#!/bin/bash

#
# cloud-init
# init.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 4 Apr 2025 11:51:59 -0500 by nick.
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
REPO_URL="https://raw.githubusercontent.com/globalso-labs/cloud-init/main"
TIMEZONE="Etc/UTC"

# === DETECT DISTRO AND VERSION ===
echo "[INFO] Detecting OS..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$(echo "$ID" | tr '[:upper:]' '[:lower:]')       # e.g. ubuntu, debian
    VERSION=$(echo "$VERSION_ID" | cut -d'.' -f1,2)          # e.g. 24.04, 12
else
    echo "[ERROR] Cannot detect OS. /etc/os-release not found."
    exit 1
fi

# Supported distros only
if [[ "$DISTRO" != "ubuntu" && "$DISTRO" != "debian" ]]; then
    echo "[ERROR] Unsupported distro: $DISTRO"
    exit 1
fi

DISTRO_URL="$REPO_URL/$DISTRO/$VERSION"
COMMON_URL="$REPO_URL/common"

echo "[INFO] Detected: $DISTRO $VERSION"
echo "[INFO] Using script paths:"
echo "  - Specific: $DISTRO_URL"
echo "  - Fallback: $COMMON_URL"

# === CHECK ARGS ===
if [ "$#" -lt 1 ]; then
    echo "[ERROR] No services specified."
    echo "Usage: init.sh <service1> <service2> ..."
    exit 1
fi

# === BASE PACKAGE SETUP ===
echo "[INFO] Updating system..."
apt update && apt upgrade -y

echo "[INFO] Installing base packages..."
apt install -y curl wget git unzip htop jq ca-certificates software-properties-common lsb-release net-tools

echo "[INFO] Setting timezone to $TIMEZONE"
timedatectl set-timezone "$TIMEZONE"

# === EXECUTE SCRIPTS ===
for service in "$@"; do
    echo "[INFO] Processing: $service"

    distro_script_url="$DISTRO_URL/$service.sh"
    common_script_url="$COMMON_URL/$service.sh"

    echo "[INFO] Trying: $distro_script_url"
    if curl --fail -fsSL "$distro_script_url" | bash; then
        echo "[INFO] [$service] executed from distro-specific script."
        continue
    fi

    echo "[INFO] Trying fallback: $common_script_url"
    if curl --fail -fsSL "$common_script_url" | bash; then
        echo "[INFO] [$service] executed from common script."
    else
        echo "[WARNING] [$service] not found in either location."
    fi
done

echo "[DONE] Initialization complete."
