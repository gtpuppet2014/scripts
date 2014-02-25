#!/bin/sh

# Ref: http://gutocarvalho.net/dokuwiki/doku.php/puppet_instalando_puppet_master_em_debian

# Passenger: http://apt.puppetlabs.com/pool/wheezy/main/p/puppet/puppetmaster-passenger_3.4.2-1puppetlabs1_all.deb

DEB_REPO_FINAL="/etc/apt/sources.list.d/puppetlabs.list"
SUFFIX="1puppetlabs1"
PUPPET_VERSION="3.4.2"

if [ $(id -u) -ne 0 ]; then
sudo $0
  exit
fi

clear
apt-get update

# mkdir if it doesn't exist
testmkdir () {
    if [ ! -d $1 ]; then
        mkdir -p $1
    fi
}

apt-get install -y puppetmaster=$PUPPET_VERSION-$SUFFIX puppetmaster-passenger=$PUPPET_VERSION-$SUFFIX
apt-get install -y ntpdate apache2
#apt-get install -y libapache2-mod-passenger 

service puppetmaster start
service puppetmaster stop

service apache2 stop

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
cat << 'EOF' > /etc/apache2/sites-available/puppetmaster.conf
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

a2ensite puppetmaster.conf
a2enmod passenger headers ssl

service apache2 start
chkconfig apache2 on
chkconfig puppetmaster off
inserv -r puppetmaster

