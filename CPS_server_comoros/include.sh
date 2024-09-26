#!/bin/sh
#
# Author: Shiro Yami
#
# Example: ./include.sh placeholder parent.html child.html output.html

function include() {
    local placeholder="$1"
    local parent="$2"
    local child="$3"
    local output="$4"


    local child_content=$(cat "$child")
    awk -v content="$child_content" -v placeholder="{$placeholder}" '
    {
        gsub(placeholder, content);
        print;
    }' "$parent" > "$output"

    echo "HTML file generated: $output"
}

PLACEHOLDER="$1"
PARENT="$2"
CHILD="$3"
OUTPUT="$4"

include "$PLACEHOLDER" "$PARENT" "$CHILD" "$OUTPUT"
