#!/bin/bash

# -------------------------------
# ✅ Environment Checks
# -------------------------------
check_environment() {
  if ! command -v docker > /dev/null; then
    echo "❌ Docker is not running or not installed."
    exit 1
  fi

  if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker daemon is not running. Please start Docker."
    exit 1
  fi

  if ! command -v ddev > /dev/null; then
    echo "❌ DDEV is not installed. Please install DDEV."
    exit 1
  fi

  if ! command -v composer > /dev/null; then
    echo "❌ Composer is not installed. Please install Composer."
    exit 1
  fi

  if ! command -v jq > /dev/null; then
    echo "❌ jq is not installed. Please install jq (used to parse DDEV output)."
    exit 1
  fi
  echo "✅ All tools are available"
}

# -------------------------------
# ✅ Validation Functions
# -------------------------------
DEFAULT_PHP=8.4
validate_php_version() {
  case "$1" in
    7.4|8.0|8.1|8.2|8.3|"$DEFAULT_PHP") return 0 ;;
    *) return 1 ;;
  esac
}

validate_compatibility() {
  local input="$1"
  local php="$2"
  local moodle=""

  # Normalize Moodle version
  if [[ "$input" =~ ^MOODLE_([0-9]{3})_STABLE$ ]]; then
    moodle="${BASH_REMATCH[1]}"
  elif [[ "$input" =~ ^([0-9]+)\.([0-9]+)(\.[0-9]+)?$ ]]; then
    # Convert semantic version: major.minor → major*100 + minor
    moodle="$(( ${BASH_REMATCH[1]} * 100 + ${BASH_REMATCH[2]} ))"
  elif [[ "$input" =~ ^[0-9]{3}$ ]]; then
    moodle="$input"
  else
    return 1  # Invalid format
  fi

  # Compatibility checks
  case "$moodle" in
    401)
      [[ "$php" =~ ^(7\.4|8\.0|8\.1)$ ]] && return 0
      ;;
    402|403)
      [[ "$php" =~ ^(8\.0|8\.1|8\.2)$ ]] && return 0
      ;;
    404|405)
      [[ "$php" =~ ^(8\.1|8\.2|8\.3)$ ]] && return 0
      ;;
    500|501)
      [[ "$php" =~ ^(8\.2|8\.3|8\.4)$ ]] && return 0
      ;;
  esac

  return 1
}
DEFAULT_MOODLE=501
validate_moodle_version() {
  local version="$1"

  if [[ "$version" =~ ^(401|402|403|404|405|500|$DEFAULT_MOODLE)$ ]]; then
    return 0
  elif [[ "$version" =~ ^(4\.[0-5]\.[0-9]+|5\.0\.[0-9]+|5\.1\.[0-9]+)$ ]]; then
    return 0
  else
    return 1
  fi
}
DEFAULT_DB=mariadb
validate_db(){
  case "$1" in
    "$DEFAULT_DB"|mysqli|pgsql) return 0 ;;
    *) return 1 ;;
  esac
}

get_moodle_package() {
  local version="$1"
  if [[ -z "$version" ]]; then
    echo "moodle/moodle"
  elif [[ "$version" =~ ^(4|5)[0-9]{2}$ ]]; then
    echo "moodle/moodle:dev-MOODLE_${version}_STABLE"
  elif [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "moodle/moodle:${version}"
  else
    return 1
  fi
}

is_moodle_version_5_1_or_higher() {
  local version="$1"
  if [[ "$version" =~ ^[0-9]{3}$ ]]; then
    local major="${version:0:1}"
    local minor="${version:1:2}"
    (( major > 5 || (major == 5 && minor >= 1) )) && return 0
  elif [[ "$version" =~ ^([0-9]+)\.([0-9]+)(\.[0-9]+)?$ ]]; then
    local major="${BASH_REMATCH[1]}"
    local minor="${BASH_REMATCH[2]}"
    (( major > 5 || (major == 5 && minor >= 1) )) && return 0
  fi
  return 1
}

cleanup_failed_install() {
  echo "🧹 Cleaning up failed install..."
  ddev delete --omit-snapshot -y >/dev/null 2>&1
  rm -rf moodle moodledata .ddev
  docker builder prune
  cd ..
  rm -rf "$1"
}

# -------------------------------
# ✅ Argument Parsing
# -------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
csv_admin_cfg=""
root_folder_is_default=true
php_version=""
moodle_version=""
force=false
root_folder="${MOODLE_DDEVS_DIR:-.}"
root_folder_is_default=true
db_type=""  # default mariadb

while [[ $# -gt 0 ]]; do
  case "$1" in
    --php)
      php_version="$2"
      shift 2
      ;;
    --version)
      moodle_version="$2"
      shift 2
      ;;
    --db)
      db_type="$2"
      shift 2
      ;;
    --admincfg-csv)
      csv_admin_cfg="$2"
      shift 2
      ;;
    --force)
      force=true
      shift
      ;;
    --root)
      root_folder="$2"
      root_folder_is_default=false
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Usage: $0 --php <version> --version <moodle_version> [--db <mariadb|mysql|postgres>] [--force] [--root <folder>] [--admincfg-csv <path_to_csv>]"
      exit 1
      ;;
  esac
done



# -------------------------------
# ✅ Start Script
# -------------------------------
check_environment


# Interactive fallback

if [[ -z "$moodle_version" ]]; then
  moodle_version=$DEFAULT_MOODLE
  read -p "Enter Moodle version. e.g. 401~501 or 4.x.x/5.x.x: ($DEFAULT_MOODLE) " moodle_version
fi
if [[ -z "$moodle_version" ]]; then
  moodle_version=$DEFAULT_MOODLE
fi

if ! validate_moodle_version "$moodle_version"; then
  echo "❌ Invalid Moodle version. Allowed: 401~501 or 4.x.x/5.x.x."
  exit 1
fi

if [[ -z "$php_version" ]]; then
  read -p "Enter the PHP version 7.4, 8.0, 8.1, 8.2, 8.3 or 8.4: ($DEFAULT_PHP) " php_version
fi
if [[ -z "$php_version" ]]; then
  php_version=$DEFAULT_PHP
fi

# validates php
if ! validate_php_version "$php_version"; then
  echo "❌ Invalid PHP version. Allowed: 8.2, 8.3, 8.4."
  exit 1
fi


# Compatible php with moodle.
if ! validate_compatibility "$moodle_version" "$php_version"; then
  echo "❌ Invalid combination: Moodle $moodle_version does not support PHP $php_version."
  exit 1
fi

if [[ -z "$db_type" ]]; then
  read -p "Enter DB type mariadb, mysqli or pgsql) Default (mariadb) " db_type
fi
if [[ -z "$db_type" ]]; then
  db_type=$DEFAULT_DB
fi
# DB type
if ! validate_db "$db_type"; then
  echo "❌ $db_type database type is not supported by ddev. Allowed: mariadb, mysqli, pgsql"
  exit 1
fi

if [ "$root_folder_is_default"=true ]; then
  read -e -p "Enter the path where you it installed. Default to local ($root_folder) " root_f
fi
# if the user gave a folder else use default
if [[ -n "$root_f" ]]; then
  root_folder="$(realpath $root_folder)" 
fi
if [[ -z "$csv_admin_cfg" ]]; then
  read -e -p "Enter the path (relative to the script '$SCRIPT_DIR') of a NAME,VALUE csv file for admin config (leave empty if none) " csv_admin_cfg
fi

# Map db_type to DDEV database option
case "$db_type" in
  mariadb) ddev_db="mariadb:10.11" ;;
  mysqli) ddev_db="mysql:8.0" ;;
  pgsql) ddev_db="postgres:15" ;;
esac


# Set the project name
project_name="moodle${moodle_version}-php${php_version}-${db_type}"
# Build full project path
project_dir="${root_folder}/${project_name}"

if [[ -d "$project_dir" && "$force" != true ]]; then
  echo "⚠️ Directory '$project_dir' already exists. Use --force to overwrite."
  exit 1
fi


rm -rf "$project_dir"
mkdir "$project_dir"
cd "$project_dir" || exit
mkdir moodle
mkdir -p moodledata
chmod -R 777 moodledata

# -------------------------------
# ✅ DDEV Config
# -------------------------------

if is_moodle_version_5_1_or_higher "$moodle_version"; then
  ddev config --composer-root='./moodle' --docroot='./moodle/public' --webserver-type=apache-fpm --disable-upload-dirs-warning --php-version="$php_version" --database="$ddev_db"
  rm -rf ./moodle/public # hack as ddev will create it but composer will complain...
else
  ddev config --composer-root='./moodle' --docroot='./moodle' --webserver-type=apache-fpm --disable-upload-dirs-warning --php-version="$php_version" --database="$ddev_db"
fi

ddev start

# -------------------------------
# ✅ Composer Install
# -------------------------------
moodle_package=$(get_moodle_package "$moodle_version")

if ! ddev composer create-project "$moodle_package"; then
  echo "❌ Composer project creation failed. Version may not exist."
  cleanup_failed_install $project_dir
  exit 1
fi

# -------------------------------
# ✅ Moodle CLI Install
# -------------------------------
INFO=$(ddev describe -j)
wwwroot=$(echo "$INFO" | jq -r '.raw.primary_url')
mailpiturl=$(echo "$INFO" | jq -r '.raw.mailpit_https_url')
# DDEV_ROOT=$(echo "$INFO" | jq -r '.raw.approot')

if ! ddev exec php ./moodle/admin/cli/install.php \
  --non-interactive \
  --agree-license \
  --wwwroot="$wwwroot" \
  --dbtype="$db_type" \
  --dbhost=db \
  --dbname=db \
  --dbuser=db \
  --dbpass=db \
  --fullname="$project_name" \
  --shortname="${moodle_version}-${php_version}-${db_type}" \
  --adminpass=1234 \
  --adminemail="test@test.com"; then
  echo "❌ Moodle CLI installation failed."
  cleanup_failed_install "$project_dir"
  exit 1
fi

if ! ddev exec php ./moodle/admin/cli/cfg.php --name=smtphosts --set=localhost:1025; then
  echo "⚠️ Moodle CLI failed to setup mailpit."
fi

# -------------------------------
# ✅ Apply CSV Config
# -------------------------------
if [ -z "$csv_admin_cfg" || "$csv_admin_cfg" = "none" ]; then
    echo "No CSV file provided..."
else
    # Resolve csv_admin_cfg path
    if [[ "$csv_admin_cfg" = /* ]]; then
        # Absolute path
        csv_admin_cfg="$(realpath "$csv_admin_cfg")"
    elif [[ "$csv_admin_cfg" = ~* ]]; then
        # Path relative to home
        csv_admin_cfg="$(realpath "$HOME/${csv_admin_cfg:1}")"
    else
        # Relative to script directory
        csv_admin_cfg="$(realpath "$SCRIPT_DIR/$csv_admin_cfg")"
    fi
    if [ -f "$csv_admin_cfg" ]; then
        
        while read -r line || [ -n "$line" ]; do
            [[ "$line" == NAME,* ]] && continue

            NAME=$(echo "$line" | awk -F',' '{print $1}' | sed 's/^"//;s/"$//')
            VALUE=$(echo "$line" | awk -F',' '{for(i=2;i<=NF;i++) printf "%s%s",$i,(i<NF?",":"");}' | sed 's/^"//;s/"$//')

            NAME=$(echo "$NAME" | xargs)
            VALUE=$(echo "$VALUE" | xargs)

            [[ -z "$NAME" || -z "$VALUE" ]] && continue

            echo "Setting $NAME to $VALUE..."
            if ! ddev exec php ./moodle/admin/cli/cfg.php --name="$NAME" --set="$VALUE" < /dev/null; then
                echo "⚠️ CLI failed to setup '$NAME' with value '$VALUE'."
            fi
        done < "$csv_admin_cfg"
    else
        echo "❌ Error: Admin config CSV file not found: '$csv_admin_cfg'"
    fi
fi


# -------------------------------
# ✅ Success Message
# -------------------------------
echo ""
echo "✅ Moodle $moodle_version with PHP $php_version setup completed using DDEV."
echo "🔗 Admin site: $wwwroot"
echo "📧 Mailpit site: $mailpiturl"

echo "🔐 Admin password: 1234"