#!/bin/bash
#
# cloud-init
# ssl.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Sat, 5 Apr 2025 14:55:11 -0500 by nick.
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

DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
  echo "Uso: ssl.sh <dominio.com>"
  exit 1
fi

# === Rutas y config ===
VAULT_PATH="idbi/certificates/nginx/$DOMAIN"
CERT_DIR="/etc/ssl/$DOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN"

# === CONFIGURATION ===
VENV_PATH="/opt/azure/venv"

# === Load environment variables from /opt/azure/venv (if not already set) ===
if [ -f "$VENV_PATH" ]; then
  echo "[VAULT] Cargando variables desde $VENV_PATH"
  # shellcheck disable=SC1090
  source "$VENV_PATH"
fi

# === Validate all required vars ===
if [[ -z "$VAULT_ADDR" || -z "$ROLE_ID" || -z "$SECRET_ID" ]]; then
  echo "[VAULT] ERROR: Faltan VAULT_ADDR, ROLE_ID o SECRET_ID."
  exit 1
fi


echo "[VAULT] Usando VAULT_ADDR: $VAULT_ADDR"

# === Authenticate via AppRole ===
echo "[VAULT] Autenticando con AppRole (TTL = 5 minutos)..."
LOGIN_RESPONSE=$(curl -s --request POST \
  --data "{
    \"role_id\": \"$ROLE_ID\",
    \"secret_id\": \"$SECRET_ID\",
    \"ttl\": \"300s\"
  }" \
  "$VAULT_ADDR/v1/auth/approle/login")

VAULT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r .auth.client_token)

if [[ "$VAULT_TOKEN" == "null" || -z "$VAULT_TOKEN" ]]; then
  echo "[VAULT] ERROR: Falló la autenticación con AppRole."
  echo "Respuesta:"
  echo "$LOGIN_RESPONSE"
  exit 1
fi

# === Exportar token ===
export VAULT_TOKEN

# === Verify connection ===
echo "[VAULT] Verificando conexión con Vault..."
vault status

# === Verificar token ===
echo "[VAULT] Verificando token..."
vault token lookup

# === Obtener certificados desde Vault KV v2 ===
echo "[SSL] Obteniendo certificado desde Vault ($VAULT_PATH)..."
SECRET=$(vault kv get -format=json "$VAULT_PATH")

FULLCHAIN=$(echo "$SECRET" | jq -r '.data.data.fullchain')
PRIVKEY=$(echo "$SECRET" | jq -r '.data.data.privkey')

if [[ -z "$FULLCHAIN" || -z "$PRIVKEY" || "$FULLCHAIN" == "null" || "$PRIVKEY" == "null" ]]; then
  echo "[SSL] Error: No se encontró fullchain o privkey en Vault."
  exit 1
fi

# === Escribir archivos ===
echo "[SSL] Escribiendo archivos en $CERT_DIR"
sudo mkdir -p "$CERT_DIR"
echo "$FULLCHAIN" | sudo tee "$CERT_DIR/fullchain.pem" > /dev/null
echo "$PRIVKEY"   | sudo tee "$CERT_DIR/privkey.pem"   > /dev/null
sudo chmod 600 "$CERT_DIR/privkey.pem"
sudo chmod 644 "$CERT_DIR/fullchain.pem"

# === Crear archivo de configuración NGINX ===
echo "[SSL] Configurando NGINX..."

if [ ! -f "$NGINX_CONF" ]; then
  echo "[SSL] No existe $NGINX_CONF. Creando archivo base..."
  sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate     $CERT_DIR/fullchain.pem;
    ssl_certificate_key $CERT_DIR/privkey.pem;

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
EOF

else
  echo "[SSL] Archivo $NGINX_CONF encontrado. Verificando configuración..."

  if ! grep -q "listen 443 ssl;" "$NGINX_CONF"; then
    echo "[SSL] No existe bloque 443. Promoviendo bloque 80 a HTTPS..."

    # === Reemplazar el primer bloque 80 con uno 443 + SSL ===
    sudo awk -v cert="$CERT_DIR/fullchain.pem" -v key="$CERT_DIR/privkey.pem" -v domain="$DOMAIN" '
    BEGIN { in_server=0; replaced=0 }
    {
      if ($0 ~ /server\s*{/) in_server=1
      if (in_server && $0 ~ /listen 80/) {
        print "    listen 443 ssl;"
        print "    ssl_certificate     " cert ";"
        print "    ssl_certificate_key " key ";"
        next
      }
      if (in_server && $0 ~ /}/) {
        in_server=0
        replaced=1
      }
      print
    }
    END {
      if (replaced == 0) {
        print "[SSL] ERROR: No se pudo encontrar bloque server { listen 80; }"
        exit 1
      }
    }
    ' "$NGINX_CONF" | sudo tee "$NGINX_CONF.tmp" > /dev/null

    sudo mv "$NGINX_CONF.tmp" "$NGINX_CONF"

    echo "[SSL] Añadiendo bloque nuevo para redirección HTTP a HTTPS..."

    sudo tee -a "$NGINX_CONF" > /dev/null <<EOF

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
EOF
  else
    echo "[SSL] Ya existe configuración HTTPS. Actualizando certificados SSL..."

    sudo sed -i "/ssl_certificate /c\    ssl_certificate     $CERT_DIR/fullchain.pem;" "$NGINX_CONF"
    sudo sed -i "/ssl_certificate_key /c\    ssl_certificate_key $CERT_DIR/privkey.pem;" "$NGINX_CONF"
  fi
fi

# === Validar y recargar NGINX ===
echo "[SSL] Verificando configuración NGINX..."
sudo nginx -t

echo "[SSL] Recargando NGINX..."
sudo systemctl reload nginx

echo "[SSL] Certificado para $DOMAIN instalado y activo."
