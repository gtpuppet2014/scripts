#!/bin/bash
#
# Puppetmaster (Apache and Phussion Passenger)
# CentOS 6.5 (64 bits)
# Ruby version: 1.8.7
# Facter version: 1.7.5
# Puppet version: 3.4.3
# Phussion Passenger: 4

# RERERENCES ################################################################################

# - http://gutocarvalho.net/puppet/doku.php

# VARIABLES ################################################################################

REDHAT_RELEASE=/etc/redhat-release
PUPPETLABS_REPO_BASE="http://yum.puppetlabs.com"
EPEL_REPO_BASE="http://dl.fedoraproject.org/pub/epel"
EPEL_RPM_RELEASE="8"
ARCH=`uname -m`
export FQDN=`hostname -f`
export PORT="3000"
export HOSTNAME=`/usr/bin/facter hostname`
IP=`/usr/bin/facter ipaddress`
TEMP_DIR=${TEMP:-/tmp}
PASSENGER="true"
export DASH_PASSWD="dashboard"

# FUNCTIONS ################################################################################

# Run it as root
if [ "$EUID" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

function error() {
  echo "ERROR: $1"
  exit $2
}

function rpm_installed() {
  rpm -q --quiet $1
}

function download(){
  if ! curl --fail --location --silent "$1" -o "$2"; then
    error "Error downloading $1" 101
  fi
}

# mkdir if it doesn't exist
testmkdir() {
    if [ ! -d $1 ]; then
        mkdir -p $1
    fi
}

disable_repo() {
   local conf=/etc/yum.repos.d/$1.repo
   if [ ! -e "$conf" ]; then
       echo "Yum repo config $conf not found -- exiting."
       exit 1
   else
       sed -i -e 's/^enabled.*/enabled=0/g' $conf
   fi
}

include_repo_packages() {
  local conf=/etc/yum.repos.d/$1.repo
  if [ ! -e "$conf" ]; then
      echo "Yum repo config $conf not found -- exiting."
      exit 1
  else
      shift
      sed -i -e "/\[$1\]/ a\includepkgs=$2" ${conf}
      sed -i -i "/\[$1\]/,/\]/ s/^enabled.*/enabled=1/" ${conf}
  fi
}

enable_service() {
  /sbin/chkconfig $1 on
  /sbin/service $1 start
}

disable_service() {
  /sbin/chkconfig $1 off
  /sbin/service $1 stop
}

# DASHBOARD ################################################################################
disable_repo puppetlabs

yum --enablerepo=puppetlabs* -y install puppet-dashboard-1.2.23-1.el6.noarch rubygem-activerecord-2.3.16-1.el6.noarch

testmkdir /opt/puppetlabs/manifests
testmkdir /opt/puppetlabs/modules

puppet module install --force --ignore-dependencies --modulepath /opt/puppetlabs/modules/ puppetlabs-stdlib --version 3.2.1
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

enable_service puppet-dashboard
#chkconfig puppet-dashboard on
#service puppet-dashboard start

chmod 0666 /usr/share/puppet-dashboard/log/production.log

enable_service puppet-dashboard-workers
#chkconfig puppet-dashboard-workers on
#service puppet-dashboard-workers start

/sbin/service httpd restart

if $PASSENGER == "true" {
cat >/etc/httpd/conf.d/dashboard.conf <<END
<VirtualHost *:80>
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
        ErrorLog /var/log/httpd/dashboard_error.log
        LogLevel warn
        CustomLog /var/log/httpd/dashboard_access.log combined
        ServerSignature On

        <Directory /usr/share/puppet-dashboard/public/>
                AllowOverride all
                Options -MultiViews
                Order allow,deny
                allow from all
        </Directory>
</VirtualHost>
END

cat >>/etc/puppet/puppet.conf <<EOF

# reports
reports      = store, http
reporturl    = http://$FQDN/reports/upload
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
external_nodes = /usr/bin/env PUPPET_DASHBOARD_URL=http://$FQDN /usr/share/puppet-dashboard/bin/external_node
EOF

disable_service puppet-dashboard

else
cat >>/etc/puppet/puppet.conf <<EOF

# reports
reports      = store, http
reporturl    = http://$FQDN:$PORT/reports/upload
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
external_nodes = /usr/bin/env PUPPET_DASHBOARD_URL=http://$FQDN:$PORT /usr/share/puppet-dashboard/bin/external_node
EOF

enable_service puppet-dashboard
#chkconfig puppet-dashboard on
#service puppet-dashboard start
}
