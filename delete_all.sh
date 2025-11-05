#!/usr/bin/env bash

# Arrays of versions
MOODLE_VERSIONS=("401" "402" "403" "404" "405" "500" "501")
PHP_VERSIONS=("7.4" "8.0" "8.1" "8.2" "8.3" "8.4")
DB_TYPES=("mariadb" "mysqli" "pgsql")

# Compatibility function (reuse your logic)
validate_compatibility() {
  local moodle="$1"
  local php="$2"

  case "$moodle" in
    401)
      [[ "$php" =~ ^(7\.4|8\.0|8\.1)$ ]] && return 0 ;;
    402|403)
      [[ "$php" =~ ^(8\.0|8\.1|8\.2)$ ]] && return 0 ;;
    404|405)
      [[ "$php" =~ ^(8\.1|8\.2|8\.3)$ ]] && return 0 ;;
    500|501)
      [[ "$php" =~ ^(8\.2|8\.3|8\.4)$ ]] && return 0 ;;
  esac

  return 1
}
root_folder="$(realpath "${MOODLE_DDEVS_DIR:-.}")" # If MOODLE_DDEVS_DIR is set and not empty use it else use local .


while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=true
      shift
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Usage: $0 [--root <folder>]"
      exit 1
      ;;
  esac
done

if [ ! -d "$root_folder" ]; then
  echo "❌ Error: Folder '$root_folder' does not exist."
  exit 1
fi


read -p "Ok to DELETE ALL ddev installs in '$root_folder'? (y|n) " ok_to_go
if [[ ! "$ok_to_go" != "y" ]]; then
  echo "Ciao then..."
  exit 1
fi
# Iterate over all combinations
for moodle in "${MOODLE_VERSIONS[@]}"; do
  for php in "${PHP_VERSIONS[@]}"; do
     
    if validate_compatibility "$moodle" "$php"; then
      for db in "${DB_TYPES[@]}"; do
        echo "Running: ./moodle_ddev_delete.sh --php $php --version $moodle --db $db"
        ./moodle_ddev_delete.sh "moodle$moodle-php$php-$db"
      done
    else
      echo "Skipping incompatible combo: Moodle $moodle with PHP $php"
    fi
  done
done