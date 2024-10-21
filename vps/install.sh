#!/bin/bash

# Habilitar la salida inmediata ante errores
set -e


# Agregar servidores DNS para la resolución de nombres de dominio
echo "Configurando servidores DNS..."
echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf

# Actualización de definiciones y repositorios
echo "Actualizando repositorios y paquetes..."
apt-get update && apt-get upgrade -y



# --------------------------------------------------------------------------------


# Función para manejar errores y continuar
function install_package() {
    package=$1
    if ! apt-get -y install "$package"; then
        echo "Error instalando $package. Continuando con el siguiente paquete."
    fi
}

# Instalación de paquetes de uso cotidiano
echo "Instalando paquetes de uso cotidiano..."
packages=(
    # htop ufw nmon mtr bmon clamav rkhunter nmap rsync whois
    htop ufw nmon mtr bmon rkhunter nmap rsync whois ncdu sysstat vim nload curl unzip vim-nox byobu btop ufw speedtest-cli btop

)
for package in "${packages[@]}"; do
    install_package "$package"
done


# --------------------------------------------------------------------------------



# Instalar Tailscale
echo "Instalando Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Modificar la configuración de UFW
echo "Configurando UFW..."
sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw

# Deshabilitar IPv6
echo "Deshabilitando IPv6..."
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf

# Generar y configurar locales
echo "Configurando locales..."
locale-gen en_US.UTF-8
dpkg-reconfigure locales

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
export EDITOR="vim"
export VISUAL=vi
EOL


# Deshabilitar y rehabilitar byobu para que se apliquen los cambios
echo "Reiniciando byobu..."
byobu-disable
byobu-enable

# enable root ssh login
echo "Permitiendo acceso SSH al usuario root..."
sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config

# añadir linea al archivo nano /etc/ssh/sshd_config para permitir acceso root por password
echo "Permitiendo acceso SSH al usuario root por contraseña..."
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config


# Eliminar usuario deleteme
echo "Eliminando usuario deleteme..."
userdel -r deleteme
# eliminar archivos del usuario deleteme
rm -rf /home/deleteme

# Indicar al usuario que cierre las sesiones SSH
echo "Por favor, cierre todas las sesiones SSH y vuelva a ingresar para aplicar los cambios."


# Dar instrucciones para configurar el acceso por SSH mandando llave al servidor
echo "Para configurar el acceso por SSH, ejecute el siguiente comando en su máquina local:"
echo "ssh-copy-id -i ~/.ssh/id_rsa.pub root@$(curl -s ifconfig.me)"

# Cambiar puerto SSH a 54322
echo "Cambiando puerto SSH a 54322..."
sed -i 's/#Port 22/Port 54322/' /etc/ssh/sshd_config

# Reiniciar el servicio SSH
echo "Reiniciando el servicio SSH..."
systemctl restart ssh

