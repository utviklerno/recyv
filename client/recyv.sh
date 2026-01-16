#!/bin/bash

# Configuration
SSH_TARGET="diskmon@localhost -p 2222"
ID_FILE="/root/.ssh/diskmon.key"

# Handle --install-cron
if [ "$1" == "--install-cron" ]; then
    echo "Setting up cron job..."
    SCRIPT_PATH=$(readlink -f "$0")
    CRON_CMD="* * * * * $SCRIPT_PATH > /dev/null 2>&1"
    
    if crontab -l 2>/dev/null | grep -qF "$SCRIPT_PATH"; then
        echo "Cron job already exists."
    else
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        echo "Cron job added: $CRON_CMD"
    fi
    exit 0
fi

# Dependencies Check
if ! command -v smartctl &> /dev/null; then echo "Error: smartctl missing"; exit 1; fi
if ! command -v ssh &> /dev/null; then echo "Error: ssh missing"; exit 1; fi
if [ ! -f "$ID_FILE" ]; then echo "Error: Key $ID_FILE missing"; exit 1; fi

# =========================================================
# 1. Gather System Info
# =========================================================
HOSTNAME=$(hostname)

# Get primary IP (Internet facing)
# Fallback to hostname -I if route fails
IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
if [ -z "$IP" ]; then
    IP=$(hostname -I | awk '{print $1}')
fi

# Create Machine ID: IP_HOSTNAME (dots in IP replaced by dashes)
CLEAN_IP=${IP//./-}
MACHINE_ID="${CLEAN_IP}_${HOSTNAME}"

# Gather Load Avg
LOAD=$(cat /proc/loadavg | awk '{print $1" "$2" "$3}')

# Gather RAM (Total/Free in MB)
RAM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
RAM_USED=$(free -m | grep Mem | awk '{print $3}')

# Gather CPU Model
CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | awk -F: '{print $2}' | xargs)

# Send System Info Packet
INFO_PAYLOAD=$(python3 -c "import json, sys; 
print(json.dumps({
    'type': 'system_info',
    'machine_id': sys.argv[1],
    'info': {
        'ip': sys.argv[2],
        'hostname': sys.argv[3],
        'load': sys.argv[4],
        'ram_total': sys.argv[5],
        'ram_used': sys.argv[6],
        'cpu_model': sys.argv[7]
    }
}))" "$MACHINE_ID" "$IP" "$HOSTNAME" "$LOAD" "$RAM_TOTAL" "$RAM_USED" "$CPU_MODEL")

echo "$INFO_PAYLOAD" | ssh -i "$ID_FILE" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SSH_TARGET > /dev/null 2>&1

# =========================================================
# 2. Gather Disk Info
# =========================================================
DEVICES=()
if [ "$#" -gt 0 ]; then
    DEVICES=("$@")
else
    for dev in /dev/sd[a-z] /dev/nvme[0-9]n[1-9]; do
        [ -e "$dev" ] && DEVICES+=("$dev")
    done
fi

for DEVICE in "${DEVICES[@]}"
do
    if [ ! -e "$DEVICE" ]; then continue; fi

    # Device ID (e.g. sda, nvme0n1)
    # Remove /dev/ prefix
    SHORT_DEV=${DEVICE##*/}

    # Read SMART data
    SMART_DATA=$(smartctl -a -j "$DEVICE")
    EXIT_CODE=$?
    
    if [ $((EXIT_CODE & 1)) -ne 0 ] || [ $((EXIT_CODE & 2)) -ne 0 ]; then
        continue
    fi

    # Construct Disk Packet
    # We send machine_id so server knows where to file it
    DISK_PAYLOAD=$(python3 -c "import json, sys; 
try:
    data = json.loads(sys.argv[1]); 
    print(json.dumps({
        'type': 'disk',
        'machine_id': sys.argv[2],
        'device': sys.argv[3],
        'smart_data': data
    }))
except Exception as e:
    print('')
" "$SMART_DATA" "$MACHINE_ID" "$SHORT_DEV")

    if [ -z "$DISK_PAYLOAD" ]; then continue; fi

    # Send
    echo "$DISK_PAYLOAD" | ssh -i "$ID_FILE" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SSH_TARGET > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "Sent $SHORT_DEV"
    else
        echo "Failed to send $SHORT_DEV"
    fi
done
