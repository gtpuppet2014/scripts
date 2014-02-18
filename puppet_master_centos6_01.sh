#!/bin/sh

# Puppetmaster en CentOS 6.x (64 bits) con Apache2 e Phussion Passenger
#
# Ruby version: 1.
# Facter version: 1.7.4
# Puppet version: 3.4.2
# Phussion Passenger: 3.x

# Refs: http://www.kermit.fr/kermit/doc/puppet/install.html
# http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm

REPO_URL="http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-7.noarch.rpm                "
PUPPETLABS_REPO="http://yum.puppetlabs.com"
REDHAT_RELEASE="/etc/redhat-release"
EPEL_REPO="http://dl.fedoraproject.org/pub/epel"

if [ "$EUID" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# SELinux
setenforce permissive

yum -y install ruby rubygems
yum -y install httpd mod_ssl

# Puppet-server
yum -y update
yum -y puppet-server-3.4.2-1.el6.noarch.rpm

/sbin/service httpd stop
/sbin/service puppetmaster start
/sbin/service puppetmaster stop

# EPEL
#rpm -ivh http://ftp.cica.es/epel/6/i386/epel-release-6-8.noarch.rpm
yum install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
# gpg key: http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6
yum update

# Passenger
#rpm -ivh $PKGPATH/osoptional/rubygem-rake-0.8.7-2.1.el6.noarch.rpm
#rpm -ivh $PPATH/rubygem-daemon_controller-0.2.5-1.noarch.rpm
yum -y install rubygem-rack rubygem-fastthread libev


/sbin/chkconfig httpd on
/sbin/chkconfig puppetmaster off
usermod -a -G puppet apache
/sbin/service puppetmaster stop
/sbin/service httpd restart

sed -i '/^exit 1$/d' /etc/init.d/puppetmaster
sed -i '1i\
exit 1' /etc/init.d/puppetmaster
