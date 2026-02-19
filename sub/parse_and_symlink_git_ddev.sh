#!/usr/bin/env bash

# Parse and symlink Moodle plugin git repos to DDEV target

set -euo pipefail

# Moodle plugin type to directory mapping
get_plugin_directory() {
    local plugin_type=$1
    local plugin_name=$2
    local moodle_version=${3:-5.1}
    local base_dir=""

    case "$plugin_type" in
        qtype) base_dir="question/type" ;;
        qbehaviour) base_dir="question/behaviour" ;;
        qbank) base_dir="question/bank" ;;
        block) base_dir="blocks" ;;
        tool) base_dir="admin/tool" ;;
        tiny) base_dir="lib/editor/tiny" ;;
        atto) base_dir="lib/editor/atto" ;;
        editor) base_dir="lib/editor" ;;
        codemirror) base_dir="lib/editor/codemirror" ;;
        format) base_dir="course/format" ;;
        checklist) base_dir="mod" ;;
        mod) base_dir="mod" ;;
        theme) base_dir="theme" ;;
        local) base_dir="local" ;;
        auth) base_dir="auth" ;;
        enrol) base_dir="enrol" ;;
        filter) base_dir="filter" ;;
        report) base_dir="report" ;;
        repository) base_dir="repository" ;;
        quiz) base_dir="mod/quiz/report" ;;
        assignment) base_dir="mod/assignment/type" ;;
        assignsubmission) base_dir="mod/assign/submission" ;;
        assignfeedback) base_dir="mod/assign/feedback" ;;
        webservice) base_dir="webservice" ;;
        *) return 1 ;;
    esac

    local plugin_path="${base_dir}/${plugin_name}"

    # Moodle 5.1+ uses public/ folder for web-accessible files
    if (( $(echo "$moodle_version >= 5.1 || $moodle_version >= 501" | bc -l) )); then
        echo "public/${plugin_path}"
    else
        echo "${plugin_path}"
    fi
}

# Parse Moodle plugin repo name (e.g., moodle-mod_example.git or moodle-mod_example)
parse_plugin_name() {
    local repo_name=$1

    if [[ "$repo_name" =~ ^moodle-([^_]+)_(.+)(\.git)?$ ]]; then
        local plugin_type="${BASH_REMATCH[1]}"
        local plugin_name="${BASH_REMATCH[2]}"
        # Remove .git suffix if present
        plugin_name="${plugin_name%.git}"
        echo "$plugin_type $plugin_name"
        return 0
    fi
    return 1
}

# Create a symlink from source to target
create_symlink() {
    local source=$1
    local target=$2
    local dry_run=$3

    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] Would create symlink: $target -> $source"
        return 0
    fi

    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$target")"

    # Remove existing symlink or check if target exists
    if [[ -L "$target" ]]; then
        rm "$target"
        echo "Removed existing symlink: $target"
    elif [[ -e "$target" ]]; then
        echo "WARNING: Target exists and is not a symlink: $target"
        return 1
    fi

    # Create symlink
    ln -s "$source" "$target"
    echo "Created symlink: $target -> $source"
    return 0
}

# Print usage
usage() {
    cat <<EOF
Usage: $0 -r <git_root> -t <ddev_target> [options]

Parse and symlink Moodle plugin git repos to DDEV target

Options:
    -r, --gitRoot PATH          Path to git repo directory containing Moodle plugin repos (required)
    -t, --ddevTarget PATH       Path to ddev target (Moodle root directory) (required)
    --dry-run                   Show what would be done without making changes
    --moodle-version VERSION    Moodle version (default: 5.1). Versions >= 5.1 use public/ folder
    -h, --help                  Show this help message

EOF
    exit 1
}

# Parse arguments
GIT_ROOT=""
DDEV_TARGET=""
DRY_RUN=false
MOODLE_VERSION=5.1

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--gitRoot)
            GIT_ROOT="$2"
            shift 2
            ;;
        -t|--ddevTarget)
            DDEV_TARGET="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --moodle-version)
            MOODLE_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$GIT_ROOT" ]] || [[ -z "$DDEV_TARGET" ]]; then
    echo "ERROR: Both -r/--gitRoot and -t/--ddevTarget are required"
    usage
fi

# Validate paths
if [[ ! -d "$GIT_ROOT" ]]; then
    echo "ERROR: Git root directory does not exist: $GIT_ROOT"
    exit 1
fi

if [[ ! -d "$DDEV_TARGET" ]] && [[ "$DRY_RUN" == "false" ]]; then
    echo "ERROR: DDEV target directory does not exist: $DDEV_TARGET"
    exit 1
fi

echo "Git root: $GIT_ROOT"
echo "DDEV target: $DDEV_TARGET"
echo "Moodle version: $MOODLE_VERSION"
echo "Dry run: $DRY_RUN"
echo

# Arrays to store plugin info for docker-compose generation
declare -a PLUGIN_SOURCES=()
declare -a PLUGIN_TARGETS=()

# Process repos
for repo_dir in "$GIT_ROOT"/*; do
    # Skip if not a directory
    [[ ! -d "$repo_dir" ]] && continue

    repo_name=$(basename "$repo_dir")

    # Parse plugin name
    if ! plugin_info=$(parse_plugin_name "$repo_name"); then
        echo "Skipping $repo_name: Not a valid Moodle plugin repo name"
        continue
    fi

    read -r plugin_type plugin_name <<< "$plugin_info"

    # Get target directory
    if ! target_rel=$(get_plugin_directory "$plugin_type" "$plugin_name" "$MOODLE_VERSION"); then
        echo "WARNING: Unknown plugin type '$plugin_type' for $repo_name"
        continue
    fi

    target_path="${DDEV_TARGET}/moodle/${target_rel}"

    # Create symlink
    if create_symlink "$repo_dir" "$target_path" "$DRY_RUN"; then
        PLUGIN_SOURCES+=("$repo_dir")
        PLUGIN_TARGETS+=("$target_rel")
    fi

    echo "  Type: $plugin_type, Name: $plugin_name"
    echo "  Target: $target_rel"
    echo
done

# Create docker-compose mounts file
if [[ ${#PLUGIN_SOURCES[@]} -gt 0 ]]; then
    compose_file="${DDEV_TARGET}/.ddev/docker-compose.mounts.yaml"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would create $compose_file with content:"
        echo "services:"
        echo "  web:"
        echo "    volumes:"
        for i in "${!PLUGIN_SOURCES[@]}"; do
            echo "      - ${PLUGIN_SOURCES[$i]}:/var/www/html/moodle/${PLUGIN_TARGETS[$i]}"
        done
    else
        mkdir -p "$(dirname "$compose_file")"

        cat > "$compose_file" <<EOF
services:
  web:
    volumes:
EOF
        for i in "${!PLUGIN_SOURCES[@]}"; do
            echo "      - ${PLUGIN_SOURCES[$i]}:/var/www/html/moodle/${PLUGIN_TARGETS[$i]}" >> "$compose_file"
        done

        echo
        echo "Created docker-compose mounts file: $compose_file"
    fi

    echo "Total mounts configured: ${#PLUGIN_SOURCES[@]}"
    echo
    echo "Processed ${#PLUGIN_SOURCES[@]} plugins successfully"
else
    echo "No valid Moodle plugin repos found"
fi
