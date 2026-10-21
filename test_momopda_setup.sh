#!/bin/bash
set -euo pipefail

echo "🧪 Running tests for MoMoPDA & AI Agent Environment Setup..."

TMP_TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/moodle_momopda_test_XXXXXX")
trap 'rm -rf "$TMP_TEST_DIR"' EXIT

echo "📁 Using temporary test directory: $TMP_TEST_DIR"

# 1. Setup mock Moodle project structure
mkdir -p "$TMP_TEST_DIR/moodle"
mkdir -p "$TMP_TEST_DIR/moodledata"
mkdir -p "$TMP_TEST_DIR/.ddev"

# 2. Run post_custom_scripts/setup_momopda.sh
echo "⚙️  Executing post_custom_scripts/setup_momopda.sh..."
./post_custom_scripts/setup_momopda.sh "$TMP_TEST_DIR" "./moodle" "{}" "502" "8.4" "mariadb"

# 3. Assertions
assert_file() {
    local path="$1"
    local desc="$2"
    if [[ -f "$path" || -L "$path" ]]; then
        echo "   ✅ $desc ($path)"
    else
        echo "   ❌ FAILED: Missing $desc ($path)"
        exit 1
    fi
}

assert_dir() {
    local path="$1"
    local desc="$2"
    if [[ -d "$path" || -L "$path" ]]; then
        echo "   ✅ $desc ($path)"
    else
        echo "   ❌ FAILED: Missing $desc ($path)"
        exit 1
    fi
}

echo "🔍 Verifying generated files and symlinks..."
assert_dir "$TMP_TEST_DIR/momopda" "MoMoPDA repository directory"
assert_dir "$TMP_TEST_DIR/.prompts" "Prompts directory/symlink"
assert_file "$TMP_TEST_DIR/AGENTS.md" "AGENTS.md orchestrator"
assert_file "$TMP_TEST_DIR/CLAUDE.md" "CLAUDE.md file"
assert_file "$TMP_TEST_DIR/.cursorrules" ".cursorrules file"
assert_file "$TMP_TEST_DIR/.cursor/rules/moodle-momopda.mdc" ".cursor/rules mdc file"
assert_file "$TMP_TEST_DIR/.windsurfrules" ".windsurfrules file"
assert_file "$TMP_TEST_DIR/.github/copilot-instructions.md" "GitHub Copilot instructions"
assert_file "$TMP_TEST_DIR/.junie/guidelines.md" "Junie / JetBrains guidelines"
assert_file "$TMP_TEST_DIR/GEMINI.md" "GEMINI.md file"
assert_file "$TMP_TEST_DIR/.env" "Host .env file"
assert_file "$TMP_TEST_DIR/.env.ai" "Host .env.ai file"
assert_file "$TMP_TEST_DIR/.ddev/docker-compose.momopda.yaml" "DDEV compose override"
assert_file "$TMP_TEST_DIR/.ddev/web-entrypoint.d/moodle-ai-env.sh" "DDEV entrypoint hook"

echo "🔍 Verifying environment variables in .env..."
grep -q "MOODLE_DIR=\"$TMP_TEST_DIR/moodle\"" "$TMP_TEST_DIR/.env" || {
    echo "❌ FAILED: MOODLE_DIR not correctly set in .env"
    exit 1
}
grep -q "MOMOPDA_DIR=\"$TMP_TEST_DIR/momopda\"" "$TMP_TEST_DIR/.env" || {
    echo "❌ FAILED: MOMOPDA_DIR not correctly set in .env"
    exit 1
}

echo "🔍 Verifying DDEV docker-compose environment..."
grep -q "MOODLE_DIR=/var/www/html/moodle" "$TMP_TEST_DIR/.ddev/docker-compose.momopda.yaml" || {
    echo "❌ FAILED: MOODLE_DIR not in docker-compose.momopda.yaml"
    exit 1
}

echo "🔍 Testing idempotency (running setup again)..."
./post_custom_scripts/setup_momopda.sh "$TMP_TEST_DIR" "./moodle" "{}" "502" "8.4" "mariadb"

echo "🔍 Testing --no-momopda option..."
TMP_TEST_NO_AI=$(mktemp -d "${TMPDIR:-/tmp}/moodle_momopda_noai_XXXXXX")
trap 'rm -rf "$TMP_TEST_DIR" "$TMP_TEST_NO_AI"' EXIT
export MOMOPDA_REPO="none"
./post_custom_scripts/setup_momopda.sh "$TMP_TEST_NO_AI" "./moodle" "{}" "502" "8.4" "mariadb"
if [[ -d "$TMP_TEST_NO_AI/momopda" ]]; then
    echo "❌ FAILED: momopda was cloned despite MOMOPDA_REPO=none"
    exit 1
else
    echo "   ✅ --no-momopda correctly bypassed cloning."
fi

echo ""
echo "🎉 ALL MOMOPDA INTEGRATION TESTS PASSED SUCCESSFULLY!"
