#!/bin/bash
# ---------------------------------------------------------------------------
# MoMoPDA & AI Agent Environment Integration for Moodle DDEV Setup
# ---------------------------------------------------------------------------
# MoMoPDA (Modular Moodle Plugin Development Assistant) repository:
# https://github.com/wilenius/momopda
# ---------------------------------------------------------------------------

DEFAULT_MOMOPDA_REPO="https://github.com/wilenius/momopda.git"

setup_momopda() {
    local project_dir="$1"
    local doc_root="${2:-./moodle}"
    local moodle_version="${3:-}"
    local php_version="${4:-}"
    local db_type="${5:-}"
    local custom_repo="${6:-${MOMOPDA_REPO:-$DEFAULT_MOMOPDA_REPO}}"

    if [[ -z "$project_dir" || ! -d "$project_dir" ]]; then
        echo "❌ Invalid project directory for MoMoPDA setup: $project_dir"
        return 1
    fi

    if [[ "$custom_repo" == "none" ]]; then
        echo "ℹ️  MoMoPDA AI agent setup disabled (--no-momopda)."
        return 0
    fi

    echo "🤖 Setting up MoMoPDA & AI agent environment in $project_dir..."

    local momopda_target="${project_dir}/momopda"
    local moodle_core_dir="${project_dir}/moodle"

    # 1. Clone or update MoMoPDA repository
    if [[ -d "$momopda_target/.git" ]]; then
        echo "   🔄 Updating existing MoMoPDA repository at $momopda_target..."
        (cd "$momopda_target" && git pull --ff-only >/dev/null 2>&1 || true)
    elif [[ -d "$momopda_target" ]]; then
        echo "   ℹ️  MoMoPDA directory already exists at $momopda_target."
    else
        echo "   📥 Cloning MoMoPDA from $custom_repo..."
        if ! git clone --depth 1 "$custom_repo" "$momopda_target" 2>/dev/null; then
            echo "   ⚠️  Could not clone MoMoPDA repository. Checking for fallback or network..."
        fi
    fi

    # 2. Setup prompt and orchestrator files in the project root
    cd "$project_dir" || return 1

    # Link / copy .prompts directory
    if [[ -d "$momopda_target/.prompts" ]]; then
        if [[ ! -e ".prompts" ]]; then
            ln -sf "momopda/.prompts" ".prompts"
            echo "   ✅ Symlinked .prompts -> momopda/.prompts"
        fi
    fi

    # Link / create AGENTS.md orchestrator
    if [[ -f "$momopda_target/AGENTS.md" ]]; then
        if [[ ! -e "AGENTS.md" ]]; then
            ln -sf "momopda/AGENTS.md" "AGENTS.md"
            echo "   ✅ Symlinked AGENTS.md -> momopda/AGENTS.md"
        fi
    fi

    # Link / create CLAUDE.md for Claude Code CLI
    if [[ -f "$momopda_target/CLAUDE.md" ]]; then
        if [[ ! -e "CLAUDE.md" ]]; then
            ln -sf "momopda/CLAUDE.md" "CLAUDE.md"
            echo "   ✅ Symlinked CLAUDE.md -> momopda/CLAUDE.md"
        fi
    else
        cat > "CLAUDE.md" <<'EOF'
<!-- CLAUDE.md -->
Read and follow the project guidelines in AGENTS.md.
EOF
        echo "   ✅ Created CLAUDE.md"
    fi

    # Cursor AI rules (.cursorrules and .cursor/rules)
    cat > ".cursorrules" <<'EOF'
# Cursor AI Rules for Moodle Development (MoMoPDA)
You are an expert Moodle development assistant.
Follow the conditional prompt loading system and standards defined in AGENTS.md and .prompts/ directory.

Always refer to:
- Core instructions: .prompts/core/base-instructions.md
- Security checklist: .prompts/core/security-checklist.md
- CI validation & testing: .prompts/core/ci-validation.md
- Plugin specific guides: .prompts/plugins/<plugin_type>.md

Moodle core directory is located at ./moodle/ (reference only).
Environment variable MOODLE_DIR is set to the Moodle core location.
EOF

    mkdir -p ".cursor/rules"
    cat > ".cursor/rules/moodle-momopda.mdc" <<'EOF'
---
description: Moodle Plugin Development with MoMoPDA Instructions
globs: ["**/*.php", "**/*.js", "**/*.mustache", "**/*.css", "**/*.xml"]
---
# Moodle Development Rules (MoMoPDA)
Follow the guidelines and architecture specified in AGENTS.md.
- Follow Moodle coding style and frankenstyle component naming.
- Enforce capability checks (require_capability, has_capability) and CSRF protection (sesskey).
- Use Moodle DB API ($DB) with parameter binding. Never concatenate SQL variables.
- Reference Moodle core files at ./moodle/ without modifying core directly.
EOF
    echo "   ✅ Configured Cursor rules (.cursorrules, .cursor/rules/moodle-momopda.mdc)"

    # Windsurf rules (.windsurfrules)
    cat > ".windsurfrules" <<'EOF'
# Windsurf Rules for Moodle Development (MoMoPDA)
Follow the project instructions and prompt system in AGENTS.md and .prompts/.
Core Moodle code is located at ./moodle/. Use MOODLE_DIR environment variable for CI validation.
EOF
    echo "   ✅ Configured Windsurf rules (.windsurfrules)"

    # GitHub Copilot instructions (.github/copilot-instructions.md)
    mkdir -p ".github"
    cat > ".github/copilot-instructions.md" <<'EOF'
# GitHub Copilot Instructions for Moodle Development (MoMoPDA)
Follow all instructions and guidelines in AGENTS.md and the .prompts/ directory.
- Follow Moodle Frankenstyle plugin architecture.
- Enforce strict security (CSRF, SQL injection prevention, capability checks).
- Follow CI validation rules outlined in .prompts/core/ci-validation.md.
- Core Moodle directory is located at ./moodle/.
EOF
    echo "   ✅ Configured GitHub Copilot instructions (.github/copilot-instructions.md)"

    # JetBrains / Junie guidelines (.junie/guidelines.md)
    mkdir -p ".junie"
    cat > ".junie/guidelines.md" <<'EOF'
# Junie / JetBrains AI Guidelines for Moodle Development (MoMoPDA)
Follow all Moodle development rules and prompt structures defined in AGENTS.md and .prompts/.
Moodle core reference is at ./moodle/ and MOODLE_DIR environment variable points to Moodle core.
EOF
    echo "   ✅ Configured JetBrains / Junie guidelines (.junie/guidelines.md)"

    # Gemini rules (GEMINI.md)
    cat > "GEMINI.md" <<'EOF'
# Gemini Instructions for Moodle Development
Read and follow the guidelines and conditional loading system in AGENTS.md.
EOF
    echo "   ✅ Configured GEMINI.md"

    # 3. Host Environment configuration (.env & .env.ai)
    cat > ".env.ai" <<EOF
# MoMoPDA and AI Environment Configuration
MOODLE_DIR="${moodle_core_dir}"
MOMOPDA_DIR="${momopda_target}"
MOODLE_VERSION="${moodle_version}"
PHP_VERSION="${php_version}"
DB_TYPE="${db_type}"
EOF

    if [[ ! -f ".env" ]]; then
        cp ".env.ai" ".env"
    else
        # Append MOODLE_DIR if not present
        if ! grep -q "^MOODLE_DIR=" ".env"; then
            echo "" >> ".env"
            echo "# MoMoPDA AI Environment" >> ".env"
            echo "MOODLE_DIR=\"${moodle_core_dir}\"" >> ".env"
            echo "MOMOPDA_DIR=\"${momopda_target}\"" >> ".env"
        fi
    fi
    echo "   ✅ Configured host environment files (.env, .env.ai)"

    # 4. DDEV Container Environment configuration
    mkdir -p ".ddev"
    cat > ".ddev/docker-compose.momopda.yaml" <<'EOF'
# DDEV docker-compose override for MoMoPDA & AI Agent Environment
services:
  web:
    environment:
      - MOODLE_DIR=/var/www/html/moodle
      - MOMOPDA_DIR=/var/www/html/momopda
EOF
    echo "   ✅ Configured DDEV container environment (.ddev/docker-compose.momopda.yaml)"

    # Startup entrypoint script inside container for environment variables
    mkdir -p ".ddev/web-entrypoint.d"
    cat > ".ddev/web-entrypoint.d/moodle-ai-env.sh" <<'EOF'
#!/bin/bash
# Export MOODLE_DIR and MOMOPDA_DIR to container profile and environment
echo "export MOODLE_DIR=/var/www/html/moodle" | sudo tee /etc/profile.d/moodle-ai-env.sh >/dev/null
echo "export MOMOPDA_DIR=/var/www/html/momopda" | sudo tee -a /etc/profile.d/moodle-ai-env.sh >/dev/null
sudo chmod 0644 /etc/profile.d/moodle-ai-env.sh

if grep -q "MOODLE_DIR" /etc/environment 2>/dev/null; then
    sudo sed -i 's|^MOODLE_DIR=.*|MOODLE_DIR=/var/www/html/moodle|' /etc/environment
else
    echo "MOODLE_DIR=/var/www/html/moodle" | sudo tee -a /etc/environment >/dev/null
fi
EOF
    chmod +x ".ddev/web-entrypoint.d/moodle-ai-env.sh"
    echo "   ✅ Configured container entrypoint hook (.ddev/web-entrypoint.d/moodle-ai-env.sh)"

    echo "✅ MoMoPDA & AI agent environment setup completed."
}
