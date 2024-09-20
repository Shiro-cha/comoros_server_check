#!/bin/sh

####### Server list ########

default_user="root"
server_list="server_list.txt"
server_list_data=$(cat "$server_list")

####### GET host name ########
function get_hostname() {
    local server="$1"
    local hostname="$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$default_user@$server" 'uname -n')"
    echo "$hostname"
}

####### GET memory ########
function get_memory() {
    local server="$1"
    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi
    local memory="$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$default_user@$server" "free -m | awk '/Mem/ {printf \"%.2f%%\\n\", \$4/\$2 * 100}'")"

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
    local task="$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$default_user@$server" 'ps aux | tail -n +2 | wc -l')"

    echo "$task"
}

####### GET CPU ########
function get_cpu() {
    local server="$1"
    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi

    local cpu="$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$default_user@$server" "top -bn1 | grep 'Cpu(s)' | awk '{printf \"Total: %.2f%% (User: %.2f%%, Sys: %.2f%%, Idle: %.2f%%)\\n\", 100-\$8, \$2, \$4, \$8}'")"
    echo "$cpu"
}

####### GET disk ########
function get_disk() {
    local server="$1"
    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi

    local disk_usage="$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$default_user@$server" "df -h | awk 'NR>1 {print \$5, \$6}'")"

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

function parse_crm_status() {
    local crm_output="$1"
    local online_nodes=$(get_online_nodes "$crm_output")
    local offline_nodes=$(get_offline_nodes "$crm_output")
    local resource_groups=$(get_resource_group "$crm_output")
    
    log_list "$online_nodes"
    log_list "$offline_nodes"
    log_list "$resource_groups"
}

function get_crm_status() {
    local server="$1"
    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi

    local crm_status="$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$default_user@$server" "crm status")"
    parse_crm_status "$crm_status"
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

        echo "$ip $hostname $memory $task $cpu $disk $crm_status"
    done
}

check_server
