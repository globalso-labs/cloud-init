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

# === Install jq if needed ===
if ! command -v jq &> /dev/null; then
  echo "[VAULT] Instalando jq..."
  sudo apt update && sudo apt install -y jq
fi

# === Detect latest Vault version ===
echo "[VAULT] Obteniendo última versión desde releases.hashicorp.com..."

LATEST_VERSION=$(curl -s https://releases.hashicorp.com/vault/ | \
  grep -oP '/vault/\K[0-9]+\.[0-9]+\.[0-9]+' | \
  sort -V | tail -n1)

if [[ -z "$LATEST_VERSION" ]]; then
  echo "[VAULT] ERROR: No se pudo determinar la última versión de Vault."
  exit 1
fi

echo "[VAULT] Última versión disponible: $LATEST_VERSION"

# === Install Vault CLI if not installed ===
if ! command -v vault &> /dev/null; then
  echo "[VAULT] Instalando Vault CLI versión $LATEST_VERSION..."
  curl -fsSL "https://releases.hashicorp.com/vault/${LATEST_VERSION}/vault_${LATEST_VERSION}_linux_amd64.zip" -o vault.zip
  unzip vault.zip
  sudo install -o root -g root -m 0755 vault /usr/local/bin/vault
  rm -f vault vault.zip
else
  echo "[VAULT] Vault ya instalado: $(vault version)"
fi

# === Authenticate via AppRole ===
echo "[VAULT] Autenticando con AppRole..."
LOGIN_RESPONSE=$(curl -s --request POST \
  --data "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
  "$VAULT_ADDR/v1/auth/approle/login")

VAULT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r .auth.client_token)

if [[ "$VAULT_TOKEN" == "null" || -z "$VAULT_TOKEN" ]]; then
  echo "[VAULT] ERROR: Falló la autenticación con AppRole."
  echo "Respuesta:"
  echo "$LOGIN_RESPONSE"
  exit 1
fi

# === Verify connection ===
echo "[VAULT] Verificando conexión con Vault..."
vault status

echo "[VAULT] Vault instalado y autenticado correctamente."