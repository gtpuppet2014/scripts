#!/bin/sh

# Basado en: https://raw.github.com/hashicorp/puppet-bootstrap/master/centos_6_x.sh

REPO_URL="http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-7.noarch.rpm		"
PUPPETLABS_REPO="http://yum.puppetlabs.com"
REDHAT_RELEASE="/etc/redhat-release"
EPEL_REPO="http://dl.fedoraproject.org/pub/epel"

if [ "$EUID" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# SELinux
setenforce permissive

# Paqueteria recomendable ou necesaria
yum update --yes
yum install -y wget screen telnet redhat-lsb
yum groupinstall -y "Development Tools"

if which puppet > /dev/null 2>&1; then
  echo "Puppet is already installed." 
  exit 0
else
# PuppetLabs repo
  cd /tmp
#  http://docs.puppetlabs.com/guides/puppetlabs_package_repositories.html#for-red-hat-enterprise-linux-and-derivatives
#  wget http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-10.noarch.rpm
#  rpm -ivh puppetlabs-release-6-10.noarch.rpm
  rpm -ivh https://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-7.noarch.rpm
  yum -y update

# Puppet (ultima version no repositorio)
#  yum install -y puppet facter

# facter 1.7.5 e puppet 3.4.3
  yum -y install facter-1.7.5-1.el6.noarch
  yum -y install puppet-3.4.3-1.el6.noarch
fi

# Puppet agent en modo 'daemon'	
puppet resource service puppet ensure=running enable=true
