#!/bin/bash

IS_MODDLE_GIT=false
GIT_INPUT=""
GIT_URL=""
GIT_BRANCH=""

# --------- Composer package from given version. ----------
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
# ------------ returns URL and BRANCH --------
# given URL@BRANCH
validate_git_url() {
  IS_MODDLE_GIT=true
  GIT_URL=""
  GIT_BRANCH=""
  local input="$1"
  # echo "validate GIT URL $input"
  # Captures valid git URLs and an optional |branch part
  #local regex='^((git@[^:]+:[^@]+\.git|https?://[^/]+/[^@]+\.git|ssh://[^/]+/[^@]+\.git|git://[^/]+/[^@]+\.git))(@([[:alnum:]_.-]+))?$'

  local regex='^(git@[^:]+:[^@]+(\.git)?|https?://[^/]+/[^@]+(\.git)?|ssh://[^/]+/[^@]+(\.git)?|git://[^/]+/[^@]+(\.git)?)(@([A-Za-z0-9_.\/-]+))?$'
  if [[ "$input" == "composer" ]]; then
    echo "false"
    #return 0 # IS_GIT stays false but input is valid
  elif [[ $input =~ $regex ]]; then
    echo "true ${BASH_REMATCH[1]} ${BASH_REMATCH[7]}"
  else
    echo "true false"
  fi
}

# -------- CREATE FOLDER NAME FROM repo ------------
normalize_folder_name() {
    local input="$1"

    if [[ -z "$input" || "$input" == "composer" ]]; then
        echo "composer"
        return 0
    fi

    # Strip protocol prefix (e.g. ssh://, https://, http://, git://)
    local repobranch="${input#[a-zA-Z]*://}"

    # Strip user auth prefix (e.g. git@)
    repobranch="${repobranch#git@}"

    # Strip branch if specified with @branch
    repobranch="${repobranch%@*}"

    # Remove host and optional port (github.com:, gitlab.com:2222/, gitlab.com/)
    repobranch=$(echo "$repobranch" | sed -E 's#^[^:/]+(:[0-9]+)?[:/]##; s#\.git$##')

    # Extract user name (first segment before /)
    local user="${repobranch%%/*}"

    # Normalize user name: lowercase and keep alphanumeric, hyphen, underscore
    user=$(echo "$user" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]+//g')

    if [[ -z "$user" ]]; then
        echo "git"
    else
        echo "$user"
    fi
}
normalize_project_name() {
    local name="$1"

    # lowercase
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')

    # replace colons, dots, underscores with hyphens
    name=$(echo "$name" | sed -E 's/[:._]+/-/g')

    # replace all other non-alphanumeric chars with hyphen
    name=$(echo "$name" | sed -E 's/[^a-z0-9-]+/-/g')

    # collapse repeated hyphens
    name=$(echo "$name" | sed -E 's/-+/-/g')

    # remove leading/trailing hyphens
    name=$(echo "$name" | sed -E 's/^-+//; s/-+$//')

    # trim length to 63 chars max
    name=$(echo "$name" | cut -c1-63)

    # cleanup trailing hyphen after trim
    name=$(echo "$name" | sed -E 's/-+$//')

    echo "$name"
}
# ---------- Create a valid HOSTNAME from repo -------------
normalize_hostname() {
    local input="$1"

    # If input looks like a git URL (contains protocol or /), extract the user/source
    if [[ "$input" =~ (git@|https?://|ssh://|git://|/) ]]; then
        input=$(normalize_folder_name "$input")
    fi

    # Only allow a-z, 0-9, hyphens. Convert to lowercase, replace all other chars with hyphen.
    local name
    name=$(echo "$input" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g')

    # Collapse multiple hyphens, strip leading/trailing hyphens
    name=$(echo "$name" | sed -E 's/-+/-/g; s/^-+//; s/-+$//')

    # Truncate to 63 characters (single hostname label limit)
    name=$(echo "$name" | cut -c1-63)

    # Strip trailing hyphen after truncation
    name=$(echo "$name" | sed -E 's/-+$//')

    echo "$name"
}

# -------------------------------
# Function: Install Moodle via Git
# -------------------------------
install_moodle_git() {
  local git_url="$1"
  local branch="$2"
  local target_dir="$3"
  local project_dir="${4:-}"
  local host_name="${5:-}"

  echo "📥 Cloning Moodle from $git_url (branch: ${branch:-default})..."
  if [ -n "$branch" ]; then
    git clone --branch "$branch" --depth 1 "$git_url" "$target_dir"
  else
    git clone --depth 1 "$git_url" "$target_dir"
  fi

  if [ $? -ne 0 ]; then
    echo "❌ Git clone failed. Check URL or branch."
    cleanup_failed_install "${project_dir:-$target_dir}" "$host_name"
    exit 1
  fi

  echo "📦 Installing dependencies via Composer..."
  if ! (cd "$target_dir" && ddev composer install --no-dev); then
    echo "❌ Composer install failed."
    cleanup_failed_install "${project_dir:-$target_dir}" "$host_name"
    exit 1
  fi
}
