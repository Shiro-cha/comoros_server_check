#!/bin/sh

CSV_FILE=$1
HTML_TEMPLATE=$2

html_name="CDR_cdr_comoros.html"
delimiter="|"
template="<tr><td>{col1}</td><td>{col2}</td></tr>"

if [ ! -f "$CSV_FILE" ]; then
    echo "File $CSV_FILE does not exist"
    exit 1
fi

parse_csv() {
    local file=$1
    local delimiter=$2
    local template=$3

    awk -F"$delimiter" -v template="$template" '
    NR > 1 {
        row = template;
        gsub("{col1}", $1, row);
        gsub("{col2}", $2, row);
        print row;
    }' "$file"
}

render_table() {
    local content=$1
    local output_file=$2
    local template_file=$3

    local escaped_content=$(printf '%s\n' "$content" | sed 's/[\/&]/\\&/g')
    local escaped_template=$(printf '%s\n' "$template_file" | sed 's/[\/&]/\\&/g')

    awk -v cdr_table="$content" '
    BEGIN {
        while ((getline < ARGV[1]) > 0) {
            gsub(/{{ cdr_table }}/, cdr_table);
            print
        }
    }' "$template_file" > "$output_file"
}

html_out=$(parse_csv "$CSV_FILE" "$delimiter" "$template")
render_table "$html_out" "$html_name" "$HTML_TEMPLATE"

echo "HTML file generated: $html_name"
