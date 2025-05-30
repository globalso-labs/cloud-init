#!/bin/bash

#
# cloud-init
# percona.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Mon, 26 May 2025 23:37:00 -0500 by nick.
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

# === Validación de parámetros ===
if [ -z "$1" ]; then
    echo "Uso: sudo $0 <PMM_SERVER_HOST> [MONITORING_INSTANCE_NAME]"
    exit 1
fi

PMM_SERVER="https://admin:$1:443" # PMM Server URL
INSTANCE_NAME="${2:-$(hostname)}"

echo "[PMM] Instalando Percona Monitoring and Management Client..."

# Instalar PMM2 Client desde repositorio oficial
if ! command -v pmm-admin >/dev/null 2>&1; then
    wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb
    sudo dpkg -i percona-release_latest.generic_all.deb
    sudo percona-release enable pmm3-client
    sudo apt-get install -y pmm-client
    sudo apt-get install -y percona-toolkit
    rm percona-release_latest.generic_all.deb || true
else
    echo "[PMM] pmm2-client ya instalado."
fi

echo "[PMM] Configurando cliente para servidor PMM: $PMM_SERVER..."

# Registrar el cliente con el servidor PMM
sudo pmm-admin config  --server-url="$PMM_SERVER" --force


### --- POSTGRES: Create monitoring user --------------------------------------
export PGPASSWORD=''
# Change these as desired
PG_MONITOR_USER="pmm"
PG_MONITOR_PASS="HilwR7Jr7ttzVaXo1hWVy"

PG_DB="postgres"
PG_PORT=5432

echo "[PMM] Creando usuario de monitoreo '$PG_MONITOR_USER' en PostgreSQL si no existe..."

# Create user if needed, grant read rights + monitoring
sudo -u postgres psql -d "$PG_DB" -c \
    "DO \$\$ BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${PG_MONITOR_USER}') THEN
            CREATE ROLE ${PG_MONITOR_USER} LOGIN PASSWORD '${PG_MONITOR_PASS}';
        END IF;
    END \$\$;"

sudo -u postgres psql -d "$PG_DB" -c "GRANT CONNECT ON DATABASE $PG_DB TO $PG_MONITOR_USER;"
sudo -u postgres psql -d "$PG_DB" -c "GRANT pg_monitor TO $PG_MONITOR_USER;"
sudo -u postgres psql -d "$PG_DB" -c "GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO $PG_MONITOR_USER;"
# (Repeat GRANT on your application database if desired)

echo "[PMM] Monitoreando instancia local de PostgreSQL en PMM..."

pmm-admin add postgresql \
    --username="$PG_MONITOR_USER" \
    --password="$PG_MONITOR_PASS" \
    --host=127.0.0.1 \
    --port="$PG_PORT" \
    --service-name="${INSTANCE_NAME}-postgresql"

echo "
[PMM] Configuración completada.
Este nodo/servidor ahora envía métricas de PostgreSQL.
Puede visualizarlas en su PMM server (Prometheus/Grafana).
"



