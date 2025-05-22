#!/bin/bash

#
# cloud-init
# agent.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 16 May 2025 13:23:41 -0500 by nick.
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

echo "Updating system packages..."
sudo apt update -y
sudo apt upgrade -y

echo "Installing dependencies..."
sudo apt install -y curl jq

# Detect architecture
ARCH=$(uname -m)

case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    armv7l)
        ARCH="arm"
        ;;
    i386)
        ARCH="386"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
else
    echo "Cannot detect operating system."
    exit 1
fi

# Get latest release information
VERSION=$(curl -s "https://packages.globalso.dev/api/globalso-labs/cloud-handler/releases/latest" | jq -r '.tag_name')
if [ -z "$VERSION" ]; then
    echo "Could not fetch latest version."
    exit 1
fi

# Get the download URL for the appropriate asset
ASSETS=$(curl -s "https://packages.globalso.dev/api/globalso-labs/cloud-handler/releases/latest" | jq -r '.assets')
ASSET_ID=$(echo "$ASSETS" | jq -r ".[] | select(.name | contains(\"linux_${ARCH}\")) | .id")

if [ -z "$ASSET_ID" ]; then
    echo "Could not find appropriate asset for this system."
    exit 1
fi

# Construct the download URL
DOWNLOAD_URL="https://packages.globalso.dev/api/globalso-labs/cloud-handler/releases/assets/$ASSET_ID"

echo "Detected OS: $OS_ID"
echo "Detected Architecture: $ARCH"
echo "Latest Version: $VERSION"
echo "Downloading from: $DOWNLOAD_URL"

# Download and extract
TMP_FILE="/tmp/cloud-handler.tar.gz"
curl -L "$DOWNLOAD_URL" -o "$TMP_FILE"
TMP_FOLDER="/tmp/cloud-handler"
mkdir -p "$TMP_FOLDER"
tar -xzf "$TMP_FILE" -C "$TMP_FOLDER"
sudo cp -f "$TMP_FOLDER/cloud-handler" /sbin/cloud-handler
sudo chmod +x /sbin/cloud-handler

# Clean up
rm -rf "$TMP_FILE"
rm -rf "$TMP_FOLDER"

echo "Cloud Handler installed successfully. Installing complementary packages..."
# Installing complementary packages
sudo cloud-handler install service -vvvv
sudo cloud-handler install telemetry -vvvv
