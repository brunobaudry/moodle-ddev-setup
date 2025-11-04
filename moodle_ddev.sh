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
validate_php_version() {
  case "$1" in
    8.0|8.1|8.2|8.3|8.4) return 0 ;;
    *) return 1 ;;
  esac
}

validate_compatibility() {
  local moodle="$1"
  local php="$2"

  if [[ "$moodle" =~ ^401|402$ ]]; then
    [[ "$php" == "8.0" || "$php" == "8.1" ]] && return 0
  elif [[ "$moodle" =~ ^403|404|405$ ]]; then
    [[ "$php" == "8.0" || "$php" == "8.1" || "$php" == "8.2" ]] && return 0
  elif [[ "$moodle" =~ ^500|501$ ]]; then
    [[ "$php" == "8.2" || "$php" == "8.3" ]] && return 0
  fi

  return 1
}

validate_moodle_version() {
  local version="$1"

  if [[ "$version" =~ ^(401|402|403|404|405|500|501)$ ]]; then
    return 0
  elif [[ "$version" =~ ^(4\.[0-5]\.[0-9]+|5\.0\.[0-9]+|5\.1\.[0-9]+)$ ]]; then
    return 0
  else
    return 1
  fi
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
  ddev delete --omit-snapshot
  rm -rf moodle moodledata .ddev
  docker builder prune
}

# -------------------------------
# ✅ Argument Parsing
# -------------------------------
php_version=""
moodle_version=""
force=false
root_folder="."  # You can change this to any desired root path
db_type="mariadb"  # default

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
      echo "Usage: $0 --php <version> --version <moodle_version> [--db <mariadb|mysql|postgres>] [--force] [--root <folder>]"
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
  read -p "Enter Moodle version (e.g. 401 or 5.1.0): " moodle_version
fi

if ! validate_moodle_version "$moodle_version"; then
  echo "❌ Invalid Moodle version. Allowed: 401–501 or 4.x.x/5.x.x."
  exit 1
fi

if [[ -z "$php_version" ]]; then
  read -p "Enter PHP version (8.0, 8.1, 8.2, 8.3, 8.4): " php_version
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
# DB type
if [[ ! "$db_type" =~ ^(mariadb|mysql|postgres)$ ]]; then
  echo "❌ $db_type database type is not supported by ddev. Allowed: mariadb, mysql, postgres"
  exit 1
fi


# Map db_type to DDEV database option
case "$db_type" in
  mariadb) ddev_db="mariadb:10.6" ;;
  mysql) ddev_db="mysql:8.0" ;;
  postgres) ddev_db="postgres:15" ;;
esac


# Set the project name
project_name="moodle${moodle_version}-php${php_version}-db${db_type}"
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
  ddev config --composer-root='./moodle' --docroot='./moodle/public' --webserver-type=apache-fpm --php-version="$php_version" --database="$ddev_db"
else
  ddev config --composer-root='./moodle' --docroot='./moodle' --webserver-type=apache-fpm --php-version="$php_version" --database="$ddev_db"
fi

ddev restart

# -------------------------------
# ✅ Composer Install
# -------------------------------
moodle_package=$(get_moodle_package "$moodle_version")

if ! ddev composer create-project "$moodle_package"; then
  echo "❌ Composer project creation failed. Version may not exist."
  cleanup_failed_install
  exit 1
fi

# -------------------------------
# ✅ Moodle CLI Install
# -------------------------------
wwwroot=$(ddev describe -j | jq -r '.raw.primary_url')

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
  --adminpass=1234; then
  echo "❌ Moodle CLI installation failed."
  cleanup_failed_install
  exit 1
fi

# -------------------------------
# ✅ Success Message
# -------------------------------
echo ""
echo "✅ Moodle $moodle_version with PHP $php_version setup completed using DDEV."
echo "🔗 Admin site: $wwwroot"
echo "🔐 Admin password: 1234"