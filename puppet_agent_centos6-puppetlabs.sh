#!/bin/sh

REPO_URL="http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-7.noarch.rpm		"

if [ "$EUID" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

PUPPETLABS_REPO=http://yum.puppetlabs.com
REDHAT_RELEASE=/etc/redhat-release
EPEL_REPO=http://dl.fedoraproject.org/pub/epel

# SELinux
setenforce permissive

# Paqueteria recomendable ou necesaria
yum update --yes
yum install wget redhat-lsb
yum groupinstall -y "Development Tools"

# PuppetLabs repo
cd /tmp
wget http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-7.noarch.rpm
rpm -ivh puppetlabs-release-6-7.noarch.rpm
yum -y update

# Puppet
yum -y install puppet facter

# Puppet agent en modo 'daemon'	
puppet resource service puppet ensure=running enable=true
