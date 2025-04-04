#!/bin/bash

#
# cloud-init
# watch.sh
# This file is part of cloud-init.
# Copyright (c) 2025.
# Last modified at Fri, 4 Apr 2025 12:09:09 -0500 by nick.
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

SCRIPT_TO_WATCH="/var/app/current/.cloud/init.sh"
LOG_FILE="/var/log/cloud-init-app.log"
PID_FILE="/var/run/cloud-init-app.pid"

echo "[WATCH] Starting watcher for: $SCRIPT_TO_WATCH"

# Ensure file exists
if [ ! -f "$SCRIPT_TO_WATCH" ]; then
    echo "[WATCH] File not found: $SCRIPT_TO_WATCH"
    exit 1
fi

# Install dependency if needed
if ! command -v inotifywait > /dev/null; then
    echo "[WATCH] Installing inotify-tools..."
    apt install -y inotify-tools
fi

# Daemonize the watch
nohup bash -c "
    echo \$$ > $PID_FILE
    while inotifywait -e close_write \"$SCRIPT_TO_WATCH\"; do
        echo \"[WATCH][\$(date)] Detected change. Running init script...\" >> \"$LOG_FILE\"
        bash \"$SCRIPT_TO_WATCH\" >> \"$LOG_FILE\" 2>&1
    done
" > /dev/null 2>&1 &

echo "[WATCH] Watcher started. Log: $LOG_FILE, PID: $(cat $PID_FILE)"