#!/bin/bash

# cloud-init
# audit.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Thu, 22 May 2025 13:23:54 -0500 by nick.
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

echo "[*] Installing auditd..."
if command -v apt >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y auditd audispd-plugins
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y audit
elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y audit
else
    echo "[!] Package manager not supported. Install auditd manually."
    exit 1
fi

echo "[*] Configuring auditd settings..."
sudo tee /etc/audit/auditd.conf > /dev/null <<EOF
log_file = /var/log/audit/audit.log
log_format = RAW
flush = INCREMENTAL
freq = 50
num_logs = 10
max_log_file = 20
max_log_file_action = ROTATE
space_left = 75
space_left_action = SYSLOG
admin_space_left = 50
admin_space_left_action = SUSPEND
disk_full_action = SUSPEND
disk_error_action = SUSPEND
EOF

echo "[*] Setting audit rules..."
sudo mkdir -p /etc/audit/rules.d
sudo tee /etc/audit/rules.d/production.rules > /dev/null <<'EOF'
-D
-b 8192

# Monitor login/logout/authentication
-w /var/log/faillog -p wa -k auth
-w /var/log/lastlog -p wa -k auth
-w /var/log/tallylog -p wa -k auth
-w /etc/securetty -p wa -k securetty

# Monitor sudoers
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

# Session tracking
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session

# Critical binaries
-a always,exit -F path=/usr/bin/passwd -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/bin/su -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged

# Config files
-w /etc/ -p wa -k etc_changes

# Module loading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module,delete_module -k modules

# Time changes
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time

# User and group changes
-w /etc/group -p wa -k group
-w /etc/gshadow -p wa -k gshadow
-w /etc/passwd -p wa -k passwd
-w /etc/shadow -p wa -k shadow
-w /etc/security/opasswd -p wa -k opasswd

# Mount/unmount
-a always,exit -F arch=b64 -S mount -k mount

# File deletion
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=4294967295 -k delete

# Exec calls
-a always,exit -F arch=b64 -S execve -F auid>=1000 -F auid!=4294967295 -k exec

# Make rules immutable until reboot
-e 2
EOF

echo "[*] Loading audit rules..."
sudo augenrules --load
sudo systemctl restart auditd
sudo systemctl enable auditd

echo "[✔] auditd is configured and running with production rules."