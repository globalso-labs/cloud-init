#!/bin/bash

# Check if version parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <php-version>"
    echo "Example: $0 8.2"
    exit 1
fi

PHP_VERSION="$1"
PHP_FPM_PORT="9000"

set -e

echo "[PHP-FPM] Installing PHP ${PHP_VERSION} and configuring with NGINX using TCP proxy..."

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

# Configure PHP-FPM to listen on TCP port
sudo tee /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf > /dev/null <<EOF
[www]
user = www-data
group = www-data
listen = 127.0.0.1:${PHP_FPM_PORT}
listen.allowed_clients = 127.0.0.1
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
EOF

# Create web root directory
sudo mkdir -p /var/app/current
sudo chown -R www-data:www-data /var/app/current

# Create a test PHP file
sudo tee /var/app/current/index.php > /dev/null <<EOF
<?php
phpinfo();
EOF

# Configure NGINX with PHP-FPM TCP proxy
sudo tee /etc/nginx/conf.d/default.conf > /dev/null <<EOF
upstream php-fpm {
    server 127.0.0.1:${PHP_FPM_PORT};
}

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
        fastcgi_pass php-fpm;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$document_root;
        fastcgi_index index.php;

        # FastCGI cache settings
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;

        # Timeouts
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 60s;
        fastcgi_read_timeout 60s;
    }

    # Deny access to .htaccess files
    location ~ /\.ht {
        deny all;
    }
}
EOF

# Restart PHP-FPM and NGINX
sudo systemctl restart php${PHP_VERSION}-fpm
sudo systemctl restart nginx

echo "[PHP-FPM] Setup complete. PHP ${PHP_VERSION}-FPM configured on TCP port ${PHP_FPM_PORT}"
echo "You can test the installation by visiting http://localhost/index.php"

# Display status of services
echo -e "\nChecking service status:"
sudo systemctl status php${PHP_VERSION}-fpm --no-pager
echo -e "\n"
sudo systemctl status nginx --no-pager