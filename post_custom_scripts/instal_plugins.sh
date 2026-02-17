#!/bin/bash
# echo $1 # Project root
# echo $2 # Moodle public
# echo $3 | jq -r # DDEV describe
# echo $4 # Moodle version
# echo $5 # PHP version
# echo $6 # Database type

# wwwroot=$(echo "$3" | jq -r '.raw.primary_url')
PLUGINS=/Users/bdb3/Documents/dev/git_repos/moodle_plugins_basic
echo "copying plugins dir $PLUGINS to ${1}/${2}"
python3 /Users/bdb3/Documents/dev/_haxe_coding/linux_moodle_copy_git_to_folders/mpm.py $PLUGINS "${1}/${2}"
