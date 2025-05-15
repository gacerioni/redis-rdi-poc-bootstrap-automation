#!/bin/bash

# Bootstrap Script for Redis Software and RDI on RHEL 9
# Author: Gabriel Cerioni - Redis Solutions Architect
# Date: 2025-05-15

# Variables
FILES=(
    "https://redis-latam-rdi-poc-deps.s3.us-east-1.amazonaws.com/rdi-installation-1.8.0.tar.gz"
)
DEST_DIR="/root"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Update system and install necessary tools
echo "Updating system and installing necessary tools..."
dnf update -y
dnf install -y wget tar
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
