#!/bin/bash

# 1. Configurar servidores DNS
echo "Configurando servidores DNS..."
cat <<EOL > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOL

# 2. Actualización de repositorios y paquetes
echo "Actualizando repositorios y paquetes..."
apt update && apt upgrade -y

apt_list=(
    "htop "
    "ufw"
    "nmon"
    "mtr"
    "bmon"
    "clamav"
    "rkhunter"
    "nmap"
    "rsync"
    "whois"
    "mc"
    "ncdu"
    "sysstat"
    "vim"
    "wget"
    "nload"
    "curl"
    "unzip"
    "vim-nox"
    "byobu"
    "btop"
    "wget"
    "git"
    "python3-pip"
    "speedtest-cli"
    "curl"
    "wget"
    "nmap"
    "whois"
    "dnsutils"
    "nano"
)

for package in "${apt_list[@]}"; do
    apt install -y "$package"
done


# 3. Configurar UFW
echo "Modificando configuración de UFW..."
sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw

# 4. Reglas del firewall UFW
echo "Aplicando reglas de firewall UFW..."
ufw reset
ufw allow from 198.27.126.229 comment 'VPN D'
ufw allow from 107.173.154.26 comment 'dan-vpn'
ufw allow from 141.95.75.216 comment 'nieto-vpn'
ufw allow from 217.182.140.17 comment 'isauro-vpn'
ufw allow from 141.95.47.34 to any port 54322 comment 'b.omv'
ufw allow proto tcp from 158.69.72.147 to any port 9000:9999 comment 'Argos'
ufw enable

# 5. Reglas adicionales para Proxmox o SSH sin VPN
echo "Configurando acceso SSH sin VPN..."
ufw allow proto tcp from any to any port 54322,8006 comment 'Admin ports'

# 6. Modificar archivo de hosts
echo "Modificando archivo de hosts..."
cat <<EOL >> /etc/hosts
127.0.0.1 localhost
XXX.XXX.XXX.XXX server.microbit.com server
EOL

# 7. Verificar configuración de locales
echo "Generando locales en_US.UTF-8..."
locale-gen en_US.UTF-8
dpkg-reconfigure locales


# cambiar puerto ssh del 22 a 54322
echo "Cambiando puerto SSH de 22 a 54322..."
sed -i 's/#Port 22/Port 54322/' /etc/ssh/sshd_config

# Reiniciar el servicio SSH para aplicar los cambios
systemctl restart sshd

# Actualizar la regla de UFW para el nuevo puerto SSH
ufw delete allow 22/tcp
ufw allow 54322/tcp comment 'SSH'

echo "Puerto SSH cambiado exitosamente a 54322"


# Modificar el archivo /root/.bashrc
echo "Modificando /root/.bashrc..."
cat <<EOL >> /root/.bashrc

export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
alias ls='ls --color=auto'
alias dir='ls --color=auto --format=vertical'
alias vdir='ls --color=auto --format=long'
eval \`dircolors\`
alias ls='ls \$LS_OPTIONS'
LS_COLORS='no=00:fi=00:di=01;35:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:su=37;41:sg=30;43:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.flac=01;35:*.mp3=01;35:*.mpc=01;35:*.ogg=01;35:*.wav=01;35:';
PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[0;37m\][\t\[\033[0;37m\]]\[\033[0;33m\][\[\033[0;36m\]\u\[\033[0;36m\]@\[\033[0;36m\]\H \[\033[1;31m\]\w\[\033[0;33m\]]\[\033[0;31m\]\[\033[0;37m\]\\$ \[\033[00m\]'
export LS_OPTIONS='--color=auto'
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad
export GIT_PS1_SHOWDIRTYSTATE=true
export GIT_PS1_SHOWUNTRACKEDFILES=true
export GIT_PS1_SHOWSTASHSTATE=true
export PROMPT_DIRTRIM=3
export EDITOR="nano"
export VISUAL=nano
EOL

# Deshabilitar y rehabilitar byobu para que se apliquen los cambios
echo "Reiniciando byobu..."
byobu-disable
byobu-enable

echo "Configuración finalizada"