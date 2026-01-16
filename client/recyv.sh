#!/bin/bash

# Configuration
# SSH connection string (user@host -p port)
SSH_TARGET="diskmon@localhost -p 2222"
# Identity File
ID_FILE="/root/.ssh/diskmon.key"

# Handle --install-cron
if [ "$1" == "--install-cron" ]; then
    echo "Setting up cron job..."
    # Self-reference logic: Use actual path of this script
    SCRIPT_PATH=$(readlink -f "$0")
    CRON_CMD="* * * * * $SCRIPT_PATH > /dev/null 2>&1"
    
    # Check if exists
    if crontab -l 2>/dev/null | grep -qF "$SCRIPT_PATH"; then
        echo "Cron job already exists."
    else
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        echo "Cron job added: $CRON_CMD"
    fi
    exit 0
fi

# Check for dependencies
if ! command -v smartctl &> /dev/null; then
    echo "Error: smartctl is not installed. Please install smartmontools."
    exit 1
fi

if ! command -v ssh &> /dev/null; then
    echo "Error: ssh is not installed."
    exit 1
fi

if [ ! -f "$ID_FILE" ]; then
    echo "Error: Identity file $ID_FILE not found."
    exit 1
fi

# Get hostname
HOSTNAME=$(hostname)

# Determine devices
DEVICES=()

if [ "$#" -gt 0 ]; then
    DEVICES=("$@")
else
    # Auto-detect devices
    for dev in /dev/sd[a-z] /dev/nvme[0-9]n[1-9]; do
        [ -e "$dev" ] && DEVICES+=("$dev")
    done
    
    if [ ${#DEVICES[@]} -eq 0 ]; then
        echo "No devices specified and none detected automatically."
        exit 1
    fi
fi

# Loop through devices
for DEVICE in "${DEVICES[@]}"
do
    if [ ! -e "$DEVICE" ]; then continue; fi

    DEV_SUFFIX=${DEVICE//\//-}
    ID="${HOSTNAME}${DEV_SUFFIX}"

    # Read SMART data
    SMART_DATA=$(smartctl -a -j "$DEVICE")
    EXIT_CODE=$?
    
    if [ $((EXIT_CODE & 1)) -ne 0 ] || [ $((EXIT_CODE & 2)) -ne 0 ]; then
        continue
    fi

    # Construct JSON payload
    PAYLOAD=$(python3 -c "import json, sys; 
try:
    data = json.loads(sys.argv[1]); 
    print(json.dumps({'id': sys.argv[2], 'device': sys.argv[3], 'hostname': sys.argv[4], 'smart_data': data}))
except Exception as e:
    print('')
" "$SMART_DATA" "$ID" "$DEVICE" "$HOSTNAME")

    if [ -z "$PAYLOAD" ]; then continue; fi

    # Send data via SSH
    # We pipe payload into ssh
    # -o StrictHostKeyChecking=no: Avoid interactive prompts in cron (Note: In production, better to manage known_hosts)
    # -i: Identity file
    echo "$PAYLOAD" | ssh -i "$ID_FILE" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SSH_TARGET > /dev/null 2>&1
    
    SSH_EXIT=$?
    if [ $SSH_EXIT -eq 0 ]; then
        echo "Sent $ID"
    else
        echo "Failed to send $ID (Exit: $SSH_EXIT)"
    fi

done
