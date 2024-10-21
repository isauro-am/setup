#!/bin/bash

# Add Cloudflare’s package signing key:
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null


# Add Cloudflare’s apt repo to your apt repositories:
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflared.list

apt-get update && apt-get install cloudflared

# # Descargar e instalar Cloudflare Tunnel (cloudflared)
# echo "Descargando e instalando Cloudflare Tunnel..."
# curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
# dpkg -i cloudflared.deb
# rm cloudflared.deb

# Verificar la instalación
cloudflared version

# Autenticar con Cloudflare
echo "Autenticando con Cloudflare..."
cloudflared tunnel login

# Configurar el túnel
echo "Configurando el túnel..."
read -p "Ingrese el hostname (ejemplo: your-domain.com, example.your-domain.com, 127.0.0.1, localhost): " HOSTNAME
read -p "Ingrese el servicio local (ejemplo: http://localhost:8000): " SERVICE


# Crear un nuevo túnel
echo "Creando un nuevo túnel..."
read -p "Ingrese un nombre para el túnel: " TUNNEL_NAME
cloudflared tunnel create $TUNNEL_NAME


# Obtener el id del tunnel
TUNNEL_ID=$(cloudflared tunnel list | grep $TUNNEL_NAME | awk '{print $1}')

cat << EOF > ~/.cloudflared/config.yml
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/${TUNNEL_ID}.json

warp-routing:
  enabled: true  # O puedes intentar deshabilitarlo si no necesitas WARP routing

ingress:
  - hostname: $HOSTNAME
    service: $SERVICE
  - service: http_status:404
EOF

# Enrutar el tráfico
echo "Enrutando el tráfico..."
cloudflared tunnel route dns $TUNNEL_NAME $HOSTNAME

# Iniciar el túnel
echo "Iniciando el túnel..."
cloudflared tunnel run $TUNNEL_NAME


# Preguntar si se desea configurar el túnel para que se inicie automáticamente
read -p "¿Desea configurar el túnel para que se inicie automáticamente? (s/n): " AUTO_START
if [[ $AUTO_START == "s" ]]; then
    # Configurar el túnel para que se inicie automáticamente
    echo "Configurando el inicio automático del túnel..."
    cloudflared service install
fi

echo "Configuración de Cloudflare Tunnel completada."
echo "El túnel se iniciará automáticamente en el próximo reinicio."
echo "Para iniciar el túnel manualmente, ejecute: cloudflared tunnel run $TUNNEL_NAME"
echo "O puede iniciarlo como: cloudflared tunnel run $TUNNEL_ID"
echo ""
echo "Para ver el estado del túnel, ejecute: cloudflared tunnel list"
echo "Para detener el túnel, ejecute: cloudflared tunnel stop $TUNNEL_ID"
echo "Para eliminar el túnel, ejecute: cloudflared tunnel delete $TUNNEL_ID"
echo ""
echo "¡Gracias por usar Cloudflare Tunnel!"
