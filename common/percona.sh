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

echo "[PMM] Configuración del mariadb..."

# Ruta del nuevo archivo de configuración
CONFIG_FILE="/etc/mysql/mariadb.conf.d/99-percona.cnf"

# Crear el archivo si no existe
if [ -f "$CONFIG_FILE" ]; then
  echo "El archivo $CONFIG_FILE ya existe. No se realizarán cambios."
else
  cat <<EOF > "$CONFIG_FILE"
[mysqld]
performance_schema=ON
performance_schema_instrument='%=on'
performance-schema-consumer-events-statements-current=ON
performance-schema-consumer-events-statements-history=ON
performance-schema-consumer-events-statements-history-long=ON
performance-schema-consumer-events-waits-current=ON
performance-schema-consumer-events-waits-history=ON
performance-schema-consumer-events-waits-history-long=ON
performance-schema-consumer-statements-digest=ON

innodb_monitor_enable=all
EOF

  echo "Archivo de configuración creado en $CONFIG_FILE"
fi

# Reiniciar el servicio de MariaDB
echo "Reiniciando MariaDB..."
systemctl restart mariadb

echo "MariaDB reiniciado. Performance Schema debería estar habilitado."


# Crear usuario de monitoreo si no existe
echo "[PMM] Creando usuario de monitoreo 'pmm' en MySQL/MariaDB..."
# Define PMM user and password
PMM_USER="pmm"
PMM_PASSWORD="HilwR7Jr7ttzVaXo1hWVy" # This is safe because it is only used locally and not exposed externally.

# Execute SQL commands
sudo mysql  <<EOF
CREATE USER '${PMM_USER}'@'::1' IDENTIFIED BY '${PMM_PASSWORD}' WITH MAX_USER_CONNECTIONS 10;
GRANT SELECT, PROCESS, REPLICATION CLIENT, RELOAD ON *.* TO '${PMM_USER}'@'::1';
CREATE USER '${PMM_USER}'@'127.0.0.1' IDENTIFIED BY '${PMM_PASSWORD}' WITH MAX_USER_CONNECTIONS 10;
GRANT SELECT, PROCESS, REPLICATION CLIENT, RELOAD ON *.* TO '${PMM_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

echo "[PMM] Monitoreando instancias locales de MySQL/MariaDB/Percona..."
# Intenta registrar cualquier instancia "mysql" local
sudo pmm-admin add mysql --username="$PMM_USER" --password="$PMM_PASSWORD" \
    --query-source=perfschema --service-name=$INSTANCE_NAME-mariadb --port=3306

echo "
[PMM] Configuración completada.
Este nodo/servidor ahora envía métricas a: http://$PMM_SERVER:8080/
Instancias monitoreadas: puertos 3306 y 3307, usuario root, sin password (ajuste según su seguridad real).
Puede visualizar dashboards en el server PMM (Prometheus/Grafana).
"



