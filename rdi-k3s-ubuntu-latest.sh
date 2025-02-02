#!/bin/bash

# Bootstrap Script for Redis Software and RDI on Ubuntu 20.04 LTS
# Author: Gabriel Cerioni - Redis Solutions Architect
# Date: 2025-02-02

# Variables
FILES=(
    "https://s3.amazonaws.com/redis-latam-rdi-poc-deps/rdi-installation-1.4.4.tar.gzz"
)
DEST_DIR="/root"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Update system and install necessary tools
echo "Updating system and installing necessary tools..."
apt update -y && apt upgrade -y
apt install -y wget tar
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

# Install Redis Software and RDI (Placeholder for Manual Installation Steps)
echo "Setup complete. Proceed with installing RDI as per documentation."
