#!/bin/sh

# mkdir if it doesn't exist
testmkdir () {
    if [ ! -d $1 ]; then
        mkdir -p $1
    fi
}

testmkdir /etc/puppet

### Debian default 'puppet.conf'
#
###################################################################
#[main]
#logdir=/var/log/puppet
#vardir=/var/lib/puppet
#ssldir=/var/lib/puppet/ssl
#rundir=/var/run/puppet
#factpath=$vardir/lib/facter
#templatedir=$confdir/templates
#
#[master]
## These are needed when the puppetmaster is run by passenger
## and can safely be removed if webrick is used.
#ssl_client_header = SSL_CLIENT_S_DN 
#ssl_client_verify_header = SSL_CLIENT_VERIFY
#
###################################################################

cat > /etc/puppet/puppet.conf <<END
[main]
    logdir           = /var/log/puppet
    vardir           = /var/lib/puppet
    ssldir           = /var/lib/puppet/ssl
    rundir           = /var/run/puppet
    factpath         = /var/lib/puppet/lib/facter
    reportdir        = /var/lib/puppet/reports
    confdir          = /etc/puppet
    config           = /etc/puppet/puppet.conf
    pluginsync       = true

[agent]
    classfile   = /var/lib/puppet/classes.txt
    localconfig = /var/lib/puppet/localconfig
    server      = puppet.domain # nome ficticio
    environment = production # entorno por defecto
    listen      = false
    daemon      = false # equivalente a: --non-daemonize
    report      = true

[master]
    # These are needed when the puppetmaster is run by passenger
    # and can safely be removed if webrick is used.
    ssl_client_header = SSL_CLIENT_S_DN 
    ssl_client_verify_header = SSL_CLIENT_VERIFY

    modulepath       = /etc/puppet/modules
    templatedir      = /etc/puppet/templates
    manifestdir      = /etc/puppet/manifests
    manifest         = /etc/puppet/manifests/site.pp
    fileserverconfig = /etc/puppet/fileserver.conf
    hiera_config     = /etc/puppet/hiera.yaml

    ca        = true
    ca_server = puppet.domain # nome ficticio
   
END

# Hiera
testmkdir /etc/puppet/hieradata

if [ ! -e /etc/puppet/hiera.yaml ]; then
cat > /etc/puppet/hiera.yaml <<END
---
:backends:
  - yaml

:hierarchy:
  - "%{::clientcert}" 
  - common

:datadir: '/etc/puppet/hieradata'

:logger: console
END
fi
