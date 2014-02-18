#!/bin/sh

# De: https://github.com/panticz/installit/blob/master/install.puppet-client.sh
# ensure that this script is run by root
if [ $(id -u) -ne 0 ]; then
sudo $0
  exit
fi

# Instalar puppet desde repositorio "apt.puppetlabs.com"
# Instalaranse versions concretas dos paquetes facter (1.7.4) e puppet (3.2.4)
clear
apt-get update

# Para asegurar que 'facter' funcione correctamente
apt-get install -y lsb_release

# Ruby
apt-get install -y ruby ruby-dev ruby1.8 ruby1.8-dev ruby-rgen ruby-switch

# Rubygems
apt-get install -y rubygems rubygems1.8

# Puppet
#
# De: https://github.com/gtpuppet2014/puppet-bootstrap/blob/master/debian.sh
cd /tmp
wget http://apt.puppetlabs.com/puppetlabs-release-wheezy.deb
dpkg -i puppetlabs-release-wheezy.deb
# Equivalente a: gpg --recv-key 4BD6EC30 && gpg -a --export 4BD6EC30 | sudo apt-key add -

apt-get update
apt-get install -y facter=1.7.4-1puppetlabs1
apt-get install -y puppet-common=3.2.4-1puppetlabs1
apt-get install -y puppet=3.2.4-1puppetlabs1

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
