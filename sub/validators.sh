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
DEFAULT_MOODLE=502
validate_moodle_version() {
  local version="$1"

  if [[ "$version" =~ ^(401|402|403|404|405|500|501|$DEFAULT_MOODLE)$ ]]; then
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
#!/bin/bash
# -------------------------------
# ✅ Enhanced Validation Functions
# -------------------------------

# Database compatibility matrix based on provided CSV data
validate_db_compatibility() {
    local moodle_version="$1"
    local php_version="$2" 
    local db_entry="$3"
    
    # Parse database entry
    local db_type=""
    local db_version=""
    
    if [[ "$db_entry" == *:* ]]; then
        db_type="${db_entry%:*}"
        db_version="${db_entry#*:}"
    else
        db_type="$db_entry"
        db_version=""
    fi
    # Normalize database type
    case "$db_type" in
        mariadb|mariadb:*)
            db_type="mariadb"
            ;;
        mysql|mysqli)
            db_type="mysql"
            ;;
        pgsql|postgres|postgresql)
            db_type="postgresql"
            ;;
        *)
            echo "❌ Unsupported database type: $db_type"
            return 1
            ;;
    esac
    #echo "! requested $db_type with version $db_version"
    # Define compatibility requirements for each Moodle version
    local required_php=""
    local required_mariadb=""
    local required_mysql=""
    local required_postgresql=""
    
    case "$moodle_version" in
        5.2|5.2*|502)
            required_php="8.3"
            required_mariadb="10.11.0"
            required_mysql="8.4"
            required_postgresql="16"
            ;;
        5.1|5.1*|501)
            required_php="8.2"
            required_mariadb="10.11.0"
            required_mysql="8.4"
            required_postgresql="15"
            ;;
        5.0|5.0*|500)
            required_php="8.2"
            required_mariadb="10.11.0"
            required_mysql="8.4"
            required_postgresql="14"
            ;;
        4.5|4.5*|405)
            required_php="8.1"
            required_mariadb="10.6.7"
            required_mysql="8.0"
            required_postgresql="13"
            ;;
        4.4|4.4*|404)
            required_php="8.1"
            required_mariadb="10.6.7"
            required_mysql="8.0"
            required_postgresql="13"
            ;;
        4.3|4.3*|403)
            required_php="8.0"
            required_mariadb="10.6.7"
            required_mysql="8.0"
            required_postgresql="13"
            ;;
        *)
            echo "❌ Unknown Moodle version: $moodle_version"
            return 1
            ;;
    esac
    echo "! requirement for this moodle version $moodle_version are: php $required_php, maria $required_mariadb, pg $required_postgresql, mysql $required_mysql"
    # Validate PHP compatibility (Moodle requires at least the minimum PHP version)
    if [[ "$required_php" =~ ^[0-9]+\.[0-9]+$ ]]; then
        # For versions with +, we just check if PHP is >= required version
        local php_parts=(${php_version//./ })
        local req_parts=(${required_php//./ })
        
        if (( ${php_parts[0]} < ${req_parts[0]} )); then
            echo "❌ PHP version $php_version is not compatible with Moodle $moodle_version. Requires at least PHP $required_php"
            return 1
        elif (( ${php_parts[0]} == ${req_parts[0]} && ${php_parts[1]} < ${req_parts[1]} )); then
            echo "❌ PHP version $php_version is not compatible with Moodle $moodle_version. Requires at least PHP $required_php"
            return 1
        fi
    fi
    
    # Validate database version if provided
    if [[ -n "$db_version" ]]; then
        local required_version=""
        
        case "$db_type" in
            mariadb)
                required_version="$required_mariadb"
                ;;
            mysql)
                required_version="$required_mysql"
                ;;
            postgresql)
                required_version="$required_postgresql"
                ;;
        esac
        
        # Compare versions
        #if [[ "$required_version" =~ ^[0-9]+\.[0-9]+ ]]; then
        if [[ "$required_version" =~ ^[0-9]+(\.[0-9]+){0,2}([[:alpha:]]+[0-9]*)?$ ]]; then
        #echo " # Compare version with required $required_version"

            local db_parts=(${db_version//./ })
            local req_parts=(${required_version//./ })
        #echo "DB parts $db_parts, Req parts $req_parts"
            # Check major version
            if (( ${db_parts[0]} < ${req_parts[0]} )); then
                echo "❌ Database version $db_version is not compatible with Moodle $moodle_version for $db_type. Requires at least $required_version"
                return 1
            elif (( ${db_parts[0]} == ${req_parts[0]} && ${#db_parts[@]} > 1 && ${#req_parts[@]} > 1 )); then
                # Check minor version if both have it
                if (( ${db_parts[1]} < ${req_parts[1]} )); then
                    echo "❌ Database version $db_version is not compatible with Moodle $moodle_version for $db_type. Requires at least $required_version"
                    return 1
                elif (( ${db_parts[1]} == ${req_parts[1]} && ${#db_parts[@]} > 2 && ${#req_parts[@]} > 2 )); then
                    # Check patch version if both have it
                    if (( ${db_parts[2]} < ${req_parts[2]} )); then
                        echo "❌ Database version $db_version is not compatible with Moodle $moodle_version for $db_type. Requires at least $required_version"
                        return 1
                    fi
                fi
            fi
        fi
    fi
    
    # Return the required minimum version for DDEV configuration if no version was provided
    if [[ -z "$db_version" ]]; then
        local min_version=""
        case "$db_type" in
            mariadb)
                min_version="$required_mariadb"
                ;;
            mysql)
                min_version="$required_mysql"
                ;;
            postgresql)
                min_version="$required_postgresql"
                ;;
        esac
        
        echo "minimum_version:$min_version"
    else
        echo "✅ Database entry $db_entry is compatible with Moodle $moodle_version and PHP $php_version"
    fi
    
    return 0
}

# Enhanced DB validation function that includes compatibility checking
validate_db_with_compatibility() {
    local moodle_version="$1"
    local php_version="$2" 
    local db_entry="$3"
    
    # First validate basic DB type
    case "$db_entry" in
        mariadb*|mysql*|pgsql*|mysqli)
            # Basic validation passed, now check compatibility
            validate_db_compatibility "$moodle_version" "$php_version" "$db_entry"
            return $?
            ;;
        *)
            echo "❌ Invalid database entry format. Expected: db_type[:version] (e.g., mariadb:10.11.2)"
            return 1
            ;;
    esac
}

# Get the minimum required version for DDEV configuration
get_min_db_version() {
    local moodle_version="$1"
    local db_type="$2"
    
    # Define compatibility requirements for each Moodle version
    local required_mariadb=""
    local required_mysql=""
    local required_postgresql=""
    
    case "$moodle_version" in
        5.2|5.2*|502)
            required_mariadb="10.11.0"
            required_mysql="8.4"
            required_postgresql="16"
            ;;
        5.1|5.1*|501)
            required_mariadb="10.11.0"
            required_mysql="8.4"
            required_postgresql="15"
            ;;
        5.0|5.0*|500)
            required_mariadb="10.11.0"
            required_mysql="8.4"
            required_postgresql="14"
            ;;
        4.5|4.5*|405)
            required_mariadb="10.6.7"
            required_mysql="8.0"
            required_postgresql="13"
            ;;
        4.4|4.4*|404)
            required_mariadb="10.6.7"
            required_mysql="8.0"
            required_postgresql="13"
            ;;
        4.3|4.3*|403)
            required_mariadb="10.6.7"
            required_mysql="8.0"
            required_postgresql="13"
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
    
    case "$db_type" in
        mariadb)
            echo "$required_mariadb"
            ;;
        mysql)
            echo "$required_mysql"
            ;;
        postgresql)
            echo "$required_postgresql"
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}