#!/usr/bin/env bash

makedockerfile_forlocale() {
    set -e

    local TARGET_DIR="$1"
    local TARGET_FILE="$TARGET_DIR/Dockerfile"

    # Ensure the directory exists
    mkdir -p "$TARGET_DIR"

    # Write the Dockerfile content
    cat <<'EOF' > "$TARGET_FILE"
RUN apt-get update && \
    apt-get install -y locales maxima && \
    sed -i '/en_AU.UTF-8/s/^# //' /etc/locale.gen && \
    locale-gen && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
EOF

    echo "Dockerfile created at $TARGET_FILE"
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