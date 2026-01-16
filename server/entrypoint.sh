#!/bin/sh

KEY_DIR="/keys"
mkdir -p "$KEY_DIR"

# ----------------------------------------------------
# 1. Host Keys (Server Identity)
# ----------------------------------------------------
if [ ! -f "$KEY_DIR/ssh_host_rsa_key" ]; then
    echo "Generating Host Keys..."
    ssh-keygen -t rsa -b 4096 -f "$KEY_DIR/ssh_host_rsa_key" -N "" -q
    ssh-keygen -t ed25519 -f "$KEY_DIR/ssh_host_ed25519_key" -N "" -q
fi

# Copy host keys to /etc/ssh with correct permissions
cp "$KEY_DIR/ssh_host_rsa_key" /etc/ssh/ssh_host_rsa_key
chmod 600 /etc/ssh/ssh_host_rsa_key
cp "$KEY_DIR/ssh_host_ed25519_key" /etc/ssh/ssh_host_ed25519_key
chmod 600 /etc/ssh/ssh_host_ed25519_key

# ----------------------------------------------------
# 2. Client Access Keys (User Authentication)
# ----------------------------------------------------
if [ ! -f "$KEY_DIR/client_key" ]; then
    echo "Generating Client Access Key..."
    ssh-keygen -t ed25519 -f "$KEY_DIR/client_key" -N "" -C "recyv-client" -q
    chmod 600 "$KEY_DIR/client_key"
    
    # Create authorized_keys
    PUB_KEY=$(cat "$KEY_DIR/client_key.pub")
    RESTRICTED_CMD="command=\"/app/receive_data.sh\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty"
    echo "$RESTRICTED_CMD $PUB_KEY" > "$KEY_DIR/authorized_keys"
fi

# Setup Authorized Keys for recyv user
mkdir -p /home/recyv/.ssh
cp "$KEY_DIR/authorized_keys" /home/recyv/.ssh/authorized_keys
chmod 600 /home/recyv/.ssh/authorized_keys
chown recyv:recyv /home/recyv/.ssh/authorized_keys

# ----------------------------------------------------
# 3. Print Banner & Keys
# ----------------------------------------------------
echo ""
echo "--------------------------------------------------"
echo "Recyv Server Running"
echo "--------------------------------------------------"
echo "Port:       ${PORT:-8080}"
echo "SSH Port:   2222"
echo "API Key:    ${API_KEY:-secretpassword} (Internal Use)"
echo "--------------------------------------------------"
echo "CLIENT PRIVATE KEY (Copy this for client install):"
echo "This file can be found in keys/client_key"
echo ""
cat "$KEY_DIR/client_key"
echo ""
echo "--------------------------------------------------"
echo ""

# Start SSHD
/usr/sbin/sshd -D -e -p 2222 &

# Export API_KEY for the SSH script
echo "export API_KEY='${API_KEY:-secretpassword}'" > /app/env.sh
chmod 644 /app/env.sh
chown recyv:recyv /app/env.sh

# Start App
exec python app.py
