#!/bin/bash

#
# cloud-init
# nginx.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 4 Apr 2025 12:00:09 -0500 by nick.
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

echo "[NGINX] Installing NGINX on $(lsb_release -ds)..."

# Install prerequisites
sudo apt install -y curl gnupg2 ca-certificates lsb-release

# Add NGINX signing key
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg > /dev/null

# Add NGINX stable repository
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/$(. /etc/os-release && echo "$ID") $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list > /dev/null

# Pin nginx.org packages
sudo tee /etc/apt/preferences.d/99nginx > /dev/null <<EOF
Package: *
Pin: origin nginx.org
Pin-Priority: 900
EOF

# Install NGINX
sudo apt update
sudo apt install -y nginx

# Enable and start NGINX service
sudo systemctl enable nginx
sudo systemctl start nginx

# === Configure /var/app/current as web root ===

echo "[NGINX] Setting up /var/app/current as web root..."
sudo mkdir -p /var/app/current
sudo chown -R www-data:www-data /var/app/current

# Add default index.html
echo "<h1>Welcome to NGINX from /var/app/current</h1>" | sudo tee /var/app/current/index.html > /dev/null

# Create default server block config
sudo tee /etc/nginx/conf.d/default.conf > /dev/null <<EOF
server {
    listen 80 default_server;
    server_name _;
    root /var/app/current;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Restart NGINX
sudo systemctl restart nginx

echo "[NGINX] Setup complete. Serving content from /var/app/current"