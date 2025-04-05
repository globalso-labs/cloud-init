#
# cloud-init
# deployments.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 4 Apr 2025 20:45:09 -0500 by nick.
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

echo "[DEPLOYMENTS] Configurando clave pública para despliegues..."

# === CLAVE PÚBLICA AUTORIZADA ===
PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILrTFxqCr3CJVQ1LVZqViRvoazBvlHU0aG97QAiqEK2e jenkins@idbi.pe"

# === DIRECTORIO Y ARCHIVO ===
TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$TARGET_USER")
SSH_DIR="$USER_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

# === CREAR DIRECTORIO .ssh SI NO EXISTE ===
if [ ! -d "$SSH_DIR" ]; then
    echo "[DEPLOYMENTS] Creando directorio $SSH_DIR"
    sudo -u "$TARGET_USER" mkdir -p "$SSH_DIR"
    sudo chmod 700 "$SSH_DIR"
fi

# === AGREGAR CLAVE SI NO EXISTE YA ===
if ! grep -qF "$PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
    echo "[DEPLOYMENTS] Agregando clave pública a $AUTH_KEYS"
    echo "$PUBKEY" | sudo tee -a "$AUTH_KEYS" > /dev/null
else
    echo "[DEPLOYMENTS] Clave pública ya existe en $AUTH_KEYS"
fi

# === ASEGURAR PERMISOS CORRECTOS ===
sudo chown "$TARGET_USER:$TARGET_USER" "$AUTH_KEYS"
sudo chmod 600 "$AUTH_KEYS"

echo "[DEPLOYMENTS] Configuración completada para el usuario $TARGET_USER"