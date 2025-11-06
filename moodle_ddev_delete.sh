#!/bin/bash

# Usage: ./prune_moodle.sh <folder> [--silent]

# Check if a folder was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <folder> [--silent]"
  exit 1
fi

root_folder="${MOODLE_DDEVS_DIR:-.}"
TARGET_DIR="$1"
SILENT=false

# Check for --silent flag
for arg in "$@"; do
    case $arg in
        --silent)
            SILENT=true
            ;;
    esac
done

# Resolve target folder
target_folder="$(realpath "$TARGET_DIR" 2>/dev/null)"

# If TARGET_DIR is not a valid folder, try with root_folder
if [ ! -d "$target_folder" ]; then
    target_folder="$(realpath "${root_folder}/${TARGET_DIR}" 2>/dev/null)"
fi

if [ ! -d "$target_folder" ]; then
  echo "❌ Error: Folder '$TARGET_DIR' does not exist."
  exit 1
fi

# Confirmation logic
if [ "$SILENT" = false ]; then
    read -p "Ok to delete $target_folder and containing ddev moodle ? (y|n) " ok_to_go
    if [[ "$ok_to_go" != "y" ]]; then
      echo "Ciao then..."
      exit 1
    fi
fi

# Navigate to the folder
cd "$target_folder" || { echo "Failed to enter $target_folder"; exit 1; }

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
echo "Deleting folder $target_folder..."
rm -rf "$target_folder"

echo "✅ Cleanup completed successfully."