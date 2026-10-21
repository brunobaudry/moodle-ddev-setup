#!/bin/bash
#
# Setup MoMoPDA AI instructions library and environment in generated Moodle DDEV project.
#
# Run as a post_custom_script by moodle_ddev.sh. Arguments:
#   $1 project_dir     host path of the DDEV approot (mounted at /var/www/html)
#   $2 MOODLE_DOC_ROOT ./moodle, or ./moodle/public on Moodle 5.1+
#   $3 DDEV_DESCRIBE   `ddev describe -j` output
#   $4 moodle_version  $5 php_version  $6 db_type

set -uo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${THIS_SCRIPT_DIR}/../sub/momopda.sh"

project_dir="${1:-$PWD}"
doc_root="${2:-./moodle}"
moodle_version="${4:-}"
php_version="${5:-}"
db_type="${6:-}"

setup_momopda "$project_dir" "$doc_root" "$moodle_version" "$php_version" "$db_type"
