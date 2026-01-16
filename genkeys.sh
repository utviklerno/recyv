#!/bin/bash

KEY_DIR="./keys"

mkdir -p "$KEY_DIR"

echo "Generating SSH keys for DiskMon..."

# 1. Generate Server Host Keys (if missing)
# This ensures clients don't see "Host key verification failed" if container is rebuilt
if [ ! -f "$KEY_DIR/ssh_host_rsa_key" ]; then
    echo "Generating Host Key (Server Identity)..."
    ssh-keygen -t rsa -b 4096 -f "$KEY_DIR/ssh_host_rsa_key" -N "" -q
fi
if [ ! -f "$KEY_DIR/ssh_host_ed25519_key" ]; then
    ssh-keygen -t ed25519 -f "$KEY_DIR/ssh_host_ed25519_key" -N "" -q
fi

# 2. Generate Client Access Keys (if missing)
if [ ! -f "$KEY_DIR/client_key" ]; then
    echo "Generating Client Access Key Pair..."
    ssh-keygen -t ed25519 -f "$KEY_DIR/client_key" -N "" -C "diskmon-client" -q
    
    # Set proper permissions for private key
    chmod 600 "$KEY_DIR/client_key"
    
    echo "Client Private Key generated at: $KEY_DIR/client_key"
    echo "WARNING: KEEP THIS KEY SAFE. IT GRANTS WRITE ACCESS TO YOUR DISK DATA."
fi

# 3. Create authorized_keys with restricted command
# The restricted command pipes input to a script that posts to the local API
PUB_KEY=$(cat "$KEY_DIR/client_key.pub")
# Command: Capture stdin and pipe it to curl
RESTRICTED_CMD="command=\"/app/receive_data.sh\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty"

echo "$RESTRICTED_CMD $PUB_KEY" > "$KEY_DIR/authorized_keys"

echo "Keys generated successfully."
