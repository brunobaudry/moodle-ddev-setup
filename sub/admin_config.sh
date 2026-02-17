
# -------------------------------
# Function: Resolve and Validate CSV Admin Config
# -------------------------------
resolve_csv_admin_cfg() {
    local cfg="$1"

    # If empty, prompt user with instructions
    if [[ -z "$cfg" ]]; then
        read -e -p "Admin configs CSV. Enter the path (relative to '$SCRIPT_DIR') of a NAME,VALUE UTF-8 CSV file ($ADMIN_CFG_INSTRUCTIONS): " cfg
        [[ -z "$cfg" ]] && cfg="$ADMIN_CFG_INSTRUCTIONS"
    fi

    # Handle special case 'none'
    if [[ "$cfg" == "leave empty if none" || "$cfg" == "none" ]]; then
        echo ""
        return
    fi
    filepath=$cfg
    # Resolve path
    if [[ "$cfg" = /* ]]; then
        cfg="$(realpath "$cfg")"
    elif [[ "$cfg" = ~* ]]; then
        cfg="$(realpath "$HOME/${cfg:1}")"
    else
        cfg="$(realpath "$SCRIPT_DIR/$cfg")"
    fi

    # Validate file existence
    if [[ ! -f "$cfg" ]]; then
        echo "❌ Error: Admin config CSV file not found: '$filepath'"
        exit 1
    fi

    echo "$cfg"
}

# -------------------------------
# Function: Apply CSV Admin Config
# -------------------------------
apply_csv_admin_cfg() {
    local cfg="$1"

    if [[ -z "$cfg" ]]; then
        echo "No CSV file provided for Moodle admin configuration."
        return
    fi

    echo "✅ Using $cfg to configure Moodle admin"

while IFS=',' read -r NAME VALUE COMPONENT _ || [[ -n "$NAME" ]]; do
    [[ "$NAME" == NAME* ]] && continue

    # Strip surrounding quotes and whitespace
    NAME=$(echo "$NAME" | sed 's/^"//;s/"$//' | xargs)
    VALUE=$(echo "$VALUE" | sed 's/^"//;s/"$//' | xargs)
    COMPONENT=$(echo "$COMPONENT" | sed 's/^"//;s/"$//' | xargs)

    [[ -z "$NAME" || -z "$VALUE" ]] && continue

    echo "Setting $NAME to $VALUE${COMPONENT:+ (component: $COMPONENT)}..."

    CMD="php ./moodle/admin/cli/cfg.php --name=$NAME --set=$VALUE"
    [[ -n "$COMPONENT" ]] && CMD="$CMD --component=$COMPONENT"

    if ! ddev exec $CMD < /dev/null; then
        echo "⚠️ CLI failed to setup '$NAME' with value '$VALUE'${COMPONENT:+ and component '$COMPONENT'}."
    fi
done < "$cfg"


}
