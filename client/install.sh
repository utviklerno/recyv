#!/bin/bash

# ==========================================
# Configuration - UPDATE THIS BEFORE PUSHING TO GITHUB
# ==========================================
GITHUB_USER="utviklerno"
REPO_NAME="recyv"
BRANCH="main"
# ==========================================

REPO_URL="https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/$BRANCH"
TARGET_FILE="/root/diskmon.sh"

echo "Installing DiskMon Client..."

# Check root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

# Install dependencies
if command -v apt-get &> /dev/null; then
    echo "Detected apt-based system. Installing dependencies..."
    apt-get update && apt-get install -y smartmontools curl python3
elif command -v yum &> /dev/null; then
    echo "Detected yum-based system. Installing dependencies..."
    yum install -y smartmontools curl python3
elif command -v pacman &> /dev/null; then
    echo "Detected pacman-based system. Installing dependencies..."
    pacman -Sy --noconfirm smartmontools curl python3
else
    echo "Warning: Could not detect package manager. Please ensure 'smartmontools', 'curl', and 'python3' are installed."
fi

# Download diskmon script
echo "Downloading diskmon.sh from $REPO_URL..."
curl -sL "$REPO_URL/client/diskmon.sh" -o "$TARGET_FILE"

if [ ! -s "$TARGET_FILE" ]; then
    echo "Error: Failed to download diskmon.sh. Please check the REPO_URL in the install script."
    echo "Attempted URL: $REPO_URL/client/diskmon.sh"
    exit 1
fi

chmod +x "$TARGET_FILE"

echo "Installation complete."
echo "Script installed to $TARGET_FILE"
echo ""
echo "----------------------------------------------------------------"
echo "NEXT STEPS:"
echo "1. Edit the configuration:"
echo "   nano $TARGET_FILE"
echo "   (Set your API_URL and API_KEY)"
echo ""
echo "2. Install cron job (Auto-detects drives):"
echo "   $TARGET_FILE --install-cron"
echo "----------------------------------------------------------------"
