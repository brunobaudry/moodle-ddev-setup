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

show_help(){
   echo "Usage: 
   $0 [Optional arguments]
        --force
        --root <folder>
        --moodle <space seperated list of moodle versions>
        --php <space seperated list of php versions>
        --db <space seperated list of db types>
        --moodle-csv <comma seperated list of moodle versions>
        --php-csv <comma seperated list of php versions>
        --db-csv <comma seperated list of db types>
        "
      exit 1
}

root_folder="$(realpath "${MOODLE_DDEVS_DIR:-.}")" # If MOODLE_DDEVS_DIR is set and not empty use it else use local .

while [[ $# -gt 0 ]]; do
  case "$1" in
    --moodle)
      shift
      MOODLE_VERSIONS=($1) # space-separated
      ;;
    --php)
      shift
      PHP_VERSIONS=($1) # space-separated
      ;;
    --db)
      shift
      DB_TYPES=($1) # space-separated
      ;;
    --moodle-csv)
      shift
      IFS=',' read -r -a MOODLE_VERSIONS <<< "$1" # comma-separated
      ;;
    --php-csv)
      shift
      IFS=',' read -r -a PHP_VERSIONS <<< "$1" # comma-separated
      ;;
    --db-csv)
      shift
      IFS=',' read -r -a DB_TYPES <<< "$1" # comma-separated
      ;;

    --force)
      force=true
      shift
      ;;
    --root)
      root_folder="$2"
      shift 2
      ;;
    --help)
     show_help
      ;;
    *)
      echo "❌ Unknown option: $1"
      show_help
      ;;
  esac
done

echo "$MOODLE_DDEVS_DIR"
echo "$MOODLE_DIR"

if [ ! -d "$root_folder" ]; then
  echo "❌ Error: Folder '$root_folder' does not exist."
  exit 1
fi

total_combinations=$(( ${#MOODLE_VERSIONS[@]} * ${#PHP_VERSIONS[@]} * ${#DB_TYPES[@]} ))



read -p "Ok to install all $total_combinations combinaisons of (Moodle ${MOODLE_VERSIONS[*]} with PHP ${PHP_VERSIONS[*]} and DB ${DB_TYPES[*]}) in '$root_folder'? (y|n) " ok_to_go

if [[ ! "$ok_to_go" != "y" ]]; then
  echo "Ciao then..."
  exit 1
fi


# Iterate over all combinations
for moodle in "${MOODLE_VERSIONS[@]}"; do
  for php in "${PHP_VERSIONS[@]}"; do
     
    if validate_compatibility "$moodle" "$php"; then
      for db in "${DB_TYPES[@]}"; do
        echo "Running: ./moodle_ddev.sh --php $php --version $moodle --db $db  --root $root_folder"
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