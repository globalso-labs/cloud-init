#!/bin/bash

#
# cloud-init
# telemetry.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Thu, 29 May 2025 20:53:19 -0500 by nick.
#
# DISCLAIMER: This software is provided "as is" without warranty of any kind, either expressed or implied. The entire
# risk as to the quality and performance of the software is with you. In no event will the author be liable for any
# damages, including any general, special, incidental, or consequential damages arising out of the use or inability
# to use the software (that includes, but not limited to, loss of data, data being rendered inaccurate, or losses
# sustained by you or third parties, or a failure of the software to operate with any other programs), even if the
# author has been advised of the possibility of such damages.
# If a license file is provided with this software, all use of this software is governed by the terms and conditions
# set forth in that license file. If no license file is provided, no rights are granted to use, modify, distribute,
# or otherwise exploit this software.
#


# --- User params ---
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <ScopeID> <Namespace>"
  exit 1
fi

SCOPEID="$1"
NAMESPACE="$2"
ENDPOINT="telemetry.globalso.dev"
NAME=$(hostname)

# --- Detect architecture ---
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
    ARCH="arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# --- Download latest release ---
echo "[OTEL] Locating latest $ARCH otelcol-contrib release..."
RELEASE_URL=$(curl -s https://api.github.com/repos/open-telemetry/opentelemetry-collector-releases/releases/latest \
  | grep "browser_download_url" \
  | grep "otelcol-contrib_.*linux_${ARCH}.tar.gz" \
  | cut -d '"' -f 4 | head -1)

if [[ -z "$RELEASE_URL" ]]; then
  echo "Could not find release for architecture: $ARCH"
  exit 1
fi

TMPDIR=$(mktemp -d)
cd "$TMPDIR"

echo "[OTEL] Downloading $RELEASE_URL"
curl -LO "$RELEASE_URL"
tar xzf otelcol-contrib_*.tar.gz

sudo mkdir -p /usr/local/bin/
sudo cp otelcol-contrib /usr/local/bin/
sudo chmod 755 /usr/local/bin/otelcol-contrib



sudo mkdir -p /etc/otelcol-contrib /var/lib/otelcol-contrib /tmp/telemetry/file_storage/compaction
sudo chmod 700 /tmp/telemetry/file_storage /tmp/telemetry/file_storage/compaction

# --- Write config with substitutions ---
cat <<EOF > config.tmp.yaml
service:
  extensions: [ file_storage ]
  pipelines:
    logs:
      exporters: [ otlphttp ]
      receivers: [ otlp, filelog, journald ]
      processors: [ batch, memory_limiter, resourcedetection, resource ]
    traces:
      exporters: [ otlphttp ]
      receivers: [ otlp ]
      processors: [ batch, memory_limiter, resourcedetection, resource ]
    metrics:
      exporters: [ prometheusremotewrite ]
      receivers: [ otlp, hostmetrics ]
      processors: [ batch, memory_limiter, resourcedetection, resource ]

extensions:
  file_storage:
    create_directory: true
    directory: "/tmp/telemetry/file_storage"
    compaction:
      on_start: true
      directory: "/tmp/telemetry/file_storage/compaction"

exporters:
  otlphttp:
    endpoint: "https://{{.Endpoint}}"
    sending_queue:
      storage: file_storage
    headers:
      x-scope-orgid: "{{.ScopeID}}"
  prometheusremotewrite:
    endpoint: "https://{{.Endpoint}}/api/v1/push"
    resource_to_telemetry_conversion:
      enabled: true
    headers:
      x-scope-orgid: "{{.ScopeID}}"

processors:
  batch:
    send_batch_max_size: 2048           # Lower than default (8192)
    send_batch_size: 1024               # VERY conservative example
    timeout: 1s                         # Send frequently so batches don't grow big
  memory_limiter:
    check_interval: 5s
    limit_mib: 128
  resource:
    attributes:
      - key: "service.namespace"
        value: "{{.Namespace}}"
        action: "upsert"
      - key: "service.name"
        value: "{{.Name}}"
        action: "upsert"
  resourcedetection:
    detectors: [ "env", "system", "azure", "ec2", "lambda", "elastic_beanstalk", "lambda" ]

receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
  journald:
    directory: /var/log/journal
  filelog:
    include: [ /var/log/**/*.log]
    storage: "file_storage"
  hostmetrics:
    collection_interval: 30s
    scrapers:
      cpu:
      disk:
      load:
      filesystem:
      memory:
      network:
      paging:
      processes:
      process:
        include:
          match_type: "strict"
          names:
          - "systemd"
          - "sshd"
          - "rsyslogd"
          - "cron"
          - "dbus-daemon"
          - "NetworkManager"
          - "auditd"
        metrics:
          process.cpu.utilization:
            enabled: true
          process.disk.operations:
            enabled: true
          process.memory.utilization:
            enabled: true
        mute_process_name_error: true
        mute_process_io_error: true
        mute_process_exe_error: true
EOF

# Replace placeholders
sed -e "s|{{.Endpoint}}|$ENDPOINT|g" \
    -e "s|{{.ScopeID}}|$SCOPEID|g" \
    -e "s|{{.Namespace}}|$NAMESPACE|g" \
    -e "s|{{.Name}}|$NAME|g" \
    config.tmp.yaml | sudo tee /etc/otelcol-contrib/config.yaml > /dev/null

sudo chmod 640 /etc/otelcol-contrib/config.yaml

# --- Systemd service ---
sudo tee /etc/systemd/system/otelcol-contrib.service > /dev/null <<EOF
[Unit]
Description=OpenTelemetry Collector Contrib
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/otelcol-contrib --config /etc/otelcol-contrib/config.yaml
Restart=always
WorkingDirectory=/var/lib/otelcol-contrib
Environment="HOME=/var/lib/otelcol-contrib"

[Install]
WantedBy=multi-user.target
EOF

# --- Enable and start service ---
sudo systemctl daemon-reload
sudo systemctl enable --now otelcol-contrib

echo "[OTEL] Installation and service setup complete."
echo "Config file written to: /etc/otelcol-contrib/config.yaml"
echo "Check logs: sudo journalctl -u otelcol-contrib"