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

    # Get free memory percentage rounded to 2 decimal places
    free_ram_percentage=$(free -m | awk '/Mem:/ {print $7/$2 * 100}' | bc | awk '{printf "%.2f", $1}')
    echo "$free_ram_percentage"

}

function get_free_swap_percentage() {

    # Get total and used swap in MB
    total_swap=$(free -m | awk '/Swap:/ {print $2}')
    used_swap=$(free -m | awk '/Swap:/ {print $3}')

    # Convert to GB
    total_swap_gb=$(echo "scale=2; $total_swap / 1024" | bc)
    used_swap_gb=$(echo "scale=2; $used_swap / 1024" | bc)

    # Calculate free swap percentage
    if (( $(echo "$total_swap_gb > 0" | bc -l) )); then
        free_swap_percentage=$(echo "scale=2; ($total_swap_gb - $used_swap_gb) / $total_swap_gb * 100" | bc)
    else
        free_swap_percentage=0
    fi

    # Show free swap percentage
    echo "$free_swap_percentage"

}


# Capture the free memory and swap percentages
free_ram_percentage=$(get_free_memory_percentage)
free_swap_percentage=$(get_free_swap_percentage)

# Verify if the variables are numeric before continuing
if ! [[ "$free_ram_percentage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: free_ram_percentage is not a valid number.  $free_ram_percentage"
    exit 1
fi

if ! [[ "$free_swap_percentage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: free_swap_percentage is not a valid number.  $free_swap_percentage"
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



mysql_installed=false

# Verificar si hay algún motor de base de datos instalado
if dpkg -l | grep -E 'mysql-server|mariadb-server|postgresql' >/dev/null 2>&1; then
    mysql_installed=true
fi

if $mysql_installed == true; then

    for i in {1..5}; do
        if systemctl is-active --quiet mysql; then

            if [ $i -gt 1 ]; then
                echo "$(date): [ MySQL ] MySQL is running" >> /var/log/reload_memory_usage.log
            fi
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