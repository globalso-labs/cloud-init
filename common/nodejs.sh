#!/bin/bash

#
# cloud-init
# nodejs.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 4 Apr 2025 12:01:52 -0500 by nick.
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

echo "[NODEJS] Installing Node.js (LTS)..."

# Install dependencies
apt install -y curl gnupg2 ca-certificates

# Add NodeSource (LTS)
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

# Show versions
echo "[NODEJS] Node.js version: $(node -v)"
echo "[NODEJS] npm version: $(npm -v)"

# Install PM2 globally
echo "[NODEJS] Installing pm2 globally..."
npm install -g pm2
echo "[NODEJS] PM2 version: $(pm2 -v)"

# Enable PM2 startup on boot using systemd
echo "[NODEJS] Configuring PM2 to launch on system boot..."
pm2 startup systemd -u "$USER" --hp "$HOME" | bash

# Optional: save empty process list (will save if apps are started later)
pm2 save

echo "[NODEJS] PM2 is now set to launch on reboot. You can run apps using:"
echo "         pm2 start app.js"
echo "         pm2 save    # to persist them"