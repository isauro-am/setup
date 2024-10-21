#!/bin/bash

# Nombre del Bridge
BRIDGE_NAME="vmbr1"
DHCP_RANGE_START="192.168.10.110"
DHCP_RANGE_END="192.168.10.200"
DHCP_GATEWAY="192.168.10.100"
DHCP_NETMASK="255.255.255.0"

# Crear el bridge en Proxmox (esto se debe hacer manualmente desde la interfaz web o por configuración manual)
echo "Asegúrate de que el Bridge $BRIDGE_NAME ha sido creado en la interfaz web de Proxmox."

# Instalar el servidor DHCP
echo "Instalando el servidor DHCP..."
apt update
apt install -y isc-dhcp-server

# Configurar el archivo /etc/default/isc-dhcp-server
echo "Configurando /etc/default/isc-dhcp-server..."
cat <<EOT > /etc/default/isc-dhcp-server
# Asignar el nombre del bridge en la variable INTERFACESv4
INTERFACESv4="$BRIDGE_NAME"
EOT

# Configurar el archivo dhcpd.conf
echo "Configurando /etc/dhcp/dhcpd.conf..."
cat <<EOT > /etc/dhcp/dhcpd.conf
# Configuration file for ISC dhcpd.
subnet 192.168.10.0 netmask 255.255.255.0 {
  range $DHCP_RANGE_START $DHCP_RANGE_END;
  authoritative;
  default-lease-time 21600000;
  max-lease-time 432000000;
  option subnet-mask $DHCP_NETMASK;
  option routers $DHCP_GATEWAY;
  option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOT

# Configurar la interfaz de red en Proxmox (bridge)
echo "Configurando /etc/network/interfaces para el bridge $BRIDGE_NAME..."
cat <<EOT >> /etc/network/interfaces
# Habilitar el reenvío de paquetes y NAT para el bridge
auto $BRIDGE_NAME
iface $BRIDGE_NAME inet static
    address $DHCP_GATEWAY
    netmask $DHCP_NETMASK
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -o $BRIDGE_NAME -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s 192.168.10.0/24 -o $BRIDGE_NAME -j MASQUERADE
EOT

# Cambiar la política de reenvío en UFW
echo "Configurando UFW para permitir reenvío de paquetes..."
sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw

# Reiniciar UFW para aplicar los cambios
echo "Reiniciando UFW..."
ufw reload

# Reiniciar el servidor DHCP
echo "Reiniciando el servidor DHCP..."
sudo systemctl restart isc-dhcp-server

# Habilitar el servidor DHCP para que inicie con el sistema
sudo systemctl enable isc-dhcp-server

# Reiniciar Proxmox
echo "Reiniciando Proxmox..."
reboot
