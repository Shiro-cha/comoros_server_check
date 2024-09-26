#!/bin/sh
#
# Author: Shiro Yami
#
# Usage: ./render.sh <template> <variables> <values> <output_file>
#
# Example: ./render.sh template.html "var1,var2" "value1,value2" output.html

TEMPLATE="$1"
VARIABLES="$2"
VALUES="$3"     
OUTPUT_FILE="$4"

if [ -z "$TEMPLATE" ]; then
    echo "Error: template is null" >&2
    exit 1
fi


function split() {
    local input="$1"
    local delimiter="$2"
    local IFS="$delimiter"
    read -r -a array <<< "$input"
    echo "${array[@]}"
}


VARIABLES_ARRAY=($(split "$VARIABLES" ","))
VALUES_ARRAY=($(split "$VALUES" ","))

function get_variable_value() {
    local variable="$1"
    for i in "${!VARIABLES_ARRAY[@]}"; do
        if [ "${VARIABLES_ARRAY[$i]}" == "$variable" ]; then
            echo "${VALUES_ARRAY[$i]}"
            return 0
        fi
    done
    echo "Error: variable $variable not found" >&2
    return 1
}


function replace_variable() {
    local content="$1"
    local variable="$2"
    local value="$3"
    
    echo "$content" | sed "s/{$variable}/$value/g"
}

function generate_output() {
    local content="$1"
    echo "$content" > "$OUTPUT_FILE"
}

function render_template() {
    local template_content
    local current_value

    if [[ ! -r "$TEMPLATE" ]]; then
        echo "Error: Template file '$TEMPLATE' does not exist or is not readable."
        return 1
    fi

    template_content=$(<"$TEMPLATE")

    for var in "${VARIABLES_ARRAY[@]}"; do
        
        current_value=$(get_variable_value "$var")

        if [[ -z "$current_value" ]]; then
            echo "Warning: Value for variable '$var' is empty."
            current_value="<<UNDEFINED>>"
        fi
        template_content=$(replace_variable "$template_content" "$var" "$current_value")
    done

    echo "$template_content"

    generate_output "$template_content"

    echo "$template_content"
}


render_template
