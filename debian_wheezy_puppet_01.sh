#!/bin/sh

apt-get update
apt-get install -y lsb_release

apt-get install -y gcc gcc-++ build-essential libxslt1-dev libxml2-dev libreadline-dev \
libreadline6-dev zlib1g-dev libssl-dev libyaml-dev curl git-core wget tree \
checkinstall make automake cmake autoconf linux-headers-`uname -r` p11-kit ssh

apt-get install -y ruby ruby-dev ruby-rgen ruby-switch
apt-get install -y rubygems
apt-get install -y puppet
apt-get install -y augeas-tools

# puppet resource service puppet ensure=running enable=true
sed -i /etc/default/puppet -e 's/START=no/START=yes/'
service puppet restart
