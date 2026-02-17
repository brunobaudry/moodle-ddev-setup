#!/bin/bash
# echo $1 # Project root
# echo $2 # Moodle public
# echo $3 | jq -r # DDEV describe
# echo $4 # Moodle version
# echo $5 # PHP version
# echo $6 # Database type
# wwwroot=$(echo "$3" | jq -r '.raw.primary_url')

# Source and destination directories
PRIOJECT_DIR=$1
SOURCE_DIR="/Users/bdb3/Documents/dev/git_repos/moodle_lang_packs_zip"

DEST_DIR="${PRIOJECT_DIR}/moodledata/lang/"

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Copy all .zip files from source to destination
cp "$SOURCE_DIR"/*.zip "$DEST_DIR"

# Change to destination directory
cd "$DEST_DIR" || exit

# Unzip all .zip files
for zipfile in *.zip; do
    unzip -o -qq "$zipfile" && rm "$zipfile"
done
cd -