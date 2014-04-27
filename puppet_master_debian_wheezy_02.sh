#!/bin/sh

# http://gutocarvalho.net/dokuwiki/doku.php/puppet_instalando_puppet_master_em_debian
# http://gutocarvalho.net/dokuwiki/doku.php/puppet_instalando_puppet_dashboard_remoto_em_debian
# http://apt.puppetlabs.com/pool/wheezy/main/p/puppet/puppetmaster-passenger_3.4.3-1puppetlabs1_all.deb

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
export DASH_VERSION="1.2.23"
export DASH_PASSWD="dashboard"
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
service ntpd stop
ntpdate -q $TIMESERVER
service ntpd start

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

apt-get install -y apache2-mpm-prefork \
#apache2-mpm-worker \
apache2 ruby-dev ruby1.8-dev rubygems libcurl4-openssl-dev apache2-threaded-dev libapr1-dev \
libaprutil1-dev 

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

cat > /etc/apache2/sites-available/puppetmaster<<EOF
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

a2enmod passenger headers ssl
a2ensite puppetmaster

service apache2 restart
puppet resource service apache2 ensure=running enable=true 

/etc/init.d/puppetmaster stop
update-rc.d -f puppetmasterremove

testmkdir "/etc/puppet/manifests"
testmkdir "/etc/puppet/modules"
testmkdir "/etc/puppet/local"
touch /etc/puppet/manifests/site.pp
cat >/etc/puppet/manifests/site.pp<<END

node default {
  notify("this is the $fqdn node")
}

END

# PUPPET DASHBOARD 1.2.23
testmkdir /opt/puppetlabs/manifests
testmkdir /opt/puppetlabs/modules

apt-get install -y libactiverecord-ruby libmysql-ruby irb libmysqlclient-dev libopenssl-ruby libreadline-ruby
apt-get install -y puppet-dashboard=$DASH_VERSION-$SUFFIX

puppet module install --force --ignore-dependencies --modulepath /opt/puppetlabs/modules/ puppetlabs-stdlib --version 3.2.1
puppet module install --force --ignore-dependencies --modulepath /opt/puppetlabs/modules/ puppetlabs-concat --version 1.0.2
puppet module install --force --ignore-dependencies --modulepath /opt/puppetlabs/modules/ puppetlabs-inifile --version 1.0.3
puppet module install --force --ignore-dependencies --modulepath /opt/puppetlabs/modules/ puppetlabs-mysql --version 2.2.3

git clone https://github.com/puppetlabs/puppetlabs-auth_conf /opt/puppetlabs/modules/auth_conf
cd /opt/puppetlabs/modules/auth_conf
git checkout tags/0.2.0

cat >/opt/puppetlabs/manifests/site.pp <<EOF
node default {
  notice("this is the $fqdn node")

  include mysql::server

  mysql::db { 'dashboard':
    user     => 'admin',
    password => '$DASH_PASSWD',
    host     => 'localhost',
    grant    => ['all'],
  }

  include auth_conf::defaults

  auth_conf::acl { '/inventory':
    auth       => 'any',
    acl_method => 'search',
    allow      => '*',
    order      => 081,
  }
  auth_conf::acl { '/facts':
    auth       => 'any',
    acl_method => ['find','search','save'],
    allow      => '*',
    order      => 082,
  }

}
EOF

puppet apply -v /opt/puppetlabs/manifests/site.pp --modulepath /opt/puppetlabs/modules

sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
sed -i 's/"max_allowed_packet = 32M"/"max_allowed_packet = 16M"/g' /etc/mysql/my.cnf
service mysql restart

cd /usr/share/puppet-dashboard/config

cat >/usr/share/puppet-dashboard/config/database.yml <<END
production:
  database: dashboard
  username: admin
  password: $DASH_PASSWD
  encoding: utf8
  adapter: mysql
END

cat >/usr/share/puppet-dashboard/config/settings.yml <<END
#===[ Settings ]=========================================================
#
# This file is meant for storing setting information that is never
# published or committed to a revision control system.
#
# Do not modify this "config/settings.yml.example" file directly -- you
# should copy it to "config/settings.yml" and customize it there.
#
#---[ Values ]----------------------------------------------------------

# Node name to use when contacting the puppet master.  This is the
# CN that is used in Dashboard's certificate.
cn_name: 'dashboard'

ca_crl_path: 'certs/dashboard.ca_crl.pem'

ca_certificate_path: 'certs/dashboard.ca_cert.pem'

certificate_path: 'certs/dashboard.cert.pem'

private_key_path: 'certs/dashboard.private_key.pem'

public_key_path: 'certs/dashboard.public_key.pem'

# Hostname of the certificate authority.
ca_server: '$FQDN'

# Port for the certificate authority.
ca_port: 8140

# Key length for SSL certificates
key_length: 1024

# The "inventory service" allows you to connect to a puppet master to retrieve and node facts
enable_inventory_service: true

# Hostname of the inventory server.
inventory_server: '$FQDN'
# Port for the inventory server.
inventory_port: 8140

# Set this to true to allow Dashboard to display diffs on files that
# are archived in the file bucket.
use_file_bucket_diffs: false

# Hostname of the file bucket server.
file_bucket_server: '$FQDN'

# Port for the file bucket server.
file_bucket_port: 8140

# Amount of time in seconds since last report before a node is considered no longer reporting
no_longer_reporting_cutoff: 3600

# How many days of history to display on the "Daily Run Status" graph
daily_run_history_length: 30

use_external_node_classification: true

# Uncomment the following line to set a local time zone.  Run
# "rake time:zones:local" for the name of your local time zone.
time_zone: 'Madrid'

# Look at http://ruby-doc.org/core/classes/Time.html#M000298 for the strftime formatting
datetime_format: '%Y-%m-%d %H:%M %Z'
date_format: '%A, %B %e, %Y'

# Set this to the URL of an image. The image will be scaled to the specified dimensions.
custom_logo_url: '/images/dashboard_logo.png'
custom_logo_width: 155px
custom_logo_height: 23px
custom_logo_alt_text: 'Puppet Dashboard'

# We will be deprecating using "http://dashboard_servername/reports" as the puppet master's reporturl.
# Set this to 'true' once you have changed all your puppet masters to send reports to
# "http://dashboard_servername/reports/upload"
disable_legacy_report_upload_url: false

# Disables the UI and controller actions for editing nodes, classes, groups and reports.  Report submission is still allowed
enable_read_only_mode: false

# Default number of items of each kind to display per page
nodes_per_page: 20
classes_per_page: 50
groups_per_page: 50
reports_per_page: 20

#===[ fin ]=============================================================
END

rake gems:refresh_specs
rake RAILS_ENV=production db:migrate

touch /usr/share/puppet-dashboard/log/production.log
chmod 0666 /usr/share/puppet-dashboard/log/production.log

cat >/etc/apache2/sites-available/dashboard <<END
Listen 3000

<VirtualHost *:3000>
        SetEnv RAILS_ENV production
        PassengerRuby /usr/bin/ruby
        PassengerHighPerformance on
        PassengerMaxPoolSize 12
        PassengerPoolIdleTime 1500
        PassengerMaxRequests 1000
        PassengerStatThrottleRate 120
#        RailsAutoDetect On
#        RailsBaseURI /

        ServerName $FQDN
        DocumentRoot /usr/share/puppet-dashboard/public/
        ErrorLog /var/log/apache2/dashboard_error.log
        LogLevel warn
        CustomLog /var/log/apache2/dashboard_access.log combined
        ServerSignature On

        <Directory /usr/share/puppet-dashboard/public/>
                AllowOverride all
                Options -MultiViews
                Order allow,deny
                allow from all
        </Directory>
</VirtualHost>
END

a2ensite dashboard
service apache2 restart

cat >>/etc/puppet/puppet.conf <<EOF

# reports
reports      = store, http
reporturl    = http://$FQDN:$PUPPET_PORT/reports/upload
storeconfigs = true

# dashboard
dbadapter     = mysql
dbname        = dashboard
dbuser        = admin
dbpassword    = $DASH_PASSWD
dbserver      = 127.0.0.1
dbconnections = 10

# ENC
node_terminus  = exec
external_nodes = /usr/bin/env PUPPET_DASHBOARD_URL=http://$FQDN:$PUPPET_PORT /usr/share/puppet-dashboard/bin/external_node
EOF

service puppetmaster restart

/etc/init.d/puppet-dashboard stop
update-rc.d -f puppet-dashboard remove

touch /usr/share/puppet-dashboard/log/production.log
chmod 0666 /usr/share/puppet-dashboard/log/production.log

env RAILS_ENV=production script/delayed_job -p dashboard -n `facter processorcount` -m start
chown -R www-data: /usr/share/puppet-dashboard/tmp/

sed -i 's/START=no/START=yes/g' /etc/default/puppet-dashboard-workers
/etc/init.d/puppet-dashboard-workers restart
