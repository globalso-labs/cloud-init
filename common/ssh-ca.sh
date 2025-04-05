#!/bin/bash

#
# cloud-init
# ssh-ca.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 4 Apr 2025 20:09:19 -0500 by nick.
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
CA_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7ZqRE9Xv3I/q2fKVh9FbAZN3Ap0rRArg3hhoGb7zuQv0yQe80CMjh5kjxhWW15aWonzwdDGzI3rIQFFtqEdplUmeWsTJ+6zNQi4L77I9ZKshBxbPzHG+tlAVejlZB1LupN4MamH4awzGyGSl+eB0DfBpU53lxxjum3svqukkdJShO0l2vVjTm4HRu4uSavsOF8cDp7Lqo+QhOHhdgG9nmKPkQjk9Dl7vtMlnX3tgySyZK6W8sR4WUJUHP/J8x7sIXsiSHFtAbDbpSN9smqVxv030DJCXXLEjf090ZVZXBDC1Ca96EosSjC33PwGvk20dbAu0i+2UaHURouXQQqaNdmS2axiuNevO54zo9zrIVz6J6RTc/nt2oi4JI8SPHDIxd1fBctbMmBAFIOc4F+F1+J4kRsvEpFj9tPkCuC/gRBdzk9ZL1ACHFiUGwGm4khmcmtoiDdBof8PrW940UQUHPFShWeqSzYw0nWZGDPGEYGnBWUy1/7XJUdVtfDx+nMj+wFmr7T9BVZ6z46hIIcDpmwA5lm0nPJnmJQhWLnNsubQb1ZlGIttx6G9p7ACrxpNkpuK8eYBnrvLYH4cFz9JDFhRRKOsQuUHOZaRkJWlhEDGgjLu9oMds1aLRgvEDQIUQKa8cVLPlVuHbX3b4788swjLLoR6vxyPzDinAIrU9PDQ=="
CA_FILE="/etc/ssh/trusted-user-ca-keys.pem"

echo "[SSH-CA] Setting up static SSH CA trust..."

# === INSTALL SSH SERVER ===
sudo apt update
sudo apt install -y openssh-server

# === INSTALL PUBLIC CA KEY ===
echo "[SSH-CA] Writing CA public key to $CA_FILE"
echo "$CA_PUBLIC_KEY" | sudo tee "$CA_FILE" > /dev/null
sudo chmod 644 "$CA_FILE"

# === CONFIGURE SSHD ===
echo "[SSH-CA] Updating /etc/ssh/sshd_config..."

# Clean up any old lines
sudo sed -i '/^#*TrustedUserCAKeys/d' /etc/ssh/sshd_config
sudo sed -i '/^#*PubkeyAuthentication/d' /etc/ssh/sshd_config
sudo sed -i '/^#*AuthorizedKeysFile/d' /etc/ssh/sshd_config

# Append required options
echo "TrustedUserCAKeys $CA_FILE" | sudo tee -a /etc/ssh/sshd_config
echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config
echo "AuthorizedKeysFile none" | sudo tee -a /etc/ssh/sshd_config

# === RESTART SSH ===
echo "[SSH-CA] Restarting SSH..."
sudo systemctl restart ssh

echo "[SSH-CA] Setup complete. This server now trusts SSH certificates signed by your static CA."