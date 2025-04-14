#!/bin/bash

#
# cloud-init
# proxy.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 4 Apr 2025 13:42:07 -0500 by nick.
#

set -e

# === Parámetros con valores por defecto ===
PORT="${1:-8080}"
SERVER_NAME="${2:-default_server}"

# === Normalizar nombre de archivo (sin espacios ni caracteres raros) ===
FILENAME=$(echo "$SERVER_NAME" | tr -cd 'a-zA-Z0-9._-' )

CONF_PATH="/etc/nginx/sites-available/${FILENAME}.conf"
ENABLED_PATH="/etc/nginx/sites-enabled/${FILENAME}.conf"

echo "[PROXY] Configurando NGINX como proxy reverso a localhost:$PORT con server_name '$SERVER_NAME'..."

# === Instalar NGINX si no está presente ===
if ! command -v nginx >/dev/null 2>&1; then
    echo "[PROXY] NGINX no encontrado. Instalando..."
    sudo apt update
    sudo apt install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
fi

# === Crear archivo de configuración ===
echo "[PROXY] Creando configuración en $CONF_PATH..."

sudo tee "$CONF_PATH" > /dev/null <<EOF
server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# === Activar el sitio ===
sudo ln -sf "$CONF_PATH" "$ENABLED_PATH"

# === Eliminar sitio por defecto si existe ===
sudo rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default

# === Verificar y recargar NGINX ===
echo "[PROXY] Verificando configuración..."
sudo nginx -t

echo "[PROXY] Recargando NGINX..."
sudo systemctl reload nginx

echo "✅ NGINX configurado. Puerto 80 → localhost:$PORT (site: $FILENAME)"
