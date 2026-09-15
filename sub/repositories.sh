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

    # Remove git protocol (git@, https://, ssh://, git://)
    repobranch=$(echo "$repobranch" | sed -E 's#^(git@|https?://|ssh://|git://)##')

    # Remove host part (github.com:, github.com/, etc.)
    repobranch=$(echo "$repobranch" | sed -E 's#^[^:/]+[:/]##')

    # Remove .git suffix
    repobranch=$(echo "$repobranch" | sed 's/\.git$//')

    normalize_part() {
        local s="$1"

        # lowercase
        s=$(echo "$s" | tr '[:upper:]' '[:lower:]')

        # version separator
        s=$(echo "$s" | tr '.' '-')

        # everything else -> underscore
        s=$(echo "$s" | sed -E 's/[^a-z0-9-]+/_/g')

        # collapse separators
        s=$(echo "$s" | sed -E 's/_+/_/g; s/-+/-/g')

        # trim
        s=$(echo "$s" | sed -E 's/^[-_]+//; s/[-_]+$//')

        echo "$s"
    }

    local safe_repo
    local safe_branch

    safe_repo=$(normalize_part "$repobranch")
    safe_branch=$(normalize_part "$branch")

    local final="$safe_repo"
    if [[ "$safe_branch" != "$input" && -n "$safe_branch" ]]; then
        final="${final}@${safe_branch}"
    fi

    echo "$final"
}
normalize_project_name() {
    local name="$1"

    # lowercase
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')

    # convert dots to dashes
    name=$(echo "$name" | tr '.' '-')

    # replace all other non-alphanumeric chars with underscore
    name=$(echo "$name" | sed -E 's/[^a-z0-9-]+/_/g')

    # collapse repeated separators
    name=$(echo "$name" | sed -E 's/_+/_/g; s/-+/-/g')

    # remove leading/trailing separators
    name=$(echo "$name" | sed -E 's/^[-_]+//; s/[-_]+$//')

    # trim length
    name=$(echo "$name" | cut -c1-50)

    # cleanup after trim
    name=$(echo "$name" | sed -E 's/[-_]+$//')

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
