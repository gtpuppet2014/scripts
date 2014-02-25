#!/bin/sh

# De: https://github.com/panticz/installit/blob/master/install.puppet-client.sh
# ensure that this script is run by root
if [ $(id -u) -ne 0 ]; then
sudo $0
  exit
fi

# Instalar puppet desde repositorio "main" de Debian 7 'Wheezy' 
clear

apt-get update

# Paquetería recomendada
apt-get install -y gcc gcc-++ build-essential libxslt1-dev libxml2-dev libreadline-dev \
libreadline6-dev zlib1g-dev libssl-dev libyaml-dev curl git-core wget tree \
checkinstall make automake cmake autoconf linux-headers-`uname -r` p11-kit ssh ntpdate

# Para asegurar que 'facter' funcione correctamente
apt-get install -y lsb_release

# Ruby
apt-get install -y ruby ruby-dev ruby-rgen ruby-switch

# Rubygems
apt-get install -y rubygems

# Puppet
# apt-get install --yes puppet-common puppet
apt-get install -y puppet

# Opcional pero recomendado
apt-get install -y augeas-tools

# Por defecto o 'daemon' esta parado (/etc/default/puppet) <=> service puppet stop
# Equivalente a realizar: puppet resource service puppet ensure=stopped enable=false

# Se queremos inicialo e ademais que este arrincado no inicio da maquina:
service puppet start

# De: https://github.com/panticz/installit/blob/master/install.puppet-client.sh
[ -f /etc/default/puppet ] && sed -i 's|START=no|START=yes|g' /etc/default/puppet

# E equivalente a realizar: puppet resource service puppet ensure=running enable=true

echo "Puppet agent is installed!" >> /home/usuario/puppet_installation_message.txt
echo `ruby -v` >> /home/usuario/puppet_installation_message.txt
echo `facter --version` >> /home/usuario/puppet_installation_message.txt
echo `puppet -version` >> /home/usuario/puppet_installation_message.txt

exit 0;
