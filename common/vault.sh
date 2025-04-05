#!/bin/bash

#
# cloud-init
# vault.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Sat, 5 Apr 2025 13:53:58 -0500 by nick.
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

VAULT_VERSION="1.15.0"
VAULT_BIN="/usr/local/bin/vault"

ENV_FILE="/opt/azure/venv"

# === Cargar variables de entorno ===
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
else
  echo "ERROR: No se encontró el archivo de entorno $ENV_FILE."
  exit 1
fi

# === Verificar requisitos ===
if [[ -z "$VAULT_ADDR" || -z "$ROLE_ID" || -z "$SECRET_ID" ]]; then
  echo "ERROR: Debes exportar las variables VAULT_ADDR, ROLE_ID y SECRET_ID antes de continuar."
  echo "Ejemplo:"
  echo "  export VAULT_ADDR=https://vault.miempresa.com"
  echo "  export ROLE_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  echo "  export SECRET_ID=yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
  exit 1
fi

echo "[VAULT] Instalando Vault CLI versión $VAULT_VERSION para Linux..."

# === Verificar si ya está instalado ===
if command -v vault >/dev/null; then
  echo "[VAULT] Vault ya está instalado: $(vault version)"
else
  echo "[VAULT] Descargando desde releases.hashicorp.com..."
  curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" -o vault.zip
  unzip -o vault.zip
  sudo install -o root -g root -m 0755 vault "$VAULT_BIN"
  rm -f vault vault.zip
  echo "[VAULT] Vault instalado correctamente en $VAULT_BIN"
fi

# === Login con AppRole ===
echo "[VAULT] Autenticando con AppRole en $VAULT_ADDR..."
LOGIN_RESPONSE=$(curl -s --request POST \
  --data "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
  "$VAULT_ADDR/v1/auth/approle/login")

VAULT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r .auth.client_token)

if [[ "$VAULT_TOKEN" == "null" || -z "$VAULT_TOKEN" ]]; then
  echo "[VAULT] ERROR: No se pudo obtener un token válido desde AppRole."
  echo "Respuesta de Vault:"
  echo "$LOGIN_RESPONSE"
  exit 1
fi

export VAULT_TOKEN
echo "export VAULT_TOKEN=$VAULT_TOKEN" >> ~/.bashrc

# === Verificar acceso con token obtenido ===
echo "[VAULT] Verificando conexión con token..."
vault status

echo "[VAULT] Autenticación con AppRole exitosa. Token cargado en VAULT_TOKEN."
