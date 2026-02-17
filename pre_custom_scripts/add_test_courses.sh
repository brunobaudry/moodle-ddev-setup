#!/bin/bash
# echo "Subscript example/test :"
# echo $1 # Project root
# echo $2 # Moodle public
# echo $3 | jq -r # DDEV describe
# echo $4 # Moodle version
# echo $5 # PHP version
# echo $6 # Database type

# wwwroot=$(echo "$3" | jq -r '.raw.primary_url')
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo ">>> Copying Default course from $SCRIPT_DIR to $1"
cp "$SCRIPT_DIR/../templates/backup-moodle2-course-8-testcourse-20250303-0813.mbz" $1/moodledata

# ddev exec php ./moodle/admin/cli/restore_backup.php \
#   --file=$backupfile \
#   --categoryid=1