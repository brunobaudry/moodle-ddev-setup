#!/usr/bin/env bash

# The locale Moodle hardcodes for its test runners.
# See phpunit_util::get_locale_name() — it is not configurable via $CFG.
MOODLE_REQUIRED_LOCALE="en_AU.UTF-8"

makedockerfile_forlocale() {
    local TARGET_DIR="$1"
    local PHP_VERSION="$2"   # e.g., "8.4" — required for version-specific packages
    local TARGET_FILE="$TARGET_DIR/Dockerfile"

    # Ensure the directory exists
    mkdir -p "$TARGET_DIR" || return 1

    # pspell is the only notable Moodle extension absent from DDEV's base image.
    # xmlrpc was removed from PHP bundled extensions in 8.1; Moodle 4.5+ dropped
    # the xmlrpc web service plugin entirely — so we do not add it here.
    local EXTRA_PKGS="php${PHP_VERSION}-pspell aspell aspell-en aspell-fr"

    # Write the Dockerfile content
    cat > "$TARGET_FILE" <<EOF
# MoodleHQ-aligned layer for PHP ${PHP_VERSION}
# Adds: pspell, aspell dictionaries, ${MOODLE_REQUIRED_LOCALE} locale, maxima (for STACK question type)
#
# Locale note: DDEV's web image ships a *pre-trimmed* /etc/locale.gen holding
# only a handful of already-uncommented locales — there is no en_AU entry to
# uncomment. So the line has to be appended, not un-commented. Moodle then
# needs setlocale(LC_TIME, 'en_AU.UTF-8') to succeed or both
# admin/tool/phpunit/cli/init.php and the Behat runner abort with
# "Required locale 'en_AU.UTF-8' is not installed."
RUN set -eu; \\
    apt-get update; \\
    apt-get install -y --no-install-recommends \\
        locales \\
        maxima \\
        ${EXTRA_PKGS}; \\
    grep -qE '^[[:space:]]*${MOODLE_REQUIRED_LOCALE}[[:space:]]+UTF-8' /etc/locale.gen \\
        || echo '${MOODLE_REQUIRED_LOCALE} UTF-8' >> /etc/locale.gen; \\
    locale-gen; \\
    locale -a | grep -qix 'en_AU.utf8' \\
        || { echo "FATAL: ${MOODLE_REQUIRED_LOCALE} was not generated"; exit 1; }; \\
    apt-get clean; rm -rf /var/lib/apt/lists/*
EOF

    echo "Dockerfile created at $TARGET_FILE"
}

# Verify the locale Moodle demands really exists in the *running* web container.
# The image build already asserts it, but this catches the case where the build
# was served from a stale cache layer or the Dockerfile never got applied —
# which is exactly how you end up debugging a cryptic phpunit init failure.
assert_locale_available() {
    echo "🔍 Verifying ${MOODLE_REQUIRED_LOCALE} locale in the web container..."
    if ddev exec php -r \
        "exit(setlocale(LC_TIME, '${MOODLE_REQUIRED_LOCALE}') === false ? 1 : 0);" \
        >/dev/null 2>&1; then
        echo "✅ Locale ${MOODLE_REQUIRED_LOCALE} available."
        return 0
    fi

    echo "❌ Locale ${MOODLE_REQUIRED_LOCALE} is missing from the web container."
    echo "   Moodle's PHPUnit/Behat init will fail with:"
    echo "     Required locale '${MOODLE_REQUIRED_LOCALE}' is not installed."
    echo "   The .ddev/web-build/Dockerfile should have generated it. Try:"
    echo "     ddev exec 'locale -a'                 # what the container has"
    echo "     ddev restart                          # rebuild the web image"
    return 1
}

# PHP ini settings that align with moodlehq/moodle-php-apache defaults.
# Lives in .ddev/php/ so DDEV picks it up automatically — not baked into image.
makemoodleini() {
    local TARGET_DIR="$1"   # pass ".ddev/php"
    mkdir -p "$TARGET_DIR"
    cat > "$TARGET_DIR/moodle.ini" <<'EOF'
; MoodleHQ-aligned PHP settings
memory_limit = 512M
max_input_vars = 5000
upload_max_filesize = 100M
post_max_size = 100M
max_execution_time = 300
EOF
    echo "PHP ini created at $TARGET_DIR/moodle.ini"
}

makeselenium(){
    local TARGET_DIR="$1"
    local TARGET_FILE="$TARGET_DIR/docker-compose.selenium.override.yaml"
    cat <<EOF > "$TARGET_FILE"
services:
  selenium-chrome:
    image: seleniarm/standalone-chromium:latest
    container_name: ${host_name}-selenium-chrome
    ports:
      - "4444"
    networks:
      - default
EOF
}