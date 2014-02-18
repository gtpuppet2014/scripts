#!/bin/sh

# Instalar puppet desde repositorio "main" de Debian 7 'Wheezy' 
apt-get update
apt-get install -y lsb_release

# Paquetería recomendada
apt-get install -y gcc gcc-++ build-essential libxslt1-dev libxml2-dev libreadline-dev \
libreadline6-dev zlib1g-dev libssl-dev libyaml-dev curl git-core wget tree \
checkinstall make automake cmake autoconf linux-headers-`uname -r` p11-kit ssh

apt-get install -y ruby ruby-dev ruby-rgen ruby-switch
apt-get install -y rubygems
apt-get install -y puppet
apt-get install -y augeas-tools

# Por defecto o 'daemon' esta parado (/etc/default/puppet) <=> service puppet stop
# Equivalente a realizar: puppet resource service puppet ensure=stopped enable=false

# Se queremos inicialo e ademais que este arrincado no inicio da maquina:
service puppet start
sed -i /etc/default/puppet -e 's/START=no/START=yes/'

# E equivalente a realizar: puppet resource service puppet ensure=running enable=true

echo "Puppet agent is installed!" >> /home/usuario/puppet_installation_message.txt
echo `ruby -v` >> /home/usuario/puppet_installation_message.txt
echo `facter --version` >> /home/usuario/puppet_installation_message.txt
echo `puppet -version` >> /home/usuario/puppet_installation_message.txt
exit 0
