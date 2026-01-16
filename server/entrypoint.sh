#!/bin/sh

# Setup SSH Host Keys
# We expect them to be mounted at /etc/ssh/keys or similar
# Standard alpine sshd expects keys in /etc/ssh/
if [ -f /keys/ssh_host_rsa_key ]; then
    cp /keys/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
    chmod 600 /etc/ssh/ssh_host_rsa_key
fi
if [ -f /keys/ssh_host_ed25519_key ]; then
    cp /keys/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
    chmod 600 /etc/ssh/ssh_host_ed25519_key
else
    # Generate fallback keys if missing
    ssh-keygen -A
fi

# Setup Authorized Keys for diskmon user
if [ -f /keys/authorized_keys ]; then
    cp /keys/authorized_keys /home/diskmon/.ssh/authorized_keys
    chmod 600 /home/diskmon/.ssh/authorized_keys
    chown diskmon:diskmon /home/diskmon/.ssh/authorized_keys
fi

# Start SSHD
# -D: Do not detach (but we run in background with &)
# -e: Log to stderr
# -p 2222: Listen on port 2222
/usr/sbin/sshd -D -e -p 2222 &

# Start App
exec python app.py
