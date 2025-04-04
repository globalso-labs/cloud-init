#!/bin/bash

#
# cloud-init
# ssh.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 4 Apr 2025 18:35:39 -0500 by nick.
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

# === INPUT: Vault Server ===
VAULT_ADDR="$1"
VAULT_MOUNT="${2:-ssh}"  # Default to 'ssh' if not provided

if [ -z "$VAULT_ADDR" ]; then
  echo "[SSH] ERROR: No Vault address provided."
  echo "Usage: ssh.sh <vault-address>"
  echo "Example: ssh.sh https://vault.mycompany.com"
  exit 1
fi

# === CONFIGURATION ===
VAULT_SSH_HELPER_VERSION="0.2.1"
VAULT_SSH_HELPER_CONFIG="/etc/vault-ssh-helper.d/config.hcl"

echo "[SSH] Installing Vault SSH Helper and configuring for Vault at https://$VAULT_ADDR"

# === PREREQUISITES ===
sudo apt update
sudo apt install -y openssh-server curl unzip libpam-google-authenticator

# === INSTALL VAULT SSH HELPER ===
if ! command -v vault-ssh-helper > /dev/null; then
    echo "[SSH] Downloading vault-ssh-helper..."
    curl -fsSL "https://releases.hashicorp.com/vault-ssh-helper/${VAULT_SSH_HELPER_VERSION}/vault-ssh-helper_${VAULT_SSH_HELPER_VERSION}_linux_amd64.zip" -o /tmp/vault-ssh-helper.zip
    unzip /tmp/vault-ssh-helper.zip -d /tmp
    sudo install -o root -g root -m 0755 /tmp/vault-ssh-helper /usr/local/bin/vault-ssh-helper
    rm /tmp/vault-ssh-helper*
fi

# === CONFIGURE VAULT SSH HELPER ===
echo "[SSH] Writing Vault SSH Helper config..."
sudo mkdir -p /etc/vault-ssh-helper.d
sudo tee "$VAULT_SSH_HELPER_CONFIG" > /dev/null <<EOF
vault_addr = "https://$VAULT_ADDR"
ssh_mount_point = "$VAULT_MOUNT"
tls_skip_verify = false
allowed_roles = "*"
EOF

sudo chmod 600 "$VAULT_SSH_HELPER_CONFIG"
sudo chown root:root "$VAULT_SSH_HELPER_CONFIG"

# === CONFIGURE PAM ===
echo "[SSH] Configuring PAM authentication via vault-ssh-helper..."

# Backup and replace /etc/pam.d/sshd
sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.bak

sudo tee /etc/pam.d/sshd > /dev/null <<EOF
# PAM configuration for sshd

#@include common-auth
auth requisite pam_exec.so quiet expose_authtok log=/var/log/vault-ssh.log /usr/local/bin/vault-ssh-helper -config=/etc/vault-ssh-helper.d/config.hcl
auth optional pam_unix.so not_set_pass use_first_pass nodelay
EOF

# === UPDATE SSHD CONFIG ===
echo "[SSH] Updating /etc/ssh/sshd_config..."
sudo sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# === RESTART SSHD ===
sudo systemctl restart ssh

echo "[SSH] Vault SSH Helper setup complete. Vault OTP logins enabled via https://$VAULT_ADDR"