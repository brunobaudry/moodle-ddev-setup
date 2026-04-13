#!/bin/bash
# echo "Subscript example/test :"
# echo $1 # Project root
# echo $2 # Moodle public
# echo $3 | jq -r # DDEV describe
# echo $4 # Moodle version
# echo $5 # PHP version
# echo $6 # Database type

# wwwroot=$(echo "$3" | jq -r '.raw.primary_url')
# cp ../templates/backup-moodle2-course-8-testcourse-20250303-0813.mbz $1/moodledata
backupfile="/var/www/html/moodledata/backup-moodle2-course-8-testcourse-20250303-0813-nousers.mbz"
ddev exec ls -la moodledata
ddev exec pwd
echo ">>> restoring Default course $backupfile"
ddev exec php ./moodle/admin/cli/restore_backup.php \
  -f=$backupfile \
  -c=1 \
  -s


# REMOVED from script as the copy will try to backup users.