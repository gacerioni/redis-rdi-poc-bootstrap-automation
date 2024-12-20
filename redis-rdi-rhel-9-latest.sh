#!/bin/bash

# Bootstrap Script for Redis Software and RDI on RHEL 9
# Author: Gabriel Cerioni - Redis Solutions Architect
# Date: 2024-12-13

# Variables
FILES=(
    "https://redis-latam-rdi-poc-deps.s3.us-east-1.amazonaws.com/redislabs-7.8.2-60-rhel9-x86_64.tar"
    "https://s3.amazonaws.com/redis-latam-rdi-poc-deps/rdi-installation-1.4.3.tar.gz"
)
DEST_DIR="/root"
SYSCTL_CONF="/etc/sysctl.conf"
FSTAB="/etc/fstab"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Update system and install necessary tools
echo "Updating system and installing necessary tools..."
dnf update -y
dnf install -y wget tar net-tools
echo "System updated and tools installed successfully."

# Download files to /root in their own folders
echo "Downloading and moving files to $DEST_DIR..."
for FILE_URL in "${FILES[@]}"; do
  FILE_NAME=$(basename "$FILE_URL")
  FOLDER_NAME="${FILE_NAME%%.*}"
  mkdir -p "$DEST_DIR/$FOLDER_NAME"
  echo "Downloading $FILE_NAME..."
  wget -q "$FILE_URL" -P "$DEST_DIR/$FOLDER_NAME/"
  if [ $? -eq 0 ]; then
    echo "$FILE_NAME downloaded successfully."
  else
    echo "Error downloading $FILE_NAME."
    exit 1
  fi
done
echo "Files downloaded and moved successfully."

# Update sysctl.conf to avoid port collisions
echo "Updating $SYSCTL_CONF to avoid port collisions..."
if ! grep -q "net.ipv4.ip_local_port_range = 30000 65535" $SYSCTL_CONF; then
  echo "net.ipv4.ip_local_port_range = 30000 65535" >> $SYSCTL_CONF
  sysctl -p
  echo "sysctl.conf updated."
else
  echo "sysctl.conf already contains the required settings."
fi

# Check if port 53 is available
echo "Checking if port 53 is available..."
if ss -tuln | grep ':53 '; then
  echo "Port 53 is in use. Please ensure it is available before proceeding."
  exit 1
else
  echo "Port 53 is available."
fi

# Turn off swap
echo "Turning off swap..."
swapoff -a
sed -i.bak '/ swap / s/^/#/' $FSTAB
echo "Swap turned off and configured to remain off after reboot."

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

# Install Redis Software and RDI (Placeholder for Manual Installation Steps)
echo "Setup complete. Proceed with installing Redis Software and RDI as per documentation."
echo "If you are about to install RS for RoF/Flex/Auto-Tier, please remember to run /opt/redislabs/sbin/prepare_flash.sh after the install.sh script!"
