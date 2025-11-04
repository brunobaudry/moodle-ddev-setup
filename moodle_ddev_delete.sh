#!/bin/bash

# Check if a folder was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <folder>"
  exit 1
fi

TARGET_DIR="$1"

# Check if the folder exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "❌ Error: Folder '$TARGET_DIR' does not exist."
  exit 1
fi

# Navigate to the folder
cd "$TARGET_DIR" || { echo "Failed to enter $TARGET_DIR"; exit 1; }

# Perform DDEV delete without snapshot
echo "Deleting DDEV project..."
ddev delete --omit-snapshot -y >/dev/null 2>&1

# Remove Moodle-related directories
echo "Removing moodle, moodledata, and .ddev directories..."
rm -rf moodle moodledata .ddev

# Prune Docker builder cache
echo "Pruning Docker builder cache..."
docker builder prune -f

# Go back and delete the folder itself
cd ..
echo "Deleting folder $TARGET_DIR..."
rm -rf "$TARGET_DIR"

echo "✅ Cleanup completed successfully."