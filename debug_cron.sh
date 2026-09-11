#!/bin/bash

echo "🔍 DEBUG: Testing cron setup in current environment"

# Change to Moodle directory
cd /var/www/html || exit 1

echo "Current working directory: $(pwd)"
echo "Files in current directory:"
ls -la | head -10

echo ""
echo "Testing if crontab is accessible:"
crontab -l 2>/dev/null && echo "✅ crontab works" || echo "❌ crontab failed"

echo ""
echo "Checking for cron installation:"
if command -v cron >/dev/null 2>&1; then
    echo "✅ Cron is installed"
else
    echo "❌ Cron is not installed"
fi

echo ""
echo "Contents of setup script:"
cat /Users/bdb3/Documents/dev/git_repos/moodle-ddev-setup/post_custom_scripts/setup_moodle_cron.sh

echo ""
echo "Checking if cron is running:"
ps aux | grep cron | grep -v grep

echo ""
echo "Environment variables:"
env | grep -E "(HOME|PATH)" | head -5
