#!/bin/bash

#
# cloud-init
# vm-venv.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Sat, 5 Apr 2025 14:05:28 -0500 by nick.
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

echo "[AZURE] Listando máquinas virtuales..."

# === Obtener VMs (nombre + grupo de recursos) ===
VMS=()
TMP=$(mktemp)

az vm list -d --query '[].{name:name, resourceGroup:resourceGroup}' -o tsv > "$TMP"

while IFS= read -r line; do
  VMS+=("$line")
done < "$TMP"

rm -f "$TMP"

if [ "${#VMS[@]}" -eq 0 ]; then
  echo "No se encontraron VMs en esta suscripción."
  exit 1
fi

# === Mostrar menú múltiple ===
echo
echo "Selecciona una o más VMs separadas por espacios (ej. 1 3 5):"
for i in "${!VMS[@]}"; do
  NAME=$(echo "${VMS[$i]}" | awk '{print $1}')
  RG=$(echo "${VMS[$i]}" | awk '{print $2}')
  echo "$((i+1)). $NAME ($RG)"
done

read -rp "VMs seleccionadas: " -a SELECTIONS

SELECTED_VMS=()
for idx in "${SELECTIONS[@]}"; do
  if [[ "$idx" =~ ^[0-9]+$ && $idx -le ${#VMS[@]} ]]; then
    SELECTED_VMS+=("${VMS[$((idx-1))]}")
  fi
done

if [ "${#SELECTED_VMS[@]}" -eq 0 ]; then
  echo "No se seleccionó ninguna VM válida."
  exit 1
fi

# === Cargar o ingresar variables de entorno ===
ENV_VARS=()
if [ -f ".env" ]; then
  echo "[INFO] Cargando variables desde .env"
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    ENV_VARS+=("export $line")
  done < .env
else
  echo "[INFO] No se encontró .env. Ingresar variables manualmente (KEY=VALUE), termina con línea vacía:"
  while true; do
    read -rp "VAR: " input
    [[ -z "$input" ]] && break
    ENV_VARS+=("export $input")
  done
fi

if [ "${#ENV_VARS[@]}" -eq 0 ]; then
  echo "No se definieron variables de entorno."
  exit 1
fi

echo
echo "Variables a aplicar:"
printf '%s\n' "${ENV_VARS[@]}"
echo

read -rp "¿Aplicar estas variables a las VMs seleccionadas? (s/N): " CONFIRM
[[ ! "$CONFIRM" =~ ^[sS](i|í)?$ ]] && exit 0

# === Preparar bloque de variables para enviar al remoto ===
# Concatenamos las líneas (cada una con formato "export VAR=value")
COMMAND=$(printf "%s\n" "${ENV_VARS[@]}")

# Este bloque se encargará de, en la VM remota:
#   - Crear /opt/azure si no existe.
#   - Crear (o actualizar) el archivo /opt/azure/venv.
#   - Para cada línea nueva, eliminar la definición previa (si existe) y agregar la nueva.
REMOTE_CMD=$(cat <<EOF
FILE="/opt/azure/venv"
sudo mkdir -p /opt/azure
sudo touch "\$FILE"

# Se utiliza un heredoc para alimentar las nuevas variables al bucle.
cat <<EOVARS | while IFS= read -r line; do
$COMMAND
EOVARS
  VAR_NAME=\$(echo "\$line" | sed -E 's/^export[[:space:]]+([^=]+)=.*/\1/')
  # Eliminar cualquier definición previa de la variable
  sudo sed -i "/^[[:space:]]*export[[:space:]]\+\$VAR_NAME=/d" "\$FILE"
  # Agregar la nueva definición
  echo "\$line" | sudo tee -a "\$FILE" > /dev/null
done

sudo chmod 644 "\$FILE"
EOF
)

# === Aplicar a cada VM seleccionada ===
for entry in "${SELECTED_VMS[@]}"; do
  NAME=$(echo "$entry" | awk '{print $1}')
  RG=$(echo "$entry" | awk '{print $2}')
  echo "[AZURE] Aplicando variables en VM: $NAME ($RG)"

  az vm run-command invoke \
    --command-id RunShellScript \
    --name "$NAME" \
    --resource-group "$RG" \
    --scripts "$REMOTE_CMD"
done

echo "[AZURE] Variables aplicadas correctamente."