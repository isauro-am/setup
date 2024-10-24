#!/bin/bash

# Set script to run every 5 minutes
#  */5 * * * * /opt/reload_memory_usage.sh

function get_free_memory_percentage() {

    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}' | bc)
    total_ram_gb=$(awk "BEGIN {printf \"%.2f\", $total_ram_kb / 1024 / 1024}")

    used_ram_gb=$(free | grep Mem | awk '{print $3 / 1024 / 1024 " GB"}')

    free_ram_percentage=$(awk "BEGIN {printf \"%.2f\", ($total_ram_gb - $used_ram_gb) / $total_ram_gb * 100}")

    return $free_ram_percentage
}


function get_free_swap_percentage() {

    total_swap_gb=$(free | grep Swap | awk '{print $2 / 1024 / 1024}')
    used_swap_gb=$(free | grep Swap | awk '{print $3 / 1024 / 1024}')
    free_swap_gb=$(awk '/SwapFree/ {print $2 / 1024 / 1024 " GB"}' /proc/meminfo)

    free_swap_percentage=$(awk "BEGIN {printf \"%.2f\", ($total_swap_gb - $used_swap_gb) / $total_swap_gb * 100}")
    
    return $free_swap_percentage
}

free_ram_percentage=$(get_free_memory_percentage)
free_swap_percentage=$(get_free_swap_percentage)

# If the free swap percentage is less than 50% and the free RAM percentage is less than 10%, then restart the swap
if [ $free_swap_percentage -lt 50 ] && [ $free_ram_percentage -lt 10 ]; then
    echo "$(date): [ Reload Apache ] Free Swap Percentage: $free_swap_percentage%, Free RAM Percentage: $free_ram_percentage%" >> /var/log/reload_memory_usage.log
    systemctl restart apache2

    sleep 120
    new_free_ram_percentage=$(get_free_memory_percentage)

    # If the new free RAM percentage is greater than 10%, then restart the swap
    if [ $new_free_ram_percentage -gt 10 ]; then
        echo "$(date): [ Restart Swap ] Free RAM Percentage: $new_free_ram_percentage%" >> /var/log/reload_memory_usage.log
        swapoff -a
        swapon -a
    fi
fi

if ! systemctl is-active --quiet mysql; then
    echo "$(date): [ Restart MySQL ] MySQL is not running" >> /var/log/reload_memory_usage.log
    systemctl start mysql
fi