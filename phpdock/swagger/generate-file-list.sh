#!/bin/sh
set -e

SPECS_DIR="/api-specs"
OUTPUT_FILE="/usr/share/nginx/html/file-list.json"

# Function to generate the file list
generate_file_list() {
    echo "Generating API specs file list..."

    # Create an empty array
    echo "[]" > ${OUTPUT_FILE}

    # Check if the directory exists and has files
    if [ -d "${SPECS_DIR}" ]; then
        # Find all YAML and JSON files
        FILES=$(find ${SPECS_DIR} -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) -printf "%f\n" | sort)

        if [ -n "$FILES" ]; then
            # Create a JSON array of filenames
            echo "[" > ${OUTPUT_FILE}

            first=true
            for file in $FILES; do
                if $first; then
                    first=false
                else
                    echo "," >> ${OUTPUT_FILE}
                fi
                echo "  \"$file\"" >> ${OUTPUT_FILE}
            done

            echo "]" >> ${OUTPUT_FILE}
        fi
    fi

    echo "File list generated: $(cat ${OUTPUT_FILE})"
}

# Generate the file list initially
generate_file_list

# Monitor the directory for changes and regenerate the file list
while true; do
    sleep 10
    generate_file_list
done