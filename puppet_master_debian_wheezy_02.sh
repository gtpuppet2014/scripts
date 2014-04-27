#!/bin/sh

# Ref: http://gutocarvalho.net/dokuwiki/doku.php/puppet_instalando_puppet_master_em_debian
# Passenger: http://apt.puppetlabs.com/pool/wheezy/main/p/puppet/puppetmaster-passenger_3.4.2-1puppetlabs1_all.deb

export DEB_REPO_FINAL="/etc/apt/sources.list.d/puppetlabs.list"
export SUFFIX="1puppetlabs1"
export PUPPET_VERSION="3.4.3"
export RACK_VERSION="1.5.2"
export PASSENGER_VERSION="4.0.31"
export RAKE_VERSION="10.3.1"
export PUPPET_PORT="8140"
export FQDN=`hostname -f`
export PUPPETVERSION=`facter puppetversion`
export HOSTNAME=`/usr/bin/facter hostname`
export PASSENGER_VERSION="4.0.41"
IP=`/usr/bin/facter ipaddress`
TIMESERVER="hora.rediris.es"
TEMP_DIR=${TEMP:-/tmp}

# Run this script as root
if [ $(id -u) -ne 0 ]; then
sudo $0
  exit
fi

# Update the repositories
apt-get update

# Create new directory if it doesn't exist
testmkdir () {
    if [ ! -d $1 ]; then
        mkdir -p $1
    fi
}

apt-get install -y gcc gcc-++ build-essential libxslt1-dev libxml2-dev libreadline-dev libreadline6-dev zlib1g-dev libssl-dev libyaml-dev \
curl git-core wget tree checkinstall make automake cmake autoconf linux-headers-`uname -r` p11-kit ssh

apt-get install -y puppetmaster-common=$PUPPET_VERSION-$SUFFIX puppetmaster=$PUPPET_VERSION-$SUFFIX
apt-get install -y ntp ntpdate
ntpdate -q $TIMESERVER
service ntpd restart

service puppetmaster start
service puppetmaster stop

testmkdir "/etc/puppet"
cat >/etc/puppet/puppet.conf<<END
[main]
vardir      = /var/lib/puppet
logdir      = /var/log/puppet
rundir      = /var/run/puppet
ssldir      = /var/lib/puppet/ssl
statedir    = /var/lib/puppet/state
confdir     = /etc/puppet
factpath    = /var/lib/puppet/facts:/var/lib/puppet/lib/facter
logdestfile = /var/log/puppet/puppet.log
pluginsync  = true

server        = $FQDN
dns_alt_names = $FQDN

[master]
ca        = true
ca_server = $FQDN
ca_name   = $FQDN
certname  = $FQDN
autosign = /etc/puppet/autosign.conf
manifestdir = /etc/puppet/manifests
manifest = /etc/puppet/manifests/site.pp
modulepath = /etc/puppet/modules:/etc/puppet/local

# These are needed when the puppetmaster is run by passenger
# and can safely be removed if webrick is used.
ssl_client_header = SSL_CLIENT_S_DN
ssl_client_verify_header = SSL_CLIENT_VERIFY
END

echo "*.sanclemente.local" >> /etc/puppet/autosign.conf

apt-get install -y apache2-mpm-prefork apache2-mpm-worker apache2 ruby-dev ruby1.8-dev rubygems libcurl4-openssl-dev \
apache2-threaded-dev libapr1-dev libaprutil1-dev 

service apache2 stop

gem install rack -v $RACK_VERSION --no-ri --no-rdoc
gem install rake -v $RAKE_VERSION --no-ri --no-rdoc
gem install passenger -v $PASSENGER_VERSION --no-ri --no-rdoc
passenger-install-apache2-module --auto # versions actualizadas

# Create the directory structure for Puppet Master Rack Application
mkdir -p /usr/share/puppet/rack/puppetmasterd
mkdir /usr/share/puppet/rack/puppetmasterd/public /usr/share/puppet/rack/puppetmasterd/tmp
wget https://raw.github.com/puppetlabs/puppet/master/ext/rack/config.ru -O /usr/share/puppet/rack/puppetmasterd/config.ru
chown puppet /usr/share/puppet/rack/puppetmasterd/config.ru

cat > /etc/apache2/sites-available/puppetmaster.conf<<EOF
LoadModule passenger_module /var/lib/gems/1.9.1/gems/passenger-$PASSENGER_VERSION/buildout/apache2/mod_passenger.so
   <IfModule mod_passenger.c>
     PassengerRoot /var/lib/gems/1.9.1/gems/passenger-$PASSENGER_VERSION
#     PassengerDefaultRuby /usr/bin/ruby1.9.1
   </IfModule>

# And the passenger performance tuning settings:
PassengerHighPerformance On
#####PassengerUseGlobalQueue On
# Set this to about 1.5 times the number of CPU cores in your master:
PassengerMaxPoolSize 6
# Recycle master processes after they service 1000 requests
PassengerMaxRequests 1000
# Stop processes if they sit idle for 10 minutes
PassengerPoolIdleTime 600

Listen $PUPPET_PORT
<VirtualHost *:$PUPPET_PORT>
    SSLEngine On

    # Only allow high security cryptography. Alter if needed for compatibility.
    SSLProtocol             All -SSLv2
    SSLCipherSuite          HIGH:!ADH:RC4+RSA:-MEDIUM:-LOW:-EXP
    SSLCertificateFile      /var/lib/puppet/ssl/certs/$FQDN.pem
    SSLCertificateKeyFile   /var/lib/puppet/ssl/private_keys/$FQDN.pem
    SSLCertificateChainFile /var/lib/puppet/ssl/ca/ca_crt.pem
    SSLCACertificateFile    /var/lib/puppet/ssl/ca/ca_crt.pem
    SSLCARevocationFile     /var/lib/puppet/ssl/ca/ca_crl.pem
    SSLVerifyClient         optional
    SSLVerifyDepth          1
    SSLOptions              +StdEnvVars +ExportCertData

    # These request headers are used to pass the client certificate
    # authentication information on to the puppet master process
    RequestHeader set X-SSL-Subject %{SSL_CLIENT_S_DN}e
    RequestHeader set X-Client-DN %{SSL_CLIENT_S_DN}e
    RequestHeader set X-Client-Verify %{SSL_CLIENT_VERIFY}e

###    RackAutoDetect On

# Possible values include: debug, info, notice, warn, error, crit,
   # alert, emerg.
   ErrorLog /var/log/apache2/puppetmaster_error.log
   LogLevel warn
   CustomLog /var/log/apache2/puppetmaster_access.log combined
   ServerSignature On

   DocumentRoot /usr/share/puppet/rack/puppetmasterd/public/

   <Directory /usr/share/puppet/rack/puppetmasterd/>
        Options None
        AllowOverride None
        Order Allow,Deny
        Allow from All
   </Directory>
</VirtualHost>
EOF

a2ensite puppetmaster
a2enmod passenger headers ssl

service apache2 restart
chkconfig apache2 on

chkconfig puppetmaster off
inserv -r puppetmaster
update-rc.d -f puppetmaster remove

testmkdir "/etc/puppet/manifests"
testmkdir "/etc/puppet/modules"
testmkdir "/etc/puppet/local"
touch /etc/puppet/manifests/site.pp
cat >/etc/puppet/manifests/site.pp<<END

node default {
  notify("this is the $fqdn node")
}

END
