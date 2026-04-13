#!/bin/bash

# ------- Rollback function --------
cleanup_failed_install() {
  echo "🧹 Cleaning up failed install..."
  ddev delete --omit-snapshot -y >/dev/null 2>&1
  rm -rf moodle moodledata .ddev
  docker builder prune
  cd ..
  rm -rf "$1"
}


# ----------------------------------
# ✅ Load functions and global vars
# ----------------------------------
source ./sub/check_environment.sh
source ./sub/validators.sh
source ./sub/repositories.sh
source ./sub/admin_config.sh
source ./sub/dockerfiles.sh

# ------- VARS init ----------------
IS_MODDLE_GIT=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POST_CUSTOM_SCRIPT_DIR="${SCRIPT_DIR}/post_custom_scripts"
PRE_CUSTOM_SCRIPT_DIR="${SCRIPT_DIR}/pre_custom_scripts"
csv_admin_cfg=""
root_folder_is_default=true
php_version=""
moodle_version=""
force=false
root_folder="${MOODLE_DDEVS_DIR:-.}"
root_folder_is_default=true
db_type=""  # default mariadb
open_ide=false

# -------------------------------
# ✅ Argument Parsing
# -------------------------------
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
    --repo)
      GIT_INPUT="$2"
      shift 2
      ;;  
    --root)
      root_folder="$2"
      root_folder_is_default=false
      shift 2
      ;;
    --ide)
      if [[ -n "$2" && "$2" != -* ]]; then
        ide="$2" # IDE name given
        shift 2
      else
        ide=""
        shift 1
      fi
      open_ide=true
      ;;

    *)
      echo "❌ Unknown option: $1"
      echo "Usage: $0 
      --php <version> ($)
      --version <moodle_version>
      [--db <mariadb|mysql|postgres>] 
      [--repo <composer|git_repo[@<branch>]>] 
      [--force] 
      [--root <folder>] 
      [--admincfg-csv <path_to_csv>]
      [--ide [IDE_NAME]]"
      exit 1
      ;;
  esac
done


# -------------------------------
# ✅ Start Script
# -------------------------------

check_environment # Verifiy that the tools (docker, composer etc are there)

# ------- Interactive fallbacks----------
# ------- MOODLE ----------
if [[ -z "$moodle_version" ]]; then
  moodle_version=$DEFAULT_MOODLE
  read -p "Moodle version. In 401~501 or 4.x.x/5.x.x formats: ($DEFAULT_MOODLE) " moodle_version
fi
if [[ -z "$moodle_version" ]]; then
  moodle_version=$DEFAULT_MOODLE
fi

if ! validate_moodle_version "$moodle_version"; then
  echo "❌ Invalid Moodle version. Allowed: 401~501 or 4.x.x/5.x.x."
  exit 1
fi
# ------- PHP ----------
if [[ -z "$php_version" ]]; then
  read -p "PHP version. 7.4, 8.0, 8.1, 8.2, 8.3 or 8.4: ($DEFAULT_PHP) " php_version
fi
if [[ -z "$php_version" ]]; then
  php_version=$DEFAULT_PHP
fi
if ! validate_php_version "$php_version"; then
  echo "❌ Invalid PHP version. Allowed: 8.2, 8.3, 8.4."
  exit 1
fi
# Compatible php with moodle.
if ! validate_compatibility "$moodle_version" "$php_version"; then
  echo "❌ Invalid combination: Moodle $moodle_version does not support PHP $php_version."
  exit 1
fi
# ------- DB ----------
if [[ -z "$db_type" ]]; then
  read -p "DB type. mariadb, mysqli or pgsql (mariadb) " db_type
fi
if [[ -z "$db_type" ]]; then
  db_type=$DEFAULT_DB
fi
if ! validate_db "$db_type"; then
  echo "❌ $db_type database type is not supported by ddev. Allowed: mariadb, mysqli, pgsql"
  exit 1
fi

# ------- REPOSITORY ----------
if [[ -z "$GIT_INPUT" ]]; then
  read -p "Repository source. Use git <git_repo_url>[@<branch>] or composer (composer): " GIT_INPUT
fi

if [[ ! -z "$GIT_INPUT" ]]; then
  read -r IS_MODDLE_GIT GIT_URL GIT_BRANCH < <(validate_git_url $GIT_INPUT)
  # if ! validate_git_url $GIT_INPUT; then 
  #   echo "❌ $GIT_INPUT does not look like a valid <git_repo_url>|<branch>"
  #   exit 1
  # fi
  # echo $IS_MODDLE_GIT
  # echo $GIT_URL
  # echo $GIT_BRANCH
fi
ADMIN_CFG_INSTRUCTIONS="leave empty if none"
# Verify if the conventional default file exists 
if [ -f "$SCRIPT_DIR/admin_cfg.csv" ]; then
  ADMIN_CFG_INSTRUCTIONS="$SCRIPT_DIR/admin_cfg.csv"
fi

# -------------------------------
# Resolve CSV Admin Config
# -------------------------------
csv_admin_cfg=$(resolve_csv_admin_cfg "$csv_admin_cfg" "$SCRIPT_DIR")
echo $csv_admin_cfg

# Map db_type to DDEV database option
case "$db_type" in
  mariadb) ddev_db="mariadb:10.11" ;;
  mysqli) ddev_db="mysql:8.0" ;;
  pgsql) ddev_db="postgres:15" ;;
esac


# Set the project name
if [[ "$IS_MODDLE_GIT" == true ]]; then
  if [[ "$GIT_URL" == false ]]; then
    echo "❌ Invalid git URL"
    exit 1
  fi
  normalisedgit=$(normalize_folder_name $GIT_INPUT)
  project_name="${normalisedgit}__m${moodle_version}-p${php_version}-${db_type}"
  echo "We will install Moodle with GIT on $GIT_URL $GIT_BRANCH"
else
  project_name="moodle${moodle_version}-php${php_version}-${db_type}"
  echo "We will install with COMPOSER"
fi

# Build full project path
project_dir="${root_folder}/${project_name}"
if [ "$root_folder_is_default"=true ]; then
  read -e -p "Enter the path where you want '${project_name}' installed. Default to local ($root_folder) " root_f
fi
# if the user gave a folder else use default
if [[ -n "$root_f" ]]; then
  root_folder="$(realpath $root_folder)" 
fi
# checks if duplicate
if [[ -d "$project_dir" && "$force" != true ]]; then
  echo "⚠️ Directory '$project_dir' already exists. Use --force to overwrite."
  exit 1
fi

# ---------------------------
# Create folders and navigate
# ---------------------------
rm -rf "$project_dir"
mkdir "$project_dir"
cd "$project_dir" || exit
mkdir moodle
mkdir -p moodledata
chmod -R 777 moodledata

# -------------------------------
# ✅ DDEV Config
# -------------------------------
is_moodle_version_5_1_or_higher "$moodle_version"
host_name=$(normalize_hostname $project_name)
MOODLE_DOC_ROOT='./moodle'
if [[ "$IS_MOODLE_ABOVE_500" == true ]]; then
  echo "⚠️  MOODLE 5.1+ --------------------------------------"
  MOODLE_DOC_ROOT='./moodle/public'
fi
# --------- Create config ------------------

# mkdir -p .ddev/web-build

# cat <<'EOF' > .ddev/web-build/Dockerfile

# ARG BASE_IMAGE
# FROM $BASE_IMAGE

# RUN apt-get update && apt-get install -y locales \
#     && sed -i '/en_AU.UTF-8/s/^# //g' /etc/locale.gen \
#     && locale-gen \
#     && echo "LANG=en_AU.UTF-8" > /etc/default/locale \
#     && echo "LC_ALL=en_AU.UTF-8" >> /etc/default/locale
# EOF

# ------------------------------------
# ✅ Running additional pre custom scripts
# ------------------------------------
# Check if folder exists
if [[ ! -d "$PRE_CUSTOM_SCRIPT_DIR" ]]; then
    echo "Directory '$PRE_CUSTOM_SCRIPT_DIR' does not exist. No custom scripts to run"
else
  DEFAULT_ARGS=("$project_dir" "$MOODLE_DOC_ROOT" "$DDEV_DESCRIBE" "$moodle_version" "$php_version" "$db_type")
  # Loop through all files in the folder
  for script in "$PRE_CUSTOM_SCRIPT_DIR"/*; do
      # Check if it's a regular file and executable
      if [[ -f "$script" && -x "$script" ]]; then
          echo "Running $script"
          "$script" "${DEFAULT_ARGS[@]}"
      elif [[ -f "$script" ]]; then
          echo "Running $script with bash"
          bash "$script" "${DEFAULT_ARGS[@]}"
      fi
  done
fi

# 1. Configure DDEV
ddev config \
  --project-name="$host_name" \
  --composer-root='./moodle' \
  --docroot="$MOODLE_DOC_ROOT" \
  --webserver-type=apache-fpm \
  --disable-upload-dirs-warning \
  --php-version="$php_version" \
  --database="$ddev_db" \



# 1.a setting crazy en_AU obligatory locale...

makedockerfile_forlocale ".ddev/web-build"


# 2. Add Selenium override BEFORE starting
makeselenium ".ddev"


# ddev start

# # Install cron and start service
# ddev exec bash -c 'apt-get update && apt-get install -y cron && service cron start'

# # Add Moodle cron job
# ddev exec bash -c 'echo "* * * * * php /var/www/html/moodle/admin/cli/cron.php >/dev/null 2>&1" | crontab -'

# # Check crontab
# ddev exec crontab -l

# hack as ddev will create MOODLE_DOC_ROOT but composer would complain ...
if [[ "$IS_MOODLE_ABOVE_500" == true ]]; then
  rm -rf $MOODLE_DOC_ROOT 
fi


# -------- LAUNCH Containers ---------------
# 3. Start DDEVy
ddev restart

# -------------------------------
# Main Logic
# -------------------------------
if [[ "$IS_MODDLE_GIT" == true ]]; then
  # -------------------------------
  # ✅ GIT Install
  # Expected format: git:<repo_url>@<branch>
  # -------------------------------
  install_moodle_git "$GIT_URL" "$GIT_BRANCH" "$project_dir/moodle"
  echo "✅ GIT Install"
else
  # -------------------------------
  # ✅ Composer Install
  # -------------------------------
  moodle_package=$(get_moodle_package "$moodle_version")
  if ! ddev composer create-project "$moodle_package"; then
    echo "❌ Composer project creation failed. Version may not exist."
    cleanup_failed_install "$project_dir"
    exit 1
  fi
  echo "✅ Composer Install"
fi

# -------------------------------
# ✅ Moodle CLI Install
# -------------------------------
DDEV_DESCRIBE=$(ddev describe -j)
wwwroot=$(echo "$DDEV_DESCRIBE" | jq -r '.raw.primary_url')
mailpiturl=$(echo "$DDEV_DESCRIBE" | jq -r '.raw.mailpit_https_url')

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
# -------------------------------
# ✅ Moodle install mailler
# -------------------------------
if ! ddev exec php ./moodle/admin/cli/cfg.php --name=smtphosts --set=localhost:1025; then
  echo "⚠️ Moodle CLI failed to setup mailpit."
fi

"$SCRIPT_DIR/sub/phpunit.sh" $project_dir $IS_MOODLE_ABOVE_500
"$SCRIPT_DIR/sub/behat.sh" $project_dir $host_name $IS_MOODLE_ABOVE_500

# -------------------------------
# ✅ Apply CSV admin Config
# -------------------------------
apply_csv_admin_cfg "$csv_admin_cfg"

# ------------------------------------
# ✅ Running additional post custom scripts
# ------------------------------------
# Check if folder exists
if [[ ! -d "$POST_CUSTOM_SCRIPT_DIR" ]]; then
    echo "Directory '$POST_CUSTOM_SCRIPT_DIR' does not exist. No custom scripts to run"
else
  DEFAULT_ARGS=("$project_dir" "$MOODLE_DOC_ROOT" "$DDEV_DESCRIBE" "$moodle_version" "$php_version" "$db_type")
  # Loop through all files in the folder
  for script in "$POST_CUSTOM_SCRIPT_DIR"/*; do
      # Must be a regular file
      [[ -f "$script" ]] || continue

      # Must start with a shebang
      if head -n 1 "$script" | grep -q '^#!'; then
          if [[ -x "$script" ]]; then
              echo "Running $script"
              "$script" "${DEFAULT_ARGS[@]}"
          else
              echo "Running $script with bash"
              bash "$script" "${DEFAULT_ARGS[@]}"
          fi
      else
          echo "Skipping non-script file: $script"
      fi
  done
fi

ddev mutagen reset && ddev restart

apply_csv_admin_cfg "$POST_CUSTOM_SCRIPT_DIR/plugins_admin_cfg.csv"




# -------------------------------
# ✅ Success Message
# -------------------------------
echo "============  $project_name ==================="
echo "📁  $project_dir"
echo "🏛  Moodle $moodle_version with PHP $php_version setup completed using DDEV."
echo "🔗  Admin site: $wwwroot"
echo "📧  Mailpit site: $mailpiturl"

echo "🔐 Admin password: 1234"
echo ""

# -------------------------------
#  Launch IDE
# -------------------------------

if [[ "$open_ide" == true ]]; then
  selected_cmd=''
  selected_name=''
  
  source $SCRIPT_DIR/sub/list_available_ide.sh
  if [ -z "$ide" ]; then
    # IDE was not given
    echo "With which IDE should I open the project (number or name)?"
    read -p 'Enter number or name: ' ide
  fi
  if [[ $ide =~ ^[0-9]+$ ]]; then
    index=$((ide-1))
    if [ $index -ge 0 ] && [ $index -lt ${#available_ides[@]} ]; then
        selected_cmd=${available_ides[$index]}
        selected_name=${names[$index]}
    fi
  else
      for i in "${!names[@]}"; do
          if [[ "${names[$i]}" == *"$ide"* ]]; then
              selected_cmd=${available_ides[$i]}
              selected_name=${names[$i]}
          fi
      done
  fi
  if [ -n "$selected_cmd" ]; then
      echo "Launching $selected_name with path: $project_dir"
      $selected_cmd "$project_dir"
  else
      echo 'Invalid choice or IDE not available.'
  fi
fi