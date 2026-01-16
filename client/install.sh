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

# Interactive Configuration
echo ""
echo "----------------------------------------------------------------"
echo "Configuration Setup"
echo "----------------------------------------------------------------"

# Check if running interactively
if [ -t 0 ]; then
    read -p "Enter Server API Upload URL (e.g. http://192.168.1.50:8080/api/upload): " INPUT_URL
    read -p "Enter API Key: " INPUT_KEY
else
    # Try reading from /dev/tty if stdin is piped (e.g. curl | bash)
    if [ -c /dev/tty ]; then
        exec 3< /dev/tty
        read -p "Enter Server API Upload URL (e.g. http://192.168.1.50:8080/api/upload): " INPUT_URL <&3
        read -p "Enter API Key: " INPUT_KEY <&3
        exec 3<&-
    else
        echo "Error: Cannot read user input. Please run this script interactively or define variables."
        exit 1
    fi
fi

if [ -z "$INPUT_URL" ] || [ -z "$INPUT_KEY" ]; then
    echo "Error: URL and API Key are required."
    exit 1
fi

# Validate connection
# Construct Ping URL from Upload URL
# Assumption: Upload URL ends with /api/upload. Ping URL is /api/ping
# We can just try to replace /upload with /ping, or just use base url if user provided base.
# But user instructions said "Server Address", prompt asks for Upload URL.
# Let's standardize.
# If user provided "http://host:port", append "/api/upload".
# If user provided "http://host:port/api/upload", keep it.

# Simple logic: remove trailing slash
INPUT_URL=${INPUT_URL%/}

# Check if ends with /api/upload
if [[ "$INPUT_URL" == *"/api/upload" ]]; then
    BASE_URL=${INPUT_URL%'/api/upload'}
    PING_URL="$BASE_URL/api/ping"
    UPLOAD_URL="$INPUT_URL"
else
    # Assume base url provided
    PING_URL="$INPUT_URL/api/ping"
    UPLOAD_URL="$INPUT_URL/api/upload"
fi

echo "Testing connection to $PING_URL..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-API-Key: $INPUT_KEY" "$PING_URL")

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "Connection successful!"
else
    echo "Error: Connection failed. HTTP Code: $HTTP_CODE"
    echo "Please check your URL and API Key."
    exit 1
fi

# Download diskmon script
echo "Downloading diskmon.sh from $REPO_URL..."
curl -sL "$REPO_URL/client/diskmon.sh" -o "$TARGET_FILE"

if [ ! -s "$TARGET_FILE" ]; then
    echo "Error: Failed to download diskmon.sh. Please check the REPO_URL in the install script."
    exit 1
fi

# Configure diskmon script
echo "Configuring $TARGET_FILE..."
# Use | as delimiter to avoid issues with slashes in URL
sed -i "s|API_URL=\"http://localhost:8080/api/upload\"|API_URL=\"$UPLOAD_URL\"|" "$TARGET_FILE"
sed -i "s|API_KEY=\"secretpassword\"|API_KEY=\"$INPUT_KEY\"|" "$TARGET_FILE"

chmod +x "$TARGET_FILE"

echo "Installation complete."
echo "Script installed to $TARGET_FILE"
echo ""

# Auto-install cron
echo "Setting up cron job..."
"$TARGET_FILE" --install-cron

echo ""
echo "----------------------------------------------------------------"
echo "SUCCESS!"
echo "DiskMon client is now installed and running."
echo "----------------------------------------------------------------"
