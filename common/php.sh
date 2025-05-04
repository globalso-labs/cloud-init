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

PHP_VERSION="$1"

if [ -z "$PHP_VERSION" ]; then
  echo "[PHP] ERROR: No version provided."
  echo "Usage: php.sh <version>"
  exit 1
fi

echo "[PHP-FPM] Installing PHP ${PHP_VERSION} on $(lsb_release -ds) and configuring with NGINX..."

# Add PHP repository
sudo apt install -y software-properties-common
sudo apt update

# Install PHP-FPM and common extensions
sudo apt install -y php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-zip

# Install NGINX if not already installed
if ! command -v nginx &> /dev/null; then
    # Install prerequisites
    sudo apt install -y curl gnupg2 ca-certificates lsb-release

    # Add NGINX signing key
    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg > /dev/null

    # Add NGINX stable repository
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/$(. /etc/os-release && echo "$ID") $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list > /dev/null

    # Install NGINX
    sudo apt update
    sudo apt install -y nginx
fi

# Create web root directory
sudo mkdir -p /var/app/current
sudo chown -R www-data:www-data /var/app/current

# Create a test PHP file
sudo tee /var/app/current/index.php > /dev/null <<EOF
<?php
phpinfo();
EOF

# Configure NGINX with PHP-FPM
sudo tee /etc/nginx/conf.d/default.conf > /dev/null <<EOF
server {
    listen 80 default_server;
    server_name _;
    root /var/app/current;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_index index.php;
    }
}
EOF

# Restart PHP-FPM and NGINX
sudo systemctl restart php${PHP_VERSION}-fpm
sudo systemctl restart nginx

echo "[PHP-FPM] Setup complete. PHP ${PHP_VERSION}-FPM and NGINX have been configured."
echo "You can test the installation by visiting http://localhost/index.php"
