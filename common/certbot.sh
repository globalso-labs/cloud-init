#!/bin/bash

#
# cloud-init
# certbot.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 4 Apr 2025 13:46:55 -0500 by nick.
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
  echo "[CERTBOT] ERROR: No domain provided."
  echo "Usage: certbot.sh your.domain.com"
  exit 1
fi

echo "[CERTBOT] Installing nginx and certbot for domain: $DOMAIN"

# Install NGINX and Certbot
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

# Obtain SSL cert
echo "[CERTBOT] Requesting Let's Encrypt certificate for $DOMAIN..."
sudo certbot --nginx --non-interactive --agree-tos -m admin@$DOMAIN -d "$DOMAIN"

# Auto-renewal is handled by certbot.timer (installed with certbot)
echo "[CERTBOT] SSL setup complete. Auto-renewal is active via systemd."
