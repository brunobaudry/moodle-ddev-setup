#!/bin/bash
# echo $1 # Project root
# echo $2 # Moodle public
# echo $3 | jq -r # DDEV describe
# echo $4 # Moodle version
# echo $5 # PHP version
# echo $6 # Database type
THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS=/Users/bdb3/Documents/dev/git_repos/moodle_plugins_basic
python3 ${THIS_SCRIPT_DIR}/../sub/parse_and_symlink_git_ddev.py -r $PLUGINS -t "${1}" --moodle-version $4
# bash ${THIS_SCRIPT_DIR}/../sub/parse_and_symlink_git_ddev.sh -r $PLUGINS -t "${1}/${2}" --moodle-version $4