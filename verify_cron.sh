#!/bin/bash

echo "🔍 Verifying Moodle cron setup..."

# Change to Moodle directory
cd /var/www/html || exit 1

# Test if cron is available
if command -v cron >/dev/null 2>&1; then
    echo "✅ Cron is installed"
else
    echo "❌ Cron is not installed"
fi

# Test if we can see cron jobs
echo "📝 Current crontab entries:"
crontab -l 2>/dev/null || echo "No crontab found"

# Test if Moodle cron job exists
if crontab -l 2>/dev/null | grep -q "admin/cli/cron.php"; then
    echo "✅ Moodle cron job found in crontab"
else
    echo "⚠️  Moodle cron job NOT found in crontab"
fi

# Show what the cron command would do
echo "🧪 Testing direct cron execution:"
php admin/cli/cron.php --help | head -5

echo ""
echo "💡 To test the full functionality, run:"
echo "   ddev restart"
echo "   ddev exec crontab -l"
echo "   Then check if cron jobs are running properly"
