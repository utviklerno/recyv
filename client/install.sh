#!/bin/bash

# ==========================================
# Configuration
# ==========================================
GITHUB_USER="utviklerno"
REPO_NAME="recyv"
BRANCH="main"
# ==========================================

REPO_URL="https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/$BRANCH"
TARGET_FILE="/root/recyv.sh"
KEY_FILE="/root/.ssh/recyv.key"

echo "Installing Recyv Client..."

# Check root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

# Install dependencies
if command -v apt-get &> /dev/null; then
    echo "Detected apt-based system. Installing dependencies..."
    apt-get update && apt-get install -y smartmontools openssh-client python3
elif command -v yum &> /dev/null; then
    echo "Detected yum-based system. Installing dependencies..."
    yum install -y smartmontools openssh-clients python3
elif command -v pacman &> /dev/null; then
    echo "Detected pacman-based system. Installing dependencies..."
    pacman -Sy --noconfirm smartmontools openssh python3
else
    echo "Warning: Could not detect package manager. Ensure 'smartmontools', 'ssh', and 'python3' are installed."
fi

# Interactive Configuration
echo ""
echo "----------------------------------------------------------------"
echo "Configuration Setup"
echo "----------------------------------------------------------------"

if [ -t 0 ]; then
    read -p "Enter SSH Target (user@host -p port): " INPUT_SSH
    echo "Paste the content of your Client Private Key (Press Ctrl+D when finished):"
    INPUT_KEY=$(cat)
else
    # Try reading from /dev/tty
    if [ -c /dev/tty ]; then
        exec 3< /dev/tty
        read -p "Enter SSH Target (user@host -p port): " INPUT_SSH <&3
        echo "Paste the content of your Client Private Key (Press Ctrl+D when finished):" <&3
        INPUT_KEY=$(cat <&3)
        exec 3<&-
    else
        echo "Error: Cannot read user input."
        exit 1
    fi
fi

if [ -z "$INPUT_SSH" ] || [ -z "$INPUT_KEY" ]; then
    echo "Error: SSH Target and Key are required."
    exit 1
fi

# Save Key
mkdir -p /root/.ssh
echo "$INPUT_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

# Download recyv script
# Updated filename to recyv.sh
echo "Downloading recyv.sh from $REPO_URL..."
curl -sL "$REPO_URL/client/recyv.sh" -o "$TARGET_FILE"

if [ ! -s "$TARGET_FILE" ]; then
    echo "Error: Failed to download recyv.sh."
    exit 1
fi

# Check if file is a 404 HTML page (common error)
if grep -q "<html" "$TARGET_FILE" || grep -q "404: Not Found" "$TARGET_FILE"; then
    echo "Error: Downloaded file seems to be an HTML page (likely 404 Not Found)."
    echo "URL attempted: $REPO_URL/client/recyv.sh"
    rm "$TARGET_FILE"
    exit 1
fi

# Configure recyv script
echo "Configuring $TARGET_FILE..."
# Escape logic for sed is tricky with special chars in variables.
# We will read file, replace line, write file.
sed -i "s|SSH_TARGET=\"diskmon@localhost -p 2222\"|SSH_TARGET=\"$INPUT_SSH\"|" "$TARGET_FILE"
sed -i "s|ID_FILE=\"/root/.ssh/diskmon.key\"|ID_FILE=\"$KEY_FILE\"|" "$TARGET_FILE"

chmod +x "$TARGET_FILE"

echo "Installation complete."
echo "Testing connection..."
"$TARGET_FILE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Connection test passed (or at least didn't crash)."
else
    echo "Warning: Initial run might have failed. Check logs."
fi

# Auto-install cron
echo "Setting up cron job..."
"$TARGET_FILE" --install-cron

echo ""
echo "----------------------------------------------------------------"
echo "SUCCESS!"
echo "Recyv client is now installed and running."
echo "----------------------------------------------------------------"
