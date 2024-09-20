#!/bin/sh

CSV_FILE=$1
HTML_TEMPLATE=$2
HTML_NAME="CPS_server_comoros.html"
DELIMITER="|"
TEMPLATE="<tr><td>{col1}</td><td>{col2}</td><td>{col3}</td><td>{col4}</td><td>{col5}</td><td>{col6}</td><td>{col7}</td><td>{col8}</td><td>{col9}</td><td>{col10}</td></tr>"

if [ ! -f "$CSV_FILE" ]; then
    echo "File $CSV_FILE does not exist"
    exit 1
fi

parse_usage() {
    local data="$1"
    
    
    IFS=',' read -r -a entries <<< "$data"

    for entry in "${entries[@]}"; do
        percent=$(echo "$entry" | awk -F',' '{print $1}' | sed 's/[]]/\]/g')
        path=$(echo "$entry" | awk -F',' '{print $2}' | sed 's/[]]/\]/g')
        path=$(echo "$path" | xargs)

        if [ -z "$percent" ]; then
            percent="No usage data"
        fi

        echo "$percent <br/>"
    done
}

parse_csv() {
    local file=$1
    local delimiter=$2
    local template=$3

    while IFS="$delimiter" read -r col1 col2 col3 col4 col5 col6 col7 col8 col9 col10; do
        if [ "$col1" = "hostname" ]; then
            continue
        fi

        parsed_col5=$(parse_usage "$col5")

        row="$template"
        row=${row//\{col1\}/$col1}
        row=${row//\{col2\}/$col2}
        row=${row//\{col3\}/$col3}
        row=${row//\{col4\}/$col4}
        row=${row//\{col5\}/$parsed_col5}
        row=${row//\{col6\}/$col6}
        row=${row//\{col7\}/$col7}
        row=${row//\{col8\}/$col8}
        row=${row//\{col9\}/$col9}
        row=${row//\{col10\}/$col10}

        echo "$row"
    done < "$file"
}

render_table() {
    local content=$1
    local output_file=$2
    local template_file=$3

    # Escape special characters
    local escaped_content=$(printf '%s\n' "$content" | sed 's/[\/&]/\\&/g')
    local escaped_template=$(printf '%s\n' "$template_file" | sed 's/[\/&]/\\&/g')

    awk -v cdr_table="$escaped_content" '
    BEGIN {
        while ((getline < ARGV[1]) > 0) {
            gsub(/{{ cdr_table }}/, cdr_table);
            print
        }
    }' "$template_file" > "$output_file"
}

html_out=$(parse_csv "$CSV_FILE" "$DELIMITER" "$TEMPLATE")
render_table "$html_out" "$HTML_NAME" "$HTML_TEMPLATE"

echo "HTML file generated: $HTML_NAME"
