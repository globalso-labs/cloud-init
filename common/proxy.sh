#!/bin/bash

#
# cloud-init
# proxy.sh
# Copyright (c) 2025.
# Última modificación: 2025-04-14 por Nick.
#

set -e

# === Parámetros con valores por defecto ===
PORT="${1:-8080}"
SERVER_NAME="${2:-default_server}"

# === Normalizar nombre de archivo ===
FILENAME=$(echo "$SERVER_NAME" | tr -cd 'a-zA-Z0-9._-')
CONF_PATH="/etc/nginx/conf.d/${FILENAME}.conf"

echo "[PROXY] Configurando NGINX como proxy reverso a localhost:$PORT (server_name: $SERVER_NAME)..."

# === Instalar NGINX si no está presente ===
if ! command -v nginx >/dev/null 2>&1; then
    echo "[PROXY] NGINX no encontrado. Instalando..."
    sudo apt update
    sudo apt install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
fi

# === Eliminar default.conf si existe ===
sudo rm -f /etc/nginx/conf.d/default.conf

# === Crear configuración NGINX ===
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

# === Validar y recargar NGINX ===
echo "[PROXY] Validando configuración NGINX..."
sudo nginx -t

echo "[PROXY] Recargando NGINX..."
sudo systemctl reload nginx

echo "✅ Proxy listo: http://$SERVER_NAME → http://localhost:$PORT"
