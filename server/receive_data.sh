#!/bin/sh

# Configuration
DATA_DIR="/app/data"
INBOX_DIR="$DATA_DIR/inbox"
TEMP_DIR="$DATA_DIR/temp"

# Ensure directories exist
mkdir -p "$INBOX_DIR"
mkdir -p "$TEMP_DIR"

# Generate unique filename
# Format: timestamp_nanoseconds_random.json
TS=$(date +%s%N)
RAND=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
FILENAME="${TS}_${RAND}.json"
TEMP_FILE="$TEMP_DIR/$FILENAME"
TARGET_FILE="$INBOX_DIR/$FILENAME"

# Read JSON from stdin to temp file
# We use cat to capture the stream
cat > "$TEMP_FILE"

# Validate file size (basic check to ensure we got data)
if [ ! -s "$TEMP_FILE" ]; then
    echo "Error: No data received"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Atomic move to inbox
# This ensures the processor only sees complete files
mv "$TEMP_FILE" "$TARGET_FILE"

# Respond with success
echo "OK"
echo "Queued as $FILENAME"
exit 0
