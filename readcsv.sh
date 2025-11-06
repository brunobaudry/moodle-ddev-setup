csv_admin_cfg="./admin_cfg.csv"
# If CSV_FILE is not empty, check if file exists
if [ -f "$csv_admin_cfg" ]; then
    # Read the CSV file line by line
    while read -r line || [ -n "$line" ]; do
        # Skip header
        [[ "$line" == NAME,* ]] && continue

        # Extract NAME and VALUE using awk (handles quoted values)
        NAME=$(echo "$line" | awk -F',' '{print $1}' | sed 's/^"//;s/"$//')
        VALUE=$(echo "$line" | awk -F',' '{for(i=2;i<=NF;i++) printf "%s%s",$i,(i<NF?",":"");}' | sed 's/^"//;s/"$//')

        # Trim spaces
        NAME=$(echo "$NAME" | xargs)
        VALUE=$(echo "$VALUE" | xargs)

        # Skip empty lines
        [[ -z "$NAME" || -z "$VALUE" ]] && continue

        echo "Setting $NAME to $VALUE..."
        if ! ddev exec php ./moodle/admin/cli/cfg.php --name="$NAME" --set="$VALUE"; then
            echo "⚠️ CLI failed to setup '$NAME' with value '$VALUE'."
        fi
    done < "$csv_admin_cfg"
else
    echo "❌ Error: Admin config csv File not found: '$csv_admin_cfg'"
fi