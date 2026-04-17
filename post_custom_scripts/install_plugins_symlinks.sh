#!/bin/bash
# echo $1 # Project root
# echo $2 # Moodle public
# echo $3 | jq -r # DDEV describe
# echo $4 # Moodle version
# echo $5 # PHP version
# echo $6 # Database type
THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${THIS_SCRIPT_DIR}/.."

# Set MOODLE_PLUGINS_REPO in your shell profile (e.g. ~/.zshrc) to point at the
# directory containing your plugin repos (named moodle-TYPE_name).
PLUGINS="${MOODLE_PLUGINS_REPO:-/Users/bdb3/Documents/dev/git_repos/moodle_plugins_basic}"

if [[ ! -d "$PLUGINS" ]]; then
    echo "⚠️  Plugin repo not found at: $PLUGINS"
    echo "   Set MOODLE_PLUGINS_REPO env var to your plugin directory — skipping."
    exit 0
fi

# Prefer the repo's .venv (has pyyaml) over the system python3.
if [[ -x "${REPO_ROOT}/.venv/bin/python3" ]]; then
    PYTHON="${REPO_ROOT}/.venv/bin/python3"
else
    PYTHON="python3"
fi

"$PYTHON" "${THIS_SCRIPT_DIR}/../sub/parse_and_symlink_git_ddev.py" \
    -r "$PLUGINS" \
    -t "${1}" \
    --moodle-version "$4"