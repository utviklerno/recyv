#!/bin/bash

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
    echo "Could not detect package manager. Please ensure 'smartmontools', 'curl', and 'python3' are installed."
fi

# Copy script
echo "Copying diskmon.sh to /root/diskmon.sh..."
cp diskmon.sh /root/diskmon.sh
chmod +x /root/diskmon.sh

echo "Installation complete."
echo ""
echo "To configure the monitoring, edit /root/diskmon.sh and update API_URL and API_KEY."
echo ""
echo "To enable automatic monitoring, add the following line to your crontab (crontab -e):"
echo "* * * * * /root/diskmon.sh /dev/sda /dev/sdb (Adjust devices as needed)"
