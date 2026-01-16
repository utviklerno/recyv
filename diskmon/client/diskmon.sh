#!/bin/bash

# Configuration
# URL of the diskmon server API
API_URL="http://localhost:8080/api/upload"
# Password/Token defined in the docker-compose file
API_KEY="secretpassword"

# Check for dependencies
if ! command -v smartctl &> /dev/null; then
    echo "Error: smartctl is not installed. Please install smartmontools."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed."
    exit 1
fi

# Get hostname
HOSTNAME=$(hostname)

# Loop through arguments (devices)
for DEVICE in "$@"
do
    # Check if device exists
    if [ ! -e "$DEVICE" ]; then
        echo "Warning: Device $DEVICE not found."
        continue
    fi

    # Generate unique ID (replace slashes with dashes)
    # e.g. /dev/sda -> hostname-dev-sda
    CLEAN_DEV=${DEVICE//\//-}
    # Remove leading dash if present (e.g. from /-dev/-sda) - actually simple replacement is usually enough
    # if device is /dev/sda, CLEAN_DEV is -dev-sda.
    # The user asked for "$hostname".-dev-sdb.
    # So if hostname is 'host1' and device is '/dev/sdb', result: 'host1-dev-sdb'
    
    # Let's clean the device string to match the requested format
    # /dev/sdb -> -dev-sdb
    DEV_SUFFIX=${DEVICE//\//-}
    ID="${HOSTNAME}${DEV_SUFFIX}"

    # Read SMART data in JSON format
    # -a: All info, -j: JSON
    SMART_DATA=$(smartctl -a -j "$DEVICE")
    EXIT_CODE=$?
    
    # smartctl returns bitmask exit codes. 
    # Bit 0: Command line did not parse.
    # Bit 1: Device open failed.
    # If these are set, we probably don't have valid JSON or data.
    if [ $((EXIT_CODE & 1)) -ne 0 ] || [ $((EXIT_CODE & 2)) -ne 0 ]; then
        echo "Error reading SMART data for $DEVICE"
        continue
    fi

    # Construct the JSON payload
    # We rely on the smart_data being valid JSON.
    # We construct a wrapper JSON.
    # Using python to safely construct JSON structure to avoid quoting issues
    
    PAYLOAD=$(python3 -c "import json, sys; 
try:
    data = json.loads(sys.argv[1]); 
    print(json.dumps({'id': sys.argv[2], 'device': sys.argv[3], 'smart_data': data}))
except Exception as e:
    print('')
" "$SMART_DATA" "$ID" "$DEVICE")

    if [ -z "$PAYLOAD" ]; then
        echo "Error constructing JSON payload for $DEVICE"
        continue
    fi

    # Send data to API
    # -s: Silent
    # -o /dev/null: Ignore output
    # -w: Write out HTTP code
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "X-API-Key: $API_KEY" \
        -d "$PAYLOAD")

    if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
        echo "Successfully sent data for $ID"
    else
        echo "Failed to send data for $ID. HTTP Code: $HTTP_CODE"
    fi

done
