#!/bin/bash

# Bootstrap Script for Redis RDI PoC on Ubuntu 22.04
# Author: Gabriel Cerioni - Redis Solutions Architect
# Date: 2025-05-15

# Variables
FILES=(
    "https://redis-latam-rdi-poc-deps.s3.us-east-1.amazonaws.com/rdi-installation-1.12.0.tar.gz"
    "https://redis-latam-rdi-poc-deps.s3.us-east-1.amazonaws.com/redislabs-7.8.6-60-jammy-amd64.tar"
)
DEST_DIR="/root"
SYSCTL_CONF="/etc/sysctl.conf"
RESOLVED_CONF="/etc/systemd/resolved.conf"
FSTAB="/etc/fstab"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Move files to /root in their own folders
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
echo "net.ipv4.ip_local_port_range = 30000 65535" >> $SYSCTL_CONF
sysctl -p

# Ensure port 53 is available
echo "Ensuring port 53 is available..."
sed -i '/^#DNSStubListener=/a DNSStubListener=no' $RESOLVED_CONF
mv /etc/resolv.conf /etc/resolv.conf.orig
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
systemctl restart systemd-resolved
echo "Port 53 is now available."

# Turn off swap
echo "Turning off swap..."
swapoff -a
sed -i.bak '/ swap / s/^(.*)$/#1/g' $FSTAB
echo "Swap turned off and configured to remain off after reboot."

# Install net-tools
echo "Installing net-tools..."
apt-get update
apt-get install -y net-tools
echo "Net-tools installed successfully."

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

# Check if port 53 is available
if ! netstat -tuln | grep ':53 '; then
  echo "Port 53 is available."
else
  echo "Port 53 is NOT available."
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
