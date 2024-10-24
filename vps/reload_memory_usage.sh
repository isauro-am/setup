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

#!/bin/bash

# Set script to run every 5 minutes
# */5 * * * * /opt/reload_memory_usage.sh

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

    # Manejar el caso en que no haya swap configurado
    if (( $(echo "$total_swap_gb > 0" | bc -l) )); then
        free_swap_percentage=$(awk "BEGIN {printf \"%.2f\", ($total_swap_gb - $used_swap_gb) / $total_swap_gb * 100}")
    else
        free_swap_percentage="0"
    fi

    echo "$free_swap_percentage"
}

# Capturar el porcentaje de memoria libre y swap libre
free_ram_percentage=$(get_free_memory_percentage)
free_swap_percentage=$(get_free_swap_percentage)

# Verificar si las variables son numéricas antes de continuar
if ! [[ "$free_ram_percentage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: free_ram_percentage no es un número válido."
    exit 1
fi

if ! [[ "$free_swap_percentage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: free_swap_percentage no es un número válido."
    exit 1
fi

# Si el porcentaje de swap libre es menor al 50% y el de RAM libre es menor al 10%, reinicia Apache y limpia el swap
if (( $(awk "BEGIN {print ($free_swap_percentage < 50)}") )) && (( $(awk "BEGIN {print ($free_ram_percentage < 10)}") )); then
    echo "$(date): [ Reload Apache ] Free Swap Percentage: $free_swap_percentage%, Free RAM Percentage: $free_ram_percentage%" >> /var/log/reload_memory_usage.log
    systemctl restart apache2

    sleep 120
    new_free_ram_percentage=$(get_free_memory_percentage)

    # Si después de reiniciar Apache la RAM libre es mayor al 10%, reiniciar el swap
    if (( $(awk "BEGIN {print ($new_free_ram_percentage > 10)}") )); then
        echo "$(date): [ Restart Swap ] Free RAM Percentage: $new_free_ram_percentage%" >> /var/log/reload_memory_usage.log
        swapoff -a
        swapon -a
    fi
fi

echo "Free RAM Percentage: $free_ram_percentage%, Free Swap Percentage: $free_swap_percentage%"

# Verificar si MySQL está activo, si no, reiniciar
if ! systemctl is-active --quiet mysql; then
    echo "$(date): [ Restart MySQL ] MySQL is not running" >> /var/log/reload_memory_usage.log
    systemctl start mysql
fi
