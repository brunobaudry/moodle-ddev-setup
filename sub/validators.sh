#!/bin/bash
# -------------------------------
# ✅ Validation Functions
# -------------------------------
DEFAULT_PHP=8.4
# ------ PHP --------------------
validate_php_version() {
  case "$1" in
    7.4|8.0|8.1|8.2|8.3|"$DEFAULT_PHP") return 0 ;;
    *) return 1 ;;
  esac
}
# ------ MOODLE ------------------
DEFAULT_MOODLE=501
validate_moodle_version() {
  local version="$1"

  if [[ "$version" =~ ^(401|402|403|404|405|500|$DEFAULT_MOODLE|502)$ ]]; then
    return 0
  elif [[ "$version" =~ ^(4\.[0-5]\.[0-9]+|5\.0\.[0-9]+|5\.1\.[0-9]+|5\.2\.[0-9]+)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ------ MOODLE vs PHP -------------
validate_compatibility() {
  local input="$1"
  local php="$2"
  local moodle=""

  # Normalize Moodle version
  if [[ "$input" =~ ^MOODLE_([0-9]{3})_STABLE$ ]]; then
    moodle="${BASH_REMATCH[1]}"
  elif [[ "$input" =~ ^([0-9]+)\.([0-9]+)(\.[0-9]+)?$ ]]; then
    # Convert semantic version: major.minor → major*100 + minor
    moodle="$(( ${BASH_REMATCH[1]} * 100 + ${BASH_REMATCH[2]} ))"
  elif [[ "$input" =~ ^[0-9]{3}$ ]]; then
    moodle="$input"
  else
    return 1  # Invalid format
  fi

  # Compatibility checks
  case "$moodle" in
    401)
      [[ "$php" =~ ^(7\.4|8\.0|8\.1)$ ]] && return 0
      ;;
    402|403)
      [[ "$php" =~ ^(8\.0|8\.1|8\.2)$ ]] && return 0
      ;;
    404|405)
      [[ "$php" =~ ^(8\.1|8\.2|8\.3)$ ]] && return 0
      ;;
    500|501)
      [[ "$php" =~ ^(8\.2|8\.3|8\.4)$ ]] && return 0
      ;;
    502)
      [[ "$php" =~ ^(8\.3|8\.4|8\.5)$ ]] && return 0
      ;;  
  esac

  return 1
}
# ---------- MOODLE 5.1 + -------------
IS_MOODLE_ABOVE_500=false
is_moodle_version_5_1_or_higher() {
  local version="$1"
  if [[ "$version" =~ ^[0-9]{3}$ ]]; then
    local major="${version:0:1}"
    local minor="${version:1:2}"
    if (( major > 5 || (major == 5 && minor >= 1) )) ; then
      IS_MOODLE_ABOVE_500=true
    fi
  elif [[ "$version" =~ ^([0-9]+)\.([0-9]+)(\.[0-9]+)?$ ]]; then
    local major="${BASH_REMATCH[1]}"
    local minor="${BASH_REMATCH[2]}"
    if (( major > 5 || (major == 5 && minor >= 1) )); then 
      IS_MOODLE_ABOVE_500=true
    fi
  fi
  return 1
}

# ------------ DBs --------------
DEFAULT_DB=mariadb
validate_db(){
  case "$1" in
    "$DEFAULT_DB"|mysqli|pgsql) return 0 ;;
    *) return 1 ;;
  esac
}