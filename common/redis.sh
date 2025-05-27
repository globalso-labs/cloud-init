#!/bin/bash

#
# cloud-init
# redis.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Mon, 26 May 2025 22:30:46 -0500 by nick.
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

# === Parámetros ===
REDIS_PORT="${1:-6379}"

echo "[REDIS] Instalando Redis server en Ubuntu..."

if ! command -v redis-server >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y redis-server
    sudo systemctl enable redis-server
    sudo systemctl start redis-server
else
    echo "[REDIS] Redis ya está instalado."
fi

echo "[REDIS] Configurando Redis para acceso remoto sin autenticación..."

# === Respaldo del archivo de configuración ===
CONF="/etc/redis/redis.conf"
if [ ! -f "${CONF}.bak" ]; then
    sudo cp "$CONF" "${CONF}.bak"
fi

# === Modificación de parámetros relevantes ===
sudo sed -i "s/^bind .*/bind 0.0.0.0 ::0/g" "$CONF"
sudo sed -i "s/^port .*/port ${REDIS_PORT}/g" "$CONF"
sudo sed -i "s/^protected-mode .*/protected-mode no/g" "$CONF"
sudo sed -i "s/^requirepass .*/#requirepass /g" "$CONF"
sudo sed -i "s/^# *requirepass .*/#requirepass /g" "$CONF"

# === Reinicio del servicio ===
echo "[REDIS] Reiniciando el servicio de Redis..."
sudo systemctl restart redis-server

echo "
[REDIS] Instancia de Redis escuchando en 0.0.0.0:${REDIS_PORT} SIN AUTENTICACIÓN.
IMPORTANTE: El servidor está abierto a todo Internet. No se recomienda su uso en ambientes de producción.
Para verificar la conectividad desde otra máquina:
    redis-cli -h <IP_SERVIDOR> -p ${REDIS_PORT} ping
"