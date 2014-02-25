#!/bin/sh

# Puppetmaster en CentOS 6.x (64 bits) con Apache2 e Phussion Passenger
#
# Ruby version: 1.
# Facter version: 1.7.4
# Puppet version: 3.4.2
# Phussion Passenger: 3.x

# Refs:
# - http://www.kermit.fr/kermit/doc/puppet/install.html
# - https://github.com/sdoumbouya/puppetfiles/blob/master/puppetserver/puppetserver_bootstrap.sh
# - http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm
# - http://www.tokiwinter.com/running-puppet-master-under-apache-and-passenger/

REPO_URL="http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-7.noarch.rpm"
PUPPETLABS_REPO="http://yum.puppetlabs.com"
REDHAT_RELEASE="/etc/redhat-release"
EPEL_REPO="http://dl.fedoraproject.org/pub/epel"

if [ "$EUID" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# SELinux
setenforce permissive
echo '0' > /selinux/enforce

yum install -y ruby ruby-devel ruby-shadow rubygems ruby-rdoc
yum install -y httpd httpd-devel mod_ssl gcc-c++ curl-devel zlib-devel openssl-devel apr-devel

# Puppet-server
yum -y update
yum install -y puppet-server-3.4.2-1.el6.noarch.rpm

/sbin/service httpd stop

# Necesario para xerar o certificado do puppetmaster
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

#yum -y install rubygem-rack rubygem-fastthread libev

usermod -a -G puppet apache

# yum -y install rubygem-passenger mod_passenger
gem install rack passenger
passenger-install-apache2-module # versions actualizadas
 
# Create the directory structure for Puppet Master Rack Application
mkdir -p /usr/share/puppet/rack/puppetmasterd
mkdir /usr/share/puppet/rack/puppetmasterd/public /usr/share/puppet/rack/puppetmasterd/tmp
cp /usr/share/puppet/ext/rack/files/config.ru /usr/share/puppet/rack/puppetmasterd/
chown puppet /usr/share/puppet/rack/puppetmasterd/config.ru

# Create a virtual host for puppet
# Replace x.x.x with the passenger module version
# Replace puppet.domain with the fqdn of the puppetmaster
cat << 'EOF' > /etc/httpd/conf.d/puppetmaster.conf
# RHEL/CentOS:
LoadModule passenger_module /usr/lib/ruby/gems/1.8/gems/passenger-x.x.x/ext/apache2/mod_passenger.so
PassengerRoot /usr/lib/ruby/gems/1.8/gems/passenger-x.x.x
PassengerRuby /usr/bin/ruby
# And the passenger performance tuning settings:
PassengerHighPerformance On
PassengerUseGlobalQueue On
# Set this to about 1.5 times the number of CPU cores in your master:
PassengerMaxPoolSize 6
# Recycle master processes after they service 1000 requests
PassengerMaxRequests 1000
# Stop processes if they sit idle for 10 minutes
PassengerPoolIdleTime 600
Listen 8140
<VirtualHost *:8140>
SSLEngine On
# Only allow high security cryptography. Alter if needed for compatibility.
SSLProtocol All -SSLv2
SSLCipherSuite HIGH:!ADH:RC4+RSA:-MEDIUM:-LOW:-EXP
SSLCertificateFile /var/lib/puppet/ssl/certs/puppet.domain.pem
SSLCertificateKeyFile /var/lib/puppet/ssl/private_keys/puppet.domain.pem
SSLCertificateChainFile /var/lib/puppet/ssl/ca/ca_crt.pem
SSLCACertificateFile /var/lib/puppet/ssl/ca/ca_crt.pem
SSLCARevocationFile /var/lib/puppet/ssl/ca/ca_crl.pem
SSLVerifyClient optional
SSLVerifyDepth 1
SSLOptions +StdEnvVars +ExportCertData
# These request headers are used to pass the client certificate
# authentication information on to the puppet master process
RequestHeader set X-SSL-Subject %{SSL_CLIENT_S_DN}e
RequestHeader set X-Client-DN %{SSL_CLIENT_S_DN}e
RequestHeader set X-Client-Verify %{SSL_CLIENT_VERIFY}e
RackAutoDetect On
DocumentRoot /usr/share/puppet/rack/puppetmasterd/public/
<Directory /usr/share/puppet/rack/puppetmasterd/>
Options None
AllowOverride None
Order Allow,Deny
Allow from All
</Directory>
</VirtualHost>
EOF

/sbin/chkconfig httpd on
/sbin/chkconfig puppetmaster off
/sbin/service httpd restart

sed -i '/^exit 1$/d' /etc/init.d/puppetmaster
sed -i '1i\
exit 1' /etc/init.d/puppetmaster

# Firewall
#
chkconfig ip6tables off
service ip6tables stop
# Equivalente a engadir esta linha en /etc/sysconfig/iptables: -A RH-Firewall-1-INPUT -p tcp -m tcp --dport 8140 -j ACCEPT
iptables -I INPUT -p tcp --dport 8140 -j ACCEPT
#iptables -I INPUT -p tcp --dport 443 -j ACCEPT
service iptables save

# ACL's
#
#setfacl -m u:apache:rx /usr/share/puppet
#getfacl /usr/share/puppet
# file: usr/share/puppet
# owner: puppet
# group: puppet
