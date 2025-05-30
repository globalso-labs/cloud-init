#!/bin/bash

#
# cloud-init
# postgres.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Thu, 29 May 2025 20:20:48 -0500 by nick.
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

# Installs the latest available PostgreSQL version on Debian/Ubuntu-based systems

set -euo pipefail

echo "[POSTGRESQL] Updating package lists and installing prerequisites..."
sudo apt-get update
sudo apt-get install -y wget ca-certificates lsb-release gnupg

echo "[POSTGRESQL] Adding PostgreSQL APT repository if not present..."
if ! grep -q "apt.postgresql.org" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
        sudo gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt \
        $(lsb_release -cs)-pgdg main" | \
        sudo tee /etc/apt/sources.list.d/pgdg.list > /dev/null
else
    echo "[POSTGRESQL] PostgreSQL APT repository already configured."
fi


echo "[POSTGRESQL] Updating package lists after adding PostgreSQL repository..."
sudo apt-get update

echo "[POSTGRESQL] Determining latest available PostgreSQL version..."
PG_MAJOR_VERSION=$(apt-cache search '^postgresql-[0-9]+$' | \
    grep -Po '^postgresql-\K[0-9]+' | \
    sort -n | tail -1)

if [[ -z "$PG_MAJOR_VERSION" ]]; then
    echo "[POSTGRESQL] Could not determine latest PostgreSQL version from the package repository." >&2
    exit 1
fi



echo "[POSTGRESQL] Installing PostgreSQL $PG_MAJOR_VERSION and core contrib utilities..."
sudo apt-get install -y "postgresql-$PG_MAJOR_VERSION" "postgresql-contrib-$PG_MAJOR_VERSION"

# Get system RAM in kB, convert to MB and GB
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
TOTAL_RAM_GB=$((TOTAL_RAM_MB / 1024))

echo "[POSTGRESQL] System RAM: ${TOTAL_RAM_MB}MB (${TOTAL_RAM_GB}GB)"

# Compute optimal settings based on RAM (conservative estimates for reliability)
# Feel free to adjust according to workload type and requirements
SHARED_BUFFERS_MB=$((TOTAL_RAM_MB / 4))        # 25% of RAM
EFFECTIVE_CACHE_SIZE_MB=$(( (TOTAL_RAM_MB * 3) / 4 ))  # 75% of RAM
MAINTENANCE_WORK_MEM_MB=$((TOTAL_RAM_MB / 16)) # ~6% of RAM

# Limit to reasonable production maximums
[ "$SHARED_BUFFERS_MB" -gt 8192 ] && SHARED_BUFFERS_MB=8192
[ "$MAINTENANCE_WORK_MEM_MB" -gt 2048 ] && MAINTENANCE_WORK_MEM_MB=2048

echo "[POSTGRESQL] Tuning parameters based on system RAM:"
echo "  shared_buffers = ${SHARED_BUFFERS_MB}MB"
echo "  effective_cache_size = ${EFFECTIVE_CACHE_SIZE_MB}MB"
echo "  maintenance_work_mem = ${MAINTENANCE_WORK_MEM_MB}MB"

echo "[POSTGRESQL] Stopping PostgreSQL service before data transfer/configuration..."
sudo systemctl stop postgresql

DATADIR="/postgres/data"
PGDATA_CURRENT=$(sudo -u postgres psql -tAc "show data_directory;" 2>/dev/null || echo "")
PGDATA_DEFAULT="/var/lib/postgresql/${PG_MAJOR_VERSION}/main"

echo "[POSTGRESQL] Ensuring target data directory ($DATADIR) exists and is owned by postgres..."
sudo mkdir -p "$DATADIR"
sudo chown postgres:postgres "$DATADIR"
sudo chmod 700 "$DATADIR"

echo "[POSTGRESQL] Initializing new PostgreSQL cluster at $DATADIR..."
sudo -u postgres /usr/lib/postgresql/"$PG_MAJOR_VERSION"/bin/initdb -D "$DATADIR"

echo "[POSTGRESQL] Adjusting PostgreSQL main config to use new data directory..."
PG_SERVICE_FILE="/etc/postgresql/${PG_MAJOR_VERSION}/main/postgresql.conf"
PG_ENV_FILE="/etc/postgresql/${PG_MAJOR_VERSION}/main/environment"
PG_CTL_SCRIPT="/lib/systemd/system/postgresql@.service"
PG_CONF_DIR="/etc/postgresql/${PG_MAJOR_VERSION}/main"

# Update /etc/postgresql/<version>/main/postgresql.conf with new data_directory
sudo sed -i "s|^#*data_directory =.*|data_directory = '$DATADIR'|" "$PG_CONF_DIR/postgresql.conf"

echo "[POSTGRESQL] Setting tuned memory parameters in postgresql.conf..."
sudo sed -i "s/^#*shared_buffers.*/shared_buffers = ${SHARED_BUFFERS_MB}MB/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*effective_cache_size.*/effective_cache_size = ${EFFECTIVE_CACHE_SIZE_MB}MB/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*maintenance_work_mem.*/maintenance_work_mem = ${MAINTENANCE_WORK_MEM_MB}MB/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*work_mem.*/work_mem = 16MB/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*checkpoint_completion_target.*/checkpoint_completion_target = 0.9/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*wal_buffers.*/wal_buffers = 16MB/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*max_wal_size.*/max_wal_size = 2GB/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*min_wal_size.*/min_wal_size = 1GB/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*default_statistics_target.*/default_statistics_target = 100/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*random_page_cost.*/random_page_cost = 1.1/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*log_min_duration_statement.*/log_min_duration_statement = 1000/" "$PG_CONF_DIR/postgresql.conf"

# Set to accept ALL connections from anywhere
sudo sed -i "s/^#*listen_addresses.*/listen_addresses = '*'/" "$PG_CONF_DIR/postgresql.conf"

echo "[POSTGRESQL] Configuring pg_hba.conf to accept all remote connections (IPv4 and IPv6)..."
echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a "$PG_CONF_DIR/pg_hba.conf" > /dev/null
echo "host    all             all             ::/0                    md5" | sudo tee -a "$PG_CONF_DIR/pg_hba.conf" > /dev/null

# Advanced reliability and security recommendations for production
sudo sed -i "s/^#*listen_addresses.*/listen_addresses = '*'/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*logging_collector.*/logging_collector = on/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s|^#*log_directory.*|log_directory = 'log'|" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*log_filename.*/log_filename = 'postgresql-%a.log'/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*log_rotation_age.*/log_rotation_age = 1d/" "$PG_CONF_DIR/postgresql.conf"
sudo sed -i "s/^#*log_rotation_size.*/log_rotation_size = 0/" "$PG_CONF_DIR/postgresql.conf"


echo "[POSTGRESQL] Fixing permissions in data directory..."
sudo chown -R postgres:postgres "$DATADIR"
sudo chmod 700 "$DATADIR"

echo "[POSTGRESQL] Restarting PostgreSQL service with new data directory and configuration..."
sudo systemctl restart postgresql

echo "[POSTGRESQL] Showing final settings (tuned parameters):"
sudo -u postgres psql -c "SHOW shared_buffers; SHOW effective_cache_size; SHOW maintenance_work_mem; SHOW work_mem; SHOW data_directory;"

echo "[POSTGRESQL] Installation, tuning, and production preparation complete."