#!/usr/bin/env bash

makedockerfile_forlocale() {
    set -e

    local TARGET_DIR="$1"
    local PHP_VERSION="$2"   # e.g., "8.4" — required for version-specific packages
    local TARGET_FILE="$TARGET_DIR/Dockerfile"

    # Ensure the directory exists
    mkdir -p "$TARGET_DIR"

    # pspell is the only notable Moodle extension absent from DDEV's base image.
    # xmlrpc was removed from PHP bundled extensions in 8.1; Moodle 4.5+ dropped
    # the xmlrpc web service plugin entirely — so we do not add it here.
    local EXTRA_PKGS="php${PHP_VERSION}-pspell aspell aspell-en aspell-fr"

    # Write the Dockerfile content
    cat > "$TARGET_FILE" <<EOF
# MoodleHQ-aligned layer for PHP ${PHP_VERSION}
# Adds: pspell, aspell dictionaries, en_AU locale, maxima (for STACK question type)
RUN apt-get update && \\
    apt-get install -y --no-install-recommends \\
        locales \\
        maxima \\
        ${EXTRA_PKGS} && \\
    sed -i '/en_AU.UTF-8/s/^# //' /etc/locale.gen && \\
    locale-gen && \\
    apt-get clean && rm -rf /var/lib/apt/lists/*
EOF

    echo "Dockerfile created at $TARGET_FILE"
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
        set -e
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