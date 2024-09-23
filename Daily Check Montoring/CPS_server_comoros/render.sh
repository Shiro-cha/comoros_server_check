#!/bin/bash

#Author: Shiro Yami

# Usage: ./render.sh <template> <variables> <values> <output_file>

TEMPLATE="$1"
VARIABLES="$2"
VALUES="$3"
OUTPUT_FILE="$4"



if [ -z "$TEMPLATE" ]; then
    echo "Error: template is null" >&2
    exit 1
fi


function get_variable_value() {
    local variable="$1"
    if [ -z "$variable" ]; then
        echo "Error: variable is null" >&2
        return 1
    fi

    for var in "${VARIABLES[@]}"; do
        if [ "$var" == "$variable" ]; then
            echo "${VALUES[$var]}"
            return
        fi
    done

    echo "Error: variable $variable not found" >&2
}
function replace_variable() {
    local content="$1"
    local value="$2"
    if [ -z "$content" ]; then
        echo "Error: content is null" >&2
        return 1
    fi

    if [ -z "$value" ]; then
        echo "Error: value is null" >&2
        return 1
    fi
    echo "$content" | sed "s/{{ $value }}/{{ $value }}/g"
}

function generate_output() {
    local content="$1"
    local output_file="$2"
    if [ -z "$content" ]; then
        echo "Error: content is null" >&2
        return 1
    fi

    if [ -z "$output_file" ]; then
        echo "Error: output_file is null" >&2
        return 1
    fi
    echo "$content" > "$output_file"
    
}

function render_template() {
    local template="$1"
    if [ -z "$template" ]; then
        echo "Error: template is null" >&2
        return 1
    fi
    for var in "${VARIABLES[@]}"; do
        current_value=$(get_variable_value "$var")
        template=$(replace_variable "$var" "$current_value")
    done
    generate_output "$template" "$OUTPUT_FILE"
    echo "$template"  
}






