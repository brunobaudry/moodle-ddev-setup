
#!/bin/bash

# Usage: ./init-behat.sh <project-folder> <hostname>
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: $0 <project-folder> <hostname> <boolean_is_moodle_above_500>"
    exit 1
fi

folder="$1"
hostname="$2"
IS_MOODLE_ABOVE_500="$3"
config_file="${folder}/moodle/config.php"

# Absolute path for behat dataroot inside container
behat_dataroot="/var/www/html/behat_moodle"

# Verify file exists
if [ ! -f "$config_file" ]; then
    echo "Error: $config_file does not exist."
    exit 1
fi

# Insert Behat configuration before require_once line

awk -v behat_dataroot="$behat_dataroot" -v hostname="$hostname" '
    /require_once.*setup.php/ {
        print "$CFG->behat_prefix = '\''behat_'\'';"
        print "$CFG->behat_dataroot = \"" behat_dataroot "\";"
        print "$CFG->behat_wwwroot = \"http://" hostname ".local\";"
        print "$CFG->behat_profiles = ["
        print "    '\''chrome'\'' => ["
        print "        '\''browser'\'' => '\''chrome'\'',"
        print "        '\''wd_host'\'' => '\''http://selenium-chrome:4444/wd/hub'\''"
        print "    ],"
        print "    '\''firefox'\'' => ["
        print "        '\''browser'\'' => '\''firefox'\'',"
        print "        '\''wd_host'\'' => '\''http://selenium-firefox:4444/wd/hub'\''"
        print "    ]"
        print "];"
        print
        next
    }
    { print }
' "$config_file" > "${config_file}.tmp"
mv "${config_file}.tmp" "$config_file"

echo "Behat configuration added successfully before require_once line."

# Optional initialization commands:
INIT_SCRIPT="moodle/admin/tool/behat/cli/init.php"
if [[ "$IS_MOODLE_ABOVE_500" == true ]]; then
  INIT_SCRIPT="moodle/public/admin/tool/behat/cli/init.php"
fi
echo "🔍 Initializing Behat environment..."
if ! ddev exec php "$INIT_SCRIPT"; then
  echo "❌ Behat initialization failed."
  exit 1
fi

echo "✅ Behat environment initialized."
