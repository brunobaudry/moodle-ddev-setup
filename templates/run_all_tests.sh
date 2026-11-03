#!/bin/bash
# ==============================================================================
# run_all_tests.sh
#
# Universal test runner for Moodle: runs both PHPUnit and Behat test suites.
# Works from:
#   - Project root (alongside rebase_moodle_upstream.sh and .ddev/)
#   - Moodle root (moodle/)
#   - Any plugin directory (e.g. moodle/public/local/myplugin/)
#
# Automatically delegates execution to DDEV when run from the host.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR_REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
DDEV_MOUNT="/var/www/html"

# ------------------------------------------------------------------------------
# Help and Usage
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Runs both PHPUnit and Behat test suites for Moodle or a specific plugin.

Options:
  --phpunit-only          Run only PHPUnit tests.
  --behat-only            Run only Behat tests.
  --feature               Run only Behat tests on the feature.
  --filter <FILTER>       Filter for PHPUnit tests (e.g., test class or method).
  --testsuite <SUITE>     Specify PHPUnit testsuite (default: auto-detected plugin suite or all).
  --tags <TAGS>           Specify Behat tags (default: @<component> or all).
  --profile <PROFILE>     Behat profile to use (default: chrome).
  --init                  Force re-initialization of PHPUnit and Behat environments.
  --deprecations          Show PHPUnit deprecation notices.
  --fail-fast             Stop on first failure (applies to both PHPUnit and Behat).
  -h, --help              Show this help message.

Environment Variables:
  MOODLE_DDEV_ROOT        Override/pin DDEV project root path.
  BEHAT_PROFILE           Default Behat profile (e.g., chrome, firefox).
  XDEBUG_MODE             Controls Xdebug mode (default: off).

Examples:
  $0                                                      Run all PHPUnit and Behat tests.
  $0 --filter test_something                              Run PHPUnit with filter and then Behat.
  $0 --tags "@javascript"                                 Run PHPUnit, then Behat with @javascript tag.
  $0 --feature "path/to/my.feature"                       Run path/to/my.feature Behat only.
  $0 --feature "path/to/my.feature" --tags "@javascript"  Run path/to/my.feature Behat with @javascript tag only.
  $0 --init                                               Re-initialize environments before running.
EOF
}

# ------------------------------------------------------------------------------
# Environment and Layout Detection
# ------------------------------------------------------------------------------
in_container() {
    [[ -n "${IS_DDEV_PROJECT:-}" || -n "${DDEV_SITENAME:-}" || -f "/.dockerenv" ]]
}

find_ddev_root() {
    local dir="$1"
    while [[ -n "$dir" && "$dir" != "/" ]]; do
        if [[ -f "$dir/.ddev/config.yaml" ]]; then
            echo "${dir%/}"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

ddev_project_status() {
    local dir="$1"
    local json
    json=$(cd "$dir" && ddev describe -j 2>/dev/null) || return 1
    if command -v jq &>/dev/null; then
        jq -r '.raw.status // empty' <<<"$json"
    elif [[ "$json" == *'"status":"running"'* ]]; then
        echo "running"
    fi
}

# Delegate to DDEV if invoked from host
ddev_delegate() {
    in_container && return 0
    command -v ddev &>/dev/null || return 0

    local ddev_root=""
    if [[ -n "${MOODLE_DDEV_ROOT:-}" ]]; then
        ddev_root="${MOODLE_DDEV_ROOT%/}"
    elif ddev_root=$(find_ddev_root "$SCRIPT_DIR"); then
        :
    elif ddev_root=$(find_ddev_root "$SCRIPT_DIR_REAL"); then
        :
    fi

    if [[ -n "$ddev_root" && -d "$ddev_root" ]]; then
        local subpath="${SCRIPT_DIR_REAL#"$ddev_root"}"
        subpath="${subpath#/}"
        local container_dir="$DDEV_MOUNT${subpath:+/$subpath}"
        local ddev_status
        ddev_status=$(ddev_project_status "$ddev_root") || ddev_status=""

        if [[ "$ddev_status" == "running" ]]; then
            echo "DDEV project : $ddev_root"
            echo "Container dir: $container_dir"
            echo "Delegating execution to DDEV web container..."
            (cd "$ddev_root" && ddev exec --dir "$container_dir" bash "$SCRIPT_NAME" "$@")
            exit $?
        else
            echo "ERROR: DDEV project found at $ddev_root but is not running ($ddev_status)."
            echo "       Behat and PHPUnit in this environment require the DDEV container."
            echo "       Please start DDEV with: (cd \"$ddev_root\" && ddev start)"
            exit 1
        fi
    fi
    return 0
}

ddev_delegate "$@"

# ------------------------------------------------------------------------------
# Moodle Layout and Component Resolution
# ------------------------------------------------------------------------------
detect_moodle_layout() {
    DIRROOT=""
    MOODLE_ROOT=""
    MOODLE_LAYOUT=""

    local candidate
    local candidates=(
        "$SCRIPT_DIR/moodle/public"
        "$SCRIPT_DIR_REAL/moodle/public"
        "$SCRIPT_DIR/moodle"
        "$SCRIPT_DIR_REAL/moodle"
        "$SCRIPT_DIR/public"
        "$SCRIPT_DIR_REAL/public"
        "$SCRIPT_DIR"
        "$SCRIPT_DIR_REAL"
        "$SCRIPT_DIR/../.."
        "$SCRIPT_DIR_REAL/../.."
        "$PWD/moodle/public"
        "$PWD/moodle"
        "$PWD/public"
        "$PWD"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate/admin" && -f "$candidate/lib/setup.php" ]]; then
            DIRROOT="$(cd "$candidate" && pwd)"
            break
        fi
        if [[ -d "$candidate/public/admin" && -f "$candidate/public/lib/setup.php" ]]; then
            DIRROOT="$(cd "$candidate/public" && pwd)"
            break
        fi
    done

    if [[ -z "$DIRROOT" ]]; then
        echo "ERROR: Could not locate Moodle dirroot (admin/ and lib/setup.php not found)."
        exit 1
    fi

    if [[ "$(basename "$DIRROOT")" == "public" && -f "$DIRROOT/../config.php" ]]; then
        MOODLE_ROOT="$(cd "$DIRROOT/.." && pwd)"
        MOODLE_LAYOUT="public"
    else
        MOODLE_ROOT="$DIRROOT"
        MOODLE_LAYOUT="classic"
    fi
}

detect_plugin_component() {
    COMPONENT=""
    local version_file=""
    if [[ -f "$SCRIPT_DIR/version.php" ]]; then
        version_file="$SCRIPT_DIR/version.php"
    elif [[ -f "$PWD/version.php" ]]; then
        version_file="$PWD/version.php"
    fi

    if [[ -n "$version_file" ]]; then
        COMPONENT=$(grep -m1 -oE "component[[:space:]]*=[[:space:]]*'[^']+'" "$version_file" 2>/dev/null \
                    | grep -oE "'[^']+'" | tr -d "'" || echo "")
    fi
}

moodle_cfg() {
    local file="$MOODLE_ROOT/config.php"
    [[ -f "$file" ]] || file="$DIRROOT/config.php"
    [[ -f "$file" ]] || return 1
    sed -nE "s/^[[:space:]]*\\\$CFG->$1[[:space:]]*=[[:space:]]*['\"]([^'\"]*)['\"].*/\\1/p" "$file" | head -n1
}

moodle_vendor_bin() {
    local bin="$1" root
    for root in "$MOODLE_ROOT" "$DIRROOT"; do
        if [[ -x "$root/vendor/bin/$bin" ]]; then
            echo "$root/vendor/bin/$bin"
            return 0
        fi
    done
    return 1
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
RUN_PHPUNIT=true
RUN_BEHAT=true
PHPUNIT_FILTER=""
PHPUNIT_TESTSUITE=""
BEHAT_TAGS=""
BEHAT_PROFILE="${BEHAT_PROFILE:-chrome}"
FORCE_INIT=false
SHOW_DEPRECATIONS=false
FAIL_FAST=false
BEHAT_FEATURE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --feature)
            BEHAT_FEATURE="$2"
            RUN_PHPUNIT=false
            RUN_BEHAT=true
            shift 2
            ;;
        --phpunit-only)
            RUN_PHPUNIT=true
            RUN_BEHAT=false
            shift
            ;;
        --behat-only)
            RUN_PHPUNIT=false
            RUN_BEHAT=true
            shift
            ;;
        --filter)
            PHPUNIT_FILTER="$2"
            shift 2
            ;;
        --testsuite)
            PHPUNIT_TESTSUITE="$2"
            shift 2
            ;;
        --tags)
            BEHAT_TAGS="$2"
            shift 2
            ;;
        --profile)
            BEHAT_PROFILE="$2"
            shift 2
            ;;
        --init)
            FORCE_INIT=true
            shift
            ;;
        --deprecations)
            SHOW_DEPRECATIONS=true
            shift
            ;;
        --fail-fast)
            FAIL_FAST=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

detect_moodle_layout
detect_plugin_component

echo "================================================================================"
echo " Moodle Test Suite Runner"
echo " Layout   : $MOODLE_LAYOUT"
echo " Root     : $MOODLE_ROOT"
echo " Dirroot  : $DIRROOT"
[[ -n "$COMPONENT" ]] && echo " Component: $COMPONENT"
echo "================================================================================"

export XDEBUG_MODE="${XDEBUG_MODE:-off}"

# ------------------------------------------------------------------------------
# 1. PHPUnit Execution
# ------------------------------------------------------------------------------
run_phpunit() {
    echo
    echo ">>> Running PHPUnit Tests..."

    local phpunit_bin
    phpunit_bin=$(moodle_vendor_bin phpunit) || {
        echo "ERROR: vendor/bin/phpunit not found. Run 'composer install' in $MOODLE_ROOT."
        return 1
    }

    local phpunit_xml=""
    for r in "$MOODLE_ROOT" "$DIRROOT"; do
        if [[ -f "$r/phpunit.xml" ]]; then
            phpunit_xml="$r/phpunit.xml"
            break
        fi
    done

    local suite="${PHPUNIT_TESTSUITE}"
    if [[ -z "$suite" && -n "$COMPONENT" ]]; then
        suite="${COMPONENT}_testsuite"
    fi

    # Initialize if forced or not initialized yet
    if $FORCE_INIT || [[ -z "$phpunit_xml" ]] || [[ -n "$suite" && ! $(grep -F "name=\"$suite\"" "$phpunit_xml" 2>/dev/null) ]]; then
        echo "Initialising Moodle PHPUnit environment..."
        php "$DIRROOT/admin/tool/phpunit/cli/init.php"
        for r in "$MOODLE_ROOT" "$DIRROOT"; do
            [[ -f "$r/phpunit.xml" ]] && phpunit_xml="$r/phpunit.xml" && break
        done
    fi

    local cmd=("$phpunit_bin" --colors)
    [[ -n "$suite" ]] && cmd+=(--testsuite "$suite")
    [[ -n "$PHPUNIT_FILTER" ]] && cmd+=(--filter "$PHPUNIT_FILTER")
    $SHOW_DEPRECATIONS && cmd+=(--display-deprecations)
    $FAIL_FAST && cmd+=(--stop-on-failure)

    echo "Command: (cd $(dirname "$phpunit_xml") && ${cmd[*]})"
    (cd "$(dirname "$phpunit_xml")" && "${cmd[@]}")
}

# ------------------------------------------------------------------------------
# 2. Behat Execution
# ------------------------------------------------------------------------------
run_behat() {
    echo
    echo ">>> Running Behat Tests..."

    local behat_bin
    behat_bin=$(moodle_vendor_bin behat) || {
        echo "ERROR: vendor/bin/behat not found. Run 'composer install' in $MOODLE_ROOT."
        return 1
    }

    local behat_dataroot
    behat_dataroot=$(moodle_cfg behat_dataroot)
    if [[ -z "$behat_dataroot" || ! -d "$(dirname "$behat_dataroot")" ]]; then
        behat_dataroot="$MOODLE_ROOT/../behat_moodle"
    fi

    local behat_config="$behat_dataroot/behatrun/behat/behat.yml"
    local init_behat="$DIRROOT/admin/tool/behat/cli/init.php"

    local tags="${BEHAT_TAGS}"
    if [[ -z "$tags" && -n "$COMPONENT" ]]; then
        tags="@${COMPONENT}"
    fi

    # Verify wwwroot reachability
    local wwwroot
    wwwroot=$(moodle_cfg behat_wwwroot)
    if [[ -n "$wwwroot" ]] && command -v curl &>/dev/null; then
        local code
        code=$(curl -sS -o /dev/null -m 10 -w '%{http_code}' "$wwwroot/" 2>/dev/null || echo "")
        if [[ -z "$code" || "$code" == "000" ]]; then
            echo "WARNING: \$CFG->behat_wwwroot ($wwwroot) is not reachable via curl."
        fi
    fi

    if $FORCE_INIT || [[ ! -f "$behat_config" ]]; then
        echo "Initialising Moodle Behat environment..."
        php "$init_behat"
    fi

    local cmd=("$behat_bin" --config "$behat_config" --profile "$BEHAT_PROFILE" -vvv)
    [[ -n "$BEHAT_FEATURE" ]] && cmd+=("$BEHAT_FEATURE")
    [[ -n "$tags" ]] && cmd+=("--tags=$tags")
    $FAIL_FAST && cmd+=(--stop-on-failure)

    echo "Command: ${cmd[*]}"
    "${cmd[@]}"
}

# ------------------------------------------------------------------------------
# Main Dispatcher
# ------------------------------------------------------------------------------
EXIT_CODE=0

if $RUN_PHPUNIT; then
    set +e
    run_phpunit
    PHPUNIT_STATUS=$?
    set -e
    if [[ $PHPUNIT_STATUS -ne 0 ]]; then
        EXIT_CODE=$PHPUNIT_STATUS
        echo "PHPUnit tests failed with exit code $EXIT_CODE."
        $FAIL_FAST && exit $EXIT_CODE
    fi
fi

if $RUN_BEHAT; then
    set +e
    run_behat
    BEHAT_STATUS=$?
    set -e
    if [[ $BEHAT_STATUS -ne 0 ]]; then
        echo "Behat tests failed with exit code $BEHAT_STATUS."
        [[ $EXIT_CODE -eq 0 ]] && EXIT_CODE=$BEHAT_STATUS
    fi
fi

if [[ $EXIT_CODE -eq 0 ]]; then
    echo
    echo "================================================================================"
    echo " All requested test suites completed successfully!"
    echo "================================================================================"
fi

exit $EXIT_CODE
