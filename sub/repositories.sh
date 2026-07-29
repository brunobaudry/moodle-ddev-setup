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
    # Separate repo and branch
    local repobranch="${input%@*}"
    local branch="${input##*@}"

    # Remove git protocol (git@, https://, ssh://, git:// etc.)
    repobranch=$(echo "$repobranch" | sed -E 's#^(git@|https?://|ssh://|git://)##')
    # Remove possible host/colon (e.g. github.com:)
    repobranch=$(echo "$repobranch" | sed -E 's#^[^:/]+[:/]##')

    # Remove .git suffix if present
    repobranch=$(echo "$repobranch" | sed 's/\.git$//')

    # Replace all invalid folder characters (/, \, :, *, ?, ", <, >, |, control chars)
    local safe_repo=$(echo "$repobranch" | sed 's#[\\/:*?"<>|]#_#g' | tr -d '\000-\037')
    local safe_branch=$(echo "$branch" | sed 's#[\\/:*?"<>|]#_#g' | tr -d '\000-\037')

    # Concatenate with "@" only if branch exists and not equal to the repository
    local final="$safe_repo"
    if [[ "$safe_branch" != "$input" && -n "$safe_branch" ]]; then
        final="${final}@${safe_branch}"
    fi

    # Trim leading/trailing space and dots (optional, for safety)
    final=$(echo "$final" | sed 's/^[ .]*//;s/[ .]*$//')

    echo "$final"
}
normalize_project_name() {
    local name="$1"

    # lowercase
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')

    # replace anything not allowed with dash
    name=$(echo "$name" | sed -E 's/[^a-z0-9-]+/-/g')

    # remove leading/trailing dashes
    name=$(echo "$name" | sed -E 's/^-+//; s/-+$//')

    # collapse multiple dashes
    name=$(echo "$name" | sed -E 's/-+/-/g')

    # trim length (safe: 50 chars)
    name=$(echo "$name" | cut -c1-50)

    # remove trailing dash again after cut
    name=$(echo "$name" | sed -E 's/-+$//')

    echo "$name"
}
# ---------- Create a valid HOSTNAME from repo -------------
normalize_hostname() {
    local input="$1"
    # Split repo and branch on '@'
    local repobranch="${input%@*}"
    local branch="${input##*@}"

    # Remove git protocol (git@, https://, ssh://, git:// etc.)
    repobranch=$(echo "$repobranch" | sed -E 's#^(git@|https?://|ssh://|git://)##')
    # Remove possible host/colon (e.g. github.com:)
    repobranch=$(echo "$repobranch" | sed -E 's#^[^:/]+[:/]##')
    # Remove .git suffix
    repobranch=$(echo "$repobranch" | sed 's/\.git$//')

    # Join repo and branch if branch is present and differs from the repo itself
    local name="$repobranch"
    if [[ "$branch" != "$input" && -n "$branch" ]]; then
        name="${name}-${branch}"
    fi

    # Only allow a-z, 0-9, hyphens. Convert to lowercase, replace all other chars with hyphen.
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

    # Collapse multiple hyphens, strip leading/trailing hyphens
    name=$(echo "$name" | sed -E 's/-+/-/g; s/^-+//; s/-+$//')

    # Truncate to 63 characters (single hostname label limit)
    name=$(echo "$name" | cut -c1-63)

    echo "$name"
}

# -------------------------------
# Function: Install Moodle via Git
# -------------------------------
install_moodle_git() {
  local git_url="$1"
  local branch="$2"
  local target_dir="$3"

  echo "📥 Cloning Moodle from $git_url (branch: ${branch:-default})..."
  if [ -n "$branch" ]; then
    git clone --branch "$branch" --depth 1 "$git_url" "$target_dir"
  else
    git clone --depth 1 "$git_url" "$target_dir"
  fi

  if [ $? -ne 0 ]; then
    echo "❌ Git clone failed. Check URL or branch."
    cleanup_failed_install "$target_dir"
    exit 1
  fi

  echo "📦 Installing dependencies via Composer..."
  cd "$target_dir" || exit 1
  if ! ddev composer install --no-dev; then
    echo "❌ Composer install failed."
    cleanup_failed_install "$target_dir"
    exit 1
  fi
}
