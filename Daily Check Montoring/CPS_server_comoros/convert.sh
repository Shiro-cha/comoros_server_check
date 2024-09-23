#!/bin/sh

contents=$1;

if [ -z "$contents" ]; then
    echo "Error: contents is null" >&2
    exit 1
fi


