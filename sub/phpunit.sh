
#!/bin/bash

# Check if folder parameter is provided
if [ -z "$1" ]|| [ -z "$2" ]; then
    echo "Usage: $0 <folder> <boolean_is_moodle_above_500>"
    exit 1
fi

folder="$1"
IS_MOODLE_ABOVE_500="$2"
config_file="${folder}/moodle/config.php"

# Verify file exists
if [ ! -f "$config_file" ]; then
    echo "Error: $config_file does not exist."
    exit 1
fi

# Use awk to insert before require_once line
awk '
    /require_once.*setup.php/ {
        print "$CFG->phpunit_prefix = \"phpu_\";"
        print "$CFG->phpunit_dataroot = \"/var/www/html/phpu_moodledata\";"
print "// Prevent qtype_stack from trying to build a Maxima auto-image during"
print "// PHPUnit init (it times out on aarch64 and breaks the whole init)."
print "define(\"QTYPE_STACK_TEST_CONFIG_PLATFORM\", \"none\"\);"
        print
        next
    }
    { print }
' "$config_file" > "${config_file}.tmp"
mv "${config_file}.tmp" "$config_file"


echo "Phpunit configuration added successfully before require_once line."
# Optional initialization commands:

INIT_SCRIPT="moodle/admin/tool/phpunit/cli/init.php"
if [[ "$IS_MOODLE_ABOVE_500" == true ]]; then
  INIT_SCRIPT="moodle/public/admin/tool/phpunit/cli/init.php"
fi

echo "🔍 Initializing PHPUNIT..."
if ! ddev exec php "$INIT_SCRIPT"; then
  echo "❌ PHPUNIT initialization failed."
  exit 1
fi

echo "✅ PHPUNIT environment initialized."
