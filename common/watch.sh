#!/bin/bash

#
# cloud-init
# watch.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 4 Apr 2025 12:09:09 -0500 by nick.
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

set -e

# === CONFIGURATION ===
WATCHED_FILE="/var/app/current/.cloud/init.sh"
LOG_FILE="/var/log/cloud-init-app.log"
PID_FILE="/var/run/cloud-init-app.pid"

echo "[WATCH] Starting watcher for: $WATCHED_FILE"

# Ensure file exists
if [ ! -f "$WATCHED_FILE" ]; then
    echo "[WATCH] File not found: $WATCHED_FILE"
    exit 1
fi

# Ensure inotify-tools is installed
if ! command -v inotifywait > /dev/null; then
    echo "[WATCH] Installing inotify-tools..."
    sudo apt update
    sudo apt install -y inotify-tools
fi

# Create log and run directories if needed
sudo mkdir -p "$(dirname "$LOG_FILE")"
sudo mkdir -p "$(dirname "$PID_FILE")"
sudo touch "$LOG_FILE"
sudo chown "$USER" "$LOG_FILE"

# Start the watcher as a background process
nohup bash -c "
    echo \$\$ > \"$PID_FILE\"
    echo \"[WATCH] Watching $WATCHED_FILE for changes...\" >> \"$LOG_FILE\"

    # Run immediately once
    bash \"$WATCHED_FILE\" >> \"$LOG_FILE\" 2>&1

    # Start watching for changes
    while inotifywait -e close_write \"$WATCHED_FILE\"; do
        echo \"[WATCH][\$(date)] Detected change. Running script...\" >> \"$LOG_FILE\"
        bash \"$WATCHED_FILE\" >> \"$LOG_FILE\" 2>&1
    done
" > /dev/null 2>&1 &

echo "[WATCH] Watcher started. Log: $LOG_FILE, PID: $(cat $PID_FILE)"