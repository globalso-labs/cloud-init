#!/bin/bash

#
# cloud-init
# laravel.sh
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

CONFIG_FILE="/etc/nginx/conf.d/default.conf"

# Backup original file before modifying
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%F-%T)"

# Change root to /var/app/current/public
sed -i 's|root /var/app/current;|root /var/app/current/public;|' "$CONFIG_FILE"

# Change try_files line inside location / block
# We'll replace: try_files $uri $uri/ =404;
# with: try_files $uri $uri/ /index.php?$query_string;
sed -i '/location \/ {/,/}/ s|try_files \$uri \$uri/ =404;|try_files $uri $uri/ /index.php?$query_string;|' "$CONFIG_FILE"


# Restart NGINX
sudo systemctl restart nginx

echo "NGINX config modified for Laravel project."
echo "Backup saved as ${CONFIG_FILE}.bak.<timestamp>"
