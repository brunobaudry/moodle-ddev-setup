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
root_folder="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=true
      shift
      ;;
    --root)
      root_folder="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Usage: $0 [--force] [--root <folder>]"
      exit 1
      ;;
  esac
done

# Iterate over all combinations
for moodle in "${MOODLE_VERSIONS[@]}"; do
  for php in "${PHP_VERSIONS[@]}"; do
     
    if validate_compatibility "$moodle" "$php"; then
      for db in "${DB_TYPES[@]}"; do
        echo "Running: ./moodle_ddev.sh --php $php --version $moodle --db $db"
        if $force; then 
          ./moodle_ddev.sh --php "$php" --version "$moodle" --db "$db" --force --root "$root_folder"
        else
          ./moodle_ddev.sh --php "$php" --version "$moodle" --db "$db" --root "$root_folder"
        fi
      done
    else
      echo "Skipping incompatible combo: Moodle $moodle with PHP $php"
    fi
  done
done