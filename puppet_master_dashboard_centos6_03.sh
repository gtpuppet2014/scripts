#!/bin/bash
#
# Puppetmaster (Apache and Phussion Passenger)
# CentOS 6.5 (64 bits)
# Ruby version: 1.8.7
# Facter version: 1.7.5
# Puppet version: 2.7.23
# Phussion Passenger: 4

# RERERENCES ################################################################################

# - http://gutocarvalho.net/puppet/doku.php

# VARIABLES ################################################################################

REDHAT_RELEASE=/etc/redhat-release
PUPPETLABS_REPO_BASE="http://yum.puppetlabs.com"
EPEL_REPO_BASE="http://dl.fedoraproject.org/pub/epel"
EPEL_RPM_RELEASE="8"
ARCH=`uname -m`
FQDN=`hostname -f`
PORT="3000"
HOSTNAME=`/usr/bin/facter hostname`
IP=`/usr/bin/facter ipaddress`
TEMP_DIR=${TEMP:-/tmp}

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
  try /sbin/chkconfig $1 on
  try /sbin/service $1 start
}

disable_service() {
  try /sbin/chkconfig $1 off
  try /sbin/service $1 stop
}

# DASHBOARD ################################################################################

yum --enablerepo=puppetlabs* -y install puppet-dashboard-1.2.23-1.el6.noarch rubygem-activerecord.noarch

testmkdir "/opt/puppetlabs/{manifests,modules}"
puppet module install --force --ignore-dependencies --modulepath /opt/puppetlabs/modules/ puppetlabs-stdlib --version 3.2.1
puppet module install --force --ignore-dependencies --modulepath /opt/puppetlabs/modules/ puppetlabs-mysql --version 2.2.3

cat >/opt/puppetlabs/manifests/site.pp<<EOF
node default {
  notice("this is the $fqdn node")

  include mysql::server

  mysql::db { 'dashboard':
    user     => 'admin',
    password => 'Va633eQ0S80OP7l148T80670',
    host     => 'localhost',
    grant    => ['all'],
  }

}
EOF

puppet apply -v /opt/puppetlabs/manifests/site.pp --modulepath /opt/puppetlabs/modules

cd /usr/share/puppet-dashboard/config
cat >/usr/share/puppet-dashboard/config/database.yml<<END
production:
  database: dashboard
  username: admin
  password: Va633eQ0S80OP7l148T80670
  encoding: utf8
  adapter: mysql
END

cat >/usr/share/puppet-dashboard/config/settings.yml<<END
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

cat >>/etc/puppet/puppet.conf <<END

# reports
reports = store, http
reporturl = http://$FQDN:$PORT/reports/upload
storeconfigs = true

# dashboard
dbadapter = mysql
dbname = dashboard
dbuser = admin
dbpassword = Va633eQ0S80OP7l148T80670
dbserver = 127.0.0.1
dbconnections = 10
END

cat >/etc/puppet/auth.conf <<END
# This is an example auth.conf file, it mimics the puppetmasterd defaults
#
# The ACL are checked in order of appearance in this file.
#
# Supported syntax:
# This file supports two different syntax depending on how
# you want to express the ACL.
#
# Path syntax (the one used below):
# ---------------------------------
# path /path/to/resource
# [environment envlist]
# [method methodlist]
# [auth[enthicated] {yes|no|on|off|any}]
# allow [host|ip|*]
# deny [host|ip]
#
# The path is matched as a prefix. That is /file match at
# the same time /file_metadat and /file_content.
#
# Regex syntax:
# -------------
# This one is differenciated from the path one by a '~'
#
# path ~ regex
# [environment envlist]
# [method methodlist]
# [auth[enthicated] {yes|no|on|off|any}]
# allow [host|ip|*]
# deny [host|ip]
#
# The regex syntax is the same as ruby ones.
#
# Ex:
# path ~ .pp$
# will match every resource ending in .pp (manifests files for instance)
#
# path ~ ^/path/to/resource
# is essentially equivalent to path /path/to/resource
#
# environment:: restrict an ACL to a specific set of environments
# method:: restrict an ACL to a specific set of methods
# auth:: restrict an ACL to an authenticated or unauthenticated request
# the default when unspecified is to restrict the ACL to authenticated requests
# (ie exactly as if auth yes was present).
#

### Authenticated ACL - those applies only when the client
### has a valid certificate and is thus authenticated

# allow nodes to retrieve their own catalog (ie their configuration)
path ~ ^/catalog/([^/]+)$
method find
allow $1

# allow nodes to retrieve their own node definition
path ~ ^/node/([^/]+)$
method find
allow $1

# allow all nodes to access the certificates services
path /certificate_revocation_list/ca
method find
allow *

# allow all nodes to store their own reports
path ~ ^/report/([^/]+)$
method save
allow $1

# inconditionnally allow access to all files services
# which means in practice that fileserver.conf will
# still be used
path /file
allow *

### Unauthenticated ACL, for clients for which the current master doesn't
### have a valid certificate; we allow authenticated users, too, because
### there isn't a great harm in letting that request through.

# allow access to the master CA
path /certificate/ca
auth any
method find
allow *

path /certificate/
auth any
method find
allow *

path /certificate_request
auth any
method find, save
allow *

#######################################################
# Inventory
path /inventory
method search
allow *

path /facts
auth any
method find, search
allow *

path /facts
auth any
method save
allow *

#######################################################

# this one is not stricly necessary, but it has the merit
# to show the default policy which is deny everything else
path /
auth any
END

enable_service puppet-dashboard
#chkconfig puppet-dashboard on
#service puppet-dashboard start

chmod 0666 /usr/share/puppet-dashboard/log/production.log

enable_service puppet-dashboard-workers
#chkconfig puppet-dashboard-workers on
#service puppet-dashboard-workers start

/sbin/service httpd restart
