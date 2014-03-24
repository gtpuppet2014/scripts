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
cat >/usr/share/puppet-dashboard/config/database.yaml<<END
production:
  database: dashboard
  username: admin
  password: Va633eQ0S80OP7l148T80670
  encoding: utf8
  adapter: mysql
END

rake gems:refresh_specs
rake RAILS_ENV=production db:migrate

cat >>/etc/puppet/puppet.conf <<END

# reports
reports = store, http
reporturl = http://$FQND:$PORT/reports/upload
storeconfigs = true

# dashboard
dbadapter = mysql
dbname = dashboard
dbuser = admin
dbpassword = Va633eQ0S80OP7l148T80670
dbserver = 127.0.0.1
dbconnections = 10
END

enable_service puppet-dashboard
#chkconfig puppet-dashboard on
#service puppet-dashboard start

chmod 0666 /usr/share/puppet-dashboard/log/production.log

enable_service puppet-dashboard-workers
#chkconfig puppet-dashboard-workers on
#service puppet-dashboard-workers start

/sbin/service httpd restart
