#!/bin/bash

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

    local out=$(ssh "$default_user@$server" "$command")
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

    local cpu="$(run_ssh "$server" "top -bn1 | grep 'Cpu(s)' | awk '{printf \"%.2f%%\\n\", 100-\$8, \$2, \$4, \$8}'")"
    echo "$cpu"
}

####### GET disk ########

get_usage() {
    local input_string="$1"
    echo "$input_string" | awk '{print $1}' | sed 's/%//'
}

get_path() {
    local input_string="$1"
    echo "$input_string" | awk '{print $2}'
}
function get_disk() {
    local server="$1"

    if [ -z "$server" ]; then
        echo "Error: server is null" >&2
        return 1
    fi

    local disk_usage
    disk_usage="$(run_ssh "$server" "df -h | awk 'NR>1 {print \$5, \$6}'")"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to get disk usage from server $server" >&2
        return 2
    fi

    local usage=($(get_usage "$disk_usage"))
    local path=($(get_path "$disk_usage"))

     if [ ${#usage[@]} -eq 0 ] || [ ${#path[@]} -eq 0 ]; then
        echo "Error: Failed to parse disk usage or paths." >&2
        return 3
    fi


    local disk_output=""
    echo '        <ul class="disk-usage">';
    for ((i = 0; i < ${#path[@]} ; i++)); do

        local current_path=$(echo "${path[$i]}")
        local current_usage=${usage[$i]}
        echo '            <li>';
echo "                <span>$current_path</span>";
echo '                <div class="tooltip">';
echo '                    <div class="progress-container">';
echo "                        <div class="progress-bar" style=\"width: $current_usage%;\">$current_usage%</div>";
echo '                    </div>';
echo "                    <span class="tooltiptext">Used: $current_usage%</span>";
echo '                </div>';
echo '            </li>';
    done
    
    echo '        </ul>';
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

     # CRM Information section
        echo '<!-- CRM Information for Server -->'
        echo '<tr class="crm-info">'
        echo '   <td colspan="7">'
        echo '       <strong>CRM Status:</strong><br>'
        echo "       Online nodes: $online_nodes<br>"
        echo "       Offline nodes: $offline_nodes<br>"
        echo "       Resource Groups: $resource_groups<br>"
        echo '       Resource Load Counts: <br>'
        get_resource_load "$crm_output"
        echo '   </td>'
        echo '</tr>'
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
    echo "$(cat "templates/header.html")"

    for server in "${server_list_data[@]}"; do
        ip=$(echo "$server" | awk '{print $1}')
        hostname=$(get_hostname "$ip")
        memory=$(get_memory "$ip")
        task=$(get_task "$ip")
        cpu=$(get_cpu "$ip")
        disk=$(get_disk "$ip")
        crm_status=$(get_crm_status "$ip")
        uptime=$(get_uptime "$ip" | awk '{print $1}')

        echo '<tr>'
        echo "   <td>$hostname ($ip)</td>"
        echo "   <td>$memory</td>"
        echo "   <td>$task tasks</td>"
        echo "   <td>$cpu</td>"
        echo "   <td>$disk</td>"
        echo '   <td class="status-ok">Online</td>'
        echo "   <td>$uptime days</td>"
        echo '</tr>'

        # CRM Information section
        echo '<!-- CRM Information for Server -->'
        echo "$crm_status"
    done

    echo "$(cat "templates/footer.html")"
}

check_server > "output.html"

