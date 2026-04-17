#!/bin/bash
# echo $1 # Project root
# echo $2 # Moodle public
# echo $3 | jq -r # DDEV describe
# echo $4 # Moodle version
# echo $5 # PHP version
# echo $6 # Database type
# wwwroot=$(echo "$3" | jq -r '.raw.primary_url')

# Set MOODLE_LANG_PACKS_DIR in your shell profile (e.g. ~/.zshrc) to point at a
# directory containing Moodle language pack .zip files.
SOURCE_DIR="${MOODLE_LANG_PACKS_DIR:-/Users/bdb3/Documents/dev/git_repos/moodle_lang_packs_zip}"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "⚠️  Lang packs directory not found at: $SOURCE_DIR"
    echo "   Set MOODLE_LANG_PACKS_DIR env var to your lang packs directory — skipping."
    exit 0
fi

DEST_DIR="${1}/moodledata/lang/"

mkdir -p "$DEST_DIR"
cp "$SOURCE_DIR"/*.zip "$DEST_DIR"

cd "$DEST_DIR" || exit
for zipfile in *.zip; do
    unzip -o -qq "$zipfile" && rm "$zipfile"
done
cd -