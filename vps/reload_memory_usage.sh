#!/bin/bash

# Set script to run every 5 minutes
# */5 * * * * /opt/reload_memory_usage.sh

# Requires:
# - bc
#  install bc

# validate if bc is installed
if ! command -v bc &> /dev/null; then
    echo "bc could not be found"
    apt install -y bc
fi


function get_free_memory_percentage() {

    total_ram_gb=$(free -h --si | grep Mem | awk '{print $2}' | sed 's/G//')
    available_ram_gb=$(free -h --si | grep Mem | awk '{print $7}' | sed 's/G//')

    free_ram_percentage=$(awk "BEGIN {if ($total_ram_gb > 0) printf \"%.2f\", $available_ram_gb / $total_ram_gb * 100; else print \"0\"}")

    echo "$free_ram_percentage"

}

function get_free_swap_percentage() {

    total_swap_gb=$(free -h --si | grep Swap | awk '{print $2}' | sed 's/G//')
    used_swap_gb=$(free -h --si | grep Swap | awk '{print $3}' | sed 's/G//')

    free_swap_percentage=$(awk "BEGIN {if ($total_swap_gb > 0) printf \"%.2f\", ($total_swap_gb - $used_swap_gb) / $total_swap_gb * 100; else print \"0\"}")

    echo "$free_swap_percentage"

}


# Capture the free memory and swap percentages
free_ram_percentage=$(get_free_memory_percentage)
free_swap_percentage=$(get_free_swap_percentage)

# Verify if the variables are numeric before continuing
if ! [[ "$free_ram_percentage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: free_ram_percentage is not a valid number."
    exit 1
fi

if ! [[ "$free_swap_percentage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: free_swap_percentage is not a valid number."
    exit 1
fi

# If the free swap percentage is less than 50% and the free RAM percentage is less than 10%, restart Apache and clear the swap
if (( $(awk "BEGIN {print ($free_swap_percentage < 50)}") )) && (( $(awk "BEGIN {print ($free_ram_percentage < 10)}") )); then

    echo "$(date): [ Reloading Apache ] Free Swap Percentage: $free_swap_percentage%, Free RAM Percentage: $free_ram_percentage%" >> /var/log/reload_memory_usage.log
    systemctl restart apache2
    sleep 60

fi

# Only with the free RAM percentage less than 10%, restart the swap
if (( $(awk "BEGIN {print ($free_ram_percentage < 10)}") )); then
    echo "$(date): [ Restarting Apache ] Free RAM Percentage: $free_ram_percentage%" >> /var/log/reload_memory_usage.log
    systemctl restart apache2
    sleep 60
fi


mysql_installed=$(dpkg -l | grep mysql-server)

# If MySQL is installed, try to start it 5 times if it is not running
if [[ -n "$mysql_installed" ]]; then

    for i in {1..5}; do
        if systemctl is-active --quiet mysql; then
            echo "$(date): [ MySQL ] MySQL is running" >> /var/log/reload_memory_usage.log
            break
        fi

        echo "$(date): [ Start MySQL ] [try $i] MySQL is not running, trying to start it" >> /var/log/reload_memory_usage.log

        systemctl start mysql
        sleep 10
    done

    echo "$(date): [ MySQL ] $(systemctl is-active --quiet mysql && echo 'running' || echo 'not running')"
fi

echo "$(date): [ $free_ram_percentage%, $free_swap_percentage% ]"
# echo mysql status