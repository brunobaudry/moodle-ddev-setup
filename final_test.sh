#!/bin/bash

echo "=== FINAL VERIFICATION TEST ==="

# Simulate what DDEV would do in the container
echo "1. Testing basic cron functionality in container..."

# Change to Moodle directory (this is where we'd be in the container)
cd /var/www/html 2>/dev/null || echo "Cannot change to /var/www/html"

echo "2. Checking if we can run crontab commands..."
crontab -l 2>/dev/null | head -5 || echo "No crontab found or crontab not working"

echo "3. Running our setup script directly:"
cd /Users/bdb3/Documents/dev/git_repos/moodle-ddev-setup
echo "Current directory: $(pwd)"
if [ -f "post_custom_scripts/setup_moodle_cron.sh" ]; then
    echo "Script exists, running it..."
    ./post_custom_scripts/setup_moodle_cron.sh
else
    echo "Script not found"
fi

echo ""
echo "4. Final verification:"
crontab -l 2>/dev/null | grep -i cron.php && echo "✅ Cron job found" || echo "❌ No cron job found"
