#!/bin/bash

# cloud-init
# mariadb.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 2 May 2025 11:50:54 -0500 by nick.
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
# === INPUT: MariaDB Server ===
MARIADB_VERSION="${1:-11.4}"

# Versión a instalar
DISTRO_ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')  # ubuntu o debian
DISTRO_CODENAME=$(lsb_release -cs)  # jammy, bullseye, etc.

echo "Detectado: $DISTRO_ID ($DISTRO_CODENAME)"
echo "Instalando MariaDB $MARIADB_VERSION desde repositorio oficial..."

# Requisitos básicos
sudo apt-get update
sudo apt-get install -y curl gnupg lsb-release software-properties-common

# Llave GPG oficial
curl -LsS https://mariadb.org/mariadb_release_signing_key.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/mariadb.gpg

# Archivo de repositorio
sudo tee /etc/apt/sources.list.d/mariadb.list > /dev/null <<EOF
# MariaDB $MARIADB_VERSION repository
deb [signed-by=/etc/apt/trusted.gpg.d/mariadb.gpg] http://mirror.mariadb.org/repo/$MARIADB_VERSION/$DISTRO_ID $DISTRO_CODENAME main
EOF

# Instalar MariaDB
sudo apt-get update
sudo apt-get install -y mariadb-server mariadb-client

# Activar e iniciar el servicio
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Verificación final
echo
echo "✅ MariaDB instalado correctamente:"
mariadb --version

### Copiar archivo de configuración
echo "Descargando archivo de configuración de MariaDB..."
sudo mkdir -p /etc/mysql/mariadb.conf.d

sudo curl -o /etc/mysql/mariadb.conf.d/99-custom.cnf https://raw.githubusercontent.com/globalso-labs/cloud-init/main/settings/mariadb/99-custom.cnf
sudo chmod 644 /etc/mysql/mariadb.conf.d/99-custom.cnf

sudo curl -o /etc/mysql/mariadb.conf.d/99-replica.cnf https://raw.githubusercontent.com/globalso-labs/cloud-init/main/settings/mariadb/99-replica.cnf
sudo chmod 644 /etc/mysql/mariadb.conf.d/99-replica.cnf


### Configuración de límites de archivos abiertos (nofile)

LIMIT=65535

echo "Aplicando límite de archivos abiertos (nofile) a $LIMIT para el usuario mysql..."

# 1. Configurar límites para el usuario mysql
echo "Configurando /etc/security/limits.d/mysql.conf..."
sudo tee /etc/security/limits.d/mysql.conf > /dev/null <<EOF
mysql soft nofile $LIMIT
mysql hard nofile $LIMIT
EOF

# 2. Asegurar que pam_limits está habilitado
for f in /etc/pam.d/common-session /etc/pam.d/common-session-noninteractive; do
  if ! grep -q "pam_limits.so" "$f"; then
    echo "Agregando pam_limits.so en $f"
    echo "session required pam_limits.so" | sudo tee -a "$f" > /dev/null
  fi
done

# 3. Crear directorio de configuración si no existe
echo "Creando configuración de systemd para MariaDB..."
sudo mkdir -p /etc/systemd/system/mariadb.service.d

sudo tee /etc/systemd/system/mariadb.service.d/limits.conf > /dev/null <<EOF
[Service]
LimitNOFILE=$LIMIT
EOF

# 4. Recargar systemd y reiniciar MariaDB
echo "Recargando systemd y reiniciando MariaDB..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart mariadb || sudo systemctl restart mysql

# 5. Verificar desde MySQL
echo "Verificando open_files_limit desde MariaDB:"
mysql -e "SHOW VARIABLES LIKE 'open_files_limit';"

### Configuración de Performance Schema

# Ruta del nuevo archivo de configuración
CONFIG_FILE="/etc/mysql/mariadb.conf.d/99-percona.cnf"

# Crear el archivo si no existe
if [ -f "$CONFIG_FILE" ]; then
  echo "El archivo $CONFIG_FILE ya existe. No se realizarán cambios."
  exit 1
fi

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

# Reiniciar el servicio de MariaDB
echo "Reiniciando MariaDB..."
systemctl restart mariadb

echo "MariaDB reiniciado. Performance Schema debería estar habilitado."
