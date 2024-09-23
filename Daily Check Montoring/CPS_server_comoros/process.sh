#!/bin/sh

####### Server list ########

default_user="root"
server_list="server_list.txt"
server_list_data=$(cat "$server_list")

####### run ssh ########
function run_ssh() {
    local server="$1"
    local command="$2"
    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi

    local out=$(ssh "$default_user@$server" "$command" 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error executing command on $server: $out" >&2
        return 1
    fi

    echo "$out"
}

####### GET host name ########
function get_hostname() {
    local server="$1"
    local hostname="$(run_ssh "$server" 'uname -n')"
    echo "$hostname"
}

####### GET memory ########
function get_memory() {
    local server="$1"
    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi
    local memory="$(run_ssh "$server" "free -m | awk '/Mem/ {printf \"%.2f%%\\n\", \$4/\$2 * 100}'")"

    if [ -z "$memory" ]; then
        echo "Error: Unable to get memory information from server $server" >&2
        return 1
    fi

    echo "$memory"
}

####### GET task ########
function get_task() {
    local server="$1"
    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi

    local task="$(run_ssh "$server" "ps aux | tail -n +2 | wc -l")"
    echo "$task"
}

####### GET CPU ########
function get_cpu() {
    local server="$1"
    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi

    local cpu="$(run_ssh "$server" "top -bn1 | grep 'Cpu(s)' | awk '{printf \"Total: %.2f%% (User: %.2f%%, Sys: %.2f%%, Idle: %.2f%%)\\n\", 100-\$8, \$2, \$4, \$8}'")"
    echo "$cpu"
}

####### GET disk ########
function get_disk() {
    local server="$1"
    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi

    local disk_usage="$(run_ssh "$server" "df -h | awk 'NR>1 {print \$5, \$6}'")"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to get disk usage from server $server" >&2
        return 2
    fi
    echo "$disk_usage"
}

####### GET CRM status ########
function get_resource_group() {
    local input="$1"
    resource_groups=()
    while IFS= read -r line; do
        if [[ $line =~ ^\ *Resource\ Group:\ (.+) ]]; then
            resource_groups+=("${BASH_REMATCH[1]}")
        fi
    done <<< "$input"
    
    echo "${resource_groups[@]}"
}

function get_online_nodes() {
    local input="$1"
    online_nodes=()
    while IFS= read -r line; do
        if [[ $line =~ ^Online:\ (.+) ]]; then
            online_nodes+=("${BASH_REMATCH[1]}")
        fi
    done <<< "$input"
    
    echo "${online_nodes[@]}"
}

function get_offline_nodes() {
    local input="$1"
    offline_nodes=()
    while IFS= read -r line; do
        if [[ $line =~ ^Offline:\ (.+) ]]; then
            offline_nodes+=("${BASH_REMATCH[1]}")
        fi
    done <<< "$input"
    
    echo "${offline_nodes[@]}"
}

function log_list() {
    local input="$1"
    while IFS= read -r line; do
        echo "$line"
    done <<< "$input"
}

function get_resource_load() {
    local input="$1"
    local current_group=""
    declare -A group_resources
    while IFS= read -r line; do
        if [[ $line =~ ^\ *Resource\ Group:\ (.+) ]]; then
            current_group="${BASH_REMATCH[1]}"
            group_resources["$current_group"]=0
        elif [[ $line =~ ^\ *[^\ ] ]]; then
            if [ -n "$current_group" ]; then
                group_resources["$current_group"]=$((group_resources["$current_group"] + 1))
            fi
        fi
    done <<< "$input"
    
    for group in "${!group_resources[@]}"; do
        echo "Resource Group: $group, Resource Count: ${group_resources[$group]}"
    done
}

function parse_crm_status() {
    local crm_output="$1"
    local online_nodes=$(get_online_nodes "$crm_output")
    local offline_nodes=$(get_offline_nodes "$crm_output")
    local resource_groups=$(get_resource_group "$crm_output")
    
    local online_nodes=$(log_list "$online_nodes")
    local offline_nodes=$(log_list "$offline_nodes")
    local resource_groups=$(log_list "$resource_groups")

    echo "Online nodes: $online_nodes"
    echo "Offline nodes: $offline_nodes"
    echo "Resource groups: $resource_groups"
    get_resource_load "$crm_output"
}

function get_crm_status() {
    local server="$1"
    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi

    local crm_status="$(run_ssh "$server" "crm status")"
    parse_crm_status "$crm_status"
}


####### Get uptime ########
function get_uptime() {
    local server="$1"
    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi

    local uptime="$(run_ssh "$server" "uptime | awk '{print \$3, \$4}'")"   
    echo "$uptime"
}

####### Check server ########
function check_server() {
    for server in ${server_list_data[@]}; do
        ip=$(echo "$server" | awk '{print $1}')
        hostname=$(get_hostname "$ip")
        memory=$(get_memory "$ip")
        task=$(get_task "$ip")
        cpu=$(get_cpu "$ip")
        disk=$(get_disk "$ip")
        crm_status=$(get_crm_status "$ip")
        uptime=$(get_uptime "$ip")

        echo "=======hostname===="
        echo "$hostname"
        echo "=======memory===="
        echo "$memory"
        echo "=======task===="
        echo "$task"
        echo "=======cpu===="
        echo "$cpu"
        echo "=======disk===="
        echo "$disk"
        echo "=======crm_status===="
        echo "$crm_status"
        echo "=======uptime===="
        echo "$uptime"

    done
}

check_server
