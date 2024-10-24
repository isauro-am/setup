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
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_ram_gb=$(awk "BEGIN {printf \"%.2f\", $total_ram_kb / 1024 / 1024}")

    used_ram_gb=$(free | grep Mem | awk '{print $3 / 1024 / 1024}')

    free_ram_percentage=$(awk "BEGIN {if ($total_ram_gb > 0) printf \"%.2f\", ($total_ram_gb - $used_ram_gb) / $total_ram_gb * 100; else print \"0\"}")

    echo "$free_ram_percentage"
}

function get_free_swap_percentage() {
    total_swap_gb=$(free | grep Swap | awk '{print $2 / 1024 / 1024}')
    used_swap_gb=$(free | grep Swap | awk '{print $3 / 1024 / 1024}')

    # Manage the case where there is no swap configured
    if (( $(echo "$total_swap_gb > 0" | bc -l) )); then
        free_swap_percentage=$(awk "BEGIN {printf \"%.2f\", ($total_swap_gb - $used_swap_gb) / $total_swap_gb * 100}")
    else
        free_swap_percentage="0"
    fi

    echo "$free_swap_percentage"
}

function restart_swap() {

    # Get the current swap size in gigabytes, rounded to the nearest integer
    current_swap_size=$(free | grep Swap | awk '{printf "%.0f", $2 / 1024 / 1024}')
    
    # Get the available disk space in the filesystem where the swap file will be created (for example, in /)
    available_disk_space=$(df --output=avail / | tail -n 1 | awk '{print $1 / 1024 / 1024}')  # Convert to GB
    
    echo "Available disk space: $available_disk_space GB"
    echo "Current swap size: $current_swap_size GB"

    # Verify if there is enough disk space to create the temporary swap file
    if (( $(echo "$available_disk_space > $current_swap_size + 1" | bc -l) )); then
        echo "There is enough disk space to create the temporary swap file."
        
        # Create a temporary swap file of size (current_swap_size + 1) GB
        fallocate -l $(($current_swap_size + 1))G /swapfile2
        chmod 600 /swapfile2
        mkswap /swapfile2
        swapon /swapfile2

        # Wait 10 seconds for the temporary swap to be in use
        sleep 10

        # Clean the real swap
        swapoff /swapfile
        swapon /swapfile

        # Delete the temporary swap file
        swapoff /swapfile2
        rm -f /swapfile2
    else
        echo "There is not enough disk space to create the temporary swap file."
        swapoff /swapfile
        swapon /swapfile
    fi
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
    echo "$(date): [ Reload Apache ] Free Swap Percentage: $free_swap_percentage%, Free RAM Percentage: $free_ram_percentage%" >> /var/log/reload_memory_usage.log
    systemctl restart apache2

    sleep 120
    new_free_ram_percentage=$(get_free_memory_percentage)

    # If after restarting Apache the RAM free percentage is greater than 10%, restart the swap
    if (( $(awk "BEGIN {print ($new_free_ram_percentage > 10)}") )); then
        echo "$(date): [ Restart Swap ] Free RAM Percentage: $new_free_ram_percentage%" >> /var/log/reload_memory_usage.log
        restart_swap
    fi
fi

# check if the free swap percentage is less than 50%
if (( $(awk "BEGIN {print ($free_swap_percentage < 50)}") )); then
    echo "$(date): [ Free Swap Percentage ] Free Swap Percentage: $free_swap_percentage%" >> /var/log/reload_memory_usage.log
    restart_swap
fi


echo "Free RAM Percentage: $free_ram_percentage%, Free Swap Percentage: $free_swap_percentage%"

# Check if MySQL is running, if not, restart it
if ! systemctl is-active --quiet mysql; then
    echo "$(date): [ Restart MySQL ] MySQL is not running" >> /var/log/reload_memory_usage.log
    systemctl start mysql
fi
