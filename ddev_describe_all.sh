#!/bin/bash

# Root folder containing all DDEV projects
root_folder="$(realpath "${MOODLE_DDEVS_DIR:-.}")"

while [[ $# -gt 0 ]]; do
  case "$1" in
      --root)
      root_folder="$2"
      shift 2
      ;;
      --help)
      echo "Usage: $0 [--root <folder>]"
      shift
      exit 1
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Usage: $0 [--root <folder>]"
      exit 1
      ;;
  esac
done

echo "===== ALL DDEVs in $root_folder ====="

for dir in "$root_folder"/*; do
    if [ -d "$dir/.ddev" ]; then
        cd "$dir" || continue
        PROJECT_NAME=$(basename "$dir")
        
        # Get DDEV info in JSON format
        INFO=$(ddev describe -j)
         echo "$INFO" | jq .
        
        WEB_HOST=$(echo "$INFO" | jq -r '.raw.services.web.https_url')
        DB_PORT=$(echo "$INFO" | jq -r '.raw.services.db.host_ports')
        mailpiturl=$(echo "$INFO" | jq -r '.raw.mailpit_https_url')
        
        DB="127.0.0.1:${DB_PORT}"
        
        echo "$PROJECT_NAME 
    $WEB_HOST ← Web
    $DB ← Database
    $mailpiturl ← Mailpit
--------"
    fi
done