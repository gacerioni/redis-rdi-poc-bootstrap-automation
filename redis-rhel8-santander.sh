#!/bin/bash

# Bootstrap Script for Redis Software on RHEL 9
# Author: Gabriel Cerioni - Redis Solutions Architect
# Date: 2024-11-01

# Variables
FILES=(
    "https://s3.amazonaws.com/redis-enterprise-software-downloads/7.8.4/redislabs-7.8.4-95-rhel8-x86_64.tar"
)
DEST_DIR="/root"
SYSCTL_CONF="/etc/sysctl.conf"
FSTAB="/etc/fstab"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Update system and install wget
echo "Updating system and installing wget..."
dnf update -y
dnf install -y wget
echo "System updated and wget installed."

# Download files to /root in their own folders
echo "Downloading and moving files to $DEST_DIR..."
for FILE_URL in "${FILES[@]}"; do
  FILE_NAME=$(basename "$FILE_URL")
  FOLDER_NAME="${FILE_NAME%%.*}"
  mkdir -p "$DEST_DIR/$FOLDER_NAME"
  wget -q "$FILE_URL" -P "$DEST_DIR/$FOLDER_NAME/"
done
echo "Files downloaded and moved successfully."

# Update sysctl.conf to avoid port collisions
echo "Updating $SYSCTL_CONF to avoid port collisions..."
echo "net.ipv4.ip_local_port_range = 30000 65535" >> $SYSCTL_CONF
sysctl -p
echo "sysctl.conf updated."

# Turn off swap
echo "Turning off swap..."
swapoff -a
sed -i.bak '/ swap / s/^(.*)$/#1/g' $FSTAB
echo "Swap turned off and configured to remain off after reboot."

# Check if port 53 is available
echo "Checking if port 53 is available..."
if ! ss -tuln | grep ':53 '; then
  echo "Port 53 is available."
else
  echo "Port 53 is in use. Please investigate."
  exit 1
fi

# Optional STEP - For Auto Tier and Redis Flex - RoF (many names same process)
#echo "Optional - Redis Flex - Calling Redis Software prepare_flash script..."
#/opt/redislabs/sbin/prepare_flash.sh
#echo "Optional - Redis Flex - prepare_flash script execution is complete!"

# Validation
echo "Validating setup..."

# Check if files are in the correct directories
for FILE_URL in "${FILES[@]}"; do
  FILE_NAME=$(basename "$FILE_URL")
  FOLDER_NAME="${FILE_NAME%%.*}"
  if [ -f "$DEST_DIR/$FOLDER_NAME/$FILE_NAME" ]; then
    echo "File $FILE_NAME is in $DEST_DIR/$FOLDER_NAME"
  else
    echo "File $FILE_NAME is NOT in $DEST_DIR/$FOLDER_NAME"
    exit 1
  fi
done

# Check sysctl.conf for port range
if grep -q "net.ipv4.ip_local_port_range = 30000 65535" $SYSCTL_CONF; then
  echo "sysctl.conf is updated correctly."
else
  echo "sysctl.conf is NOT updated correctly."
  exit 1
fi

# Check if swap is off
if ! swapon --show | grep -q 'swap'; then
  echo "Swap is turned off."
else
  echo "Swap is NOT turned off."
  exit 1
fi

echo "All validations passed. Bootstrap script completed successfully."
echo "If you are about to install RS for RoF/Flex/Auto-Tier, please remember to run /opt/redislabs/sbin/prepare_flash.sh after the install.sh script!"
