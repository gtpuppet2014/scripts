#!/bin/sh

# Puppetmaster en CentOS 6.5 (64 bits) con Apache2 e Phussion Passenger
#
# Ruby version: 1.8.7
# Facter version: 1.7.5
# Puppet version: 2.7.23
# Phussion Passenger: 4

# RERERENCES ################################################################################

# - https://raw.githubusercontent.com/robinbowes/puppet-server-bootstrap/master/psb
# - http://www.kermit.fr/kermit/doc/puppet/install.html
# - https://github.com/sdoumbouya/puppetfiles/blob/master/puppetserver/puppetserver_bootstrap.sh
# - http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm
# - http://www.tokiwinter.com/running-puppet-master-under-apache-and-passenger/

# VARIABLES ################################################################################

# REPO_URL="http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-7.noarch.rpm"
# ELV=`cat /etc/redhat-release | gawk 'BEGIN {FS="release "} {print $2}' | gawk 'BEGIN {FS="."} {print $1}'` # osmajorversion

REDHAT_RELEASE=/etc/redhat-release
PUPPETLABS_REPO_BASE="http://yum.puppetlabs.com"
EPEL_REPO="http://dl.fedoraproject.org/pub/epel"
ARCH=`uname -m`
FQDN=`hostname -f`
TIMESERVER="hora.rediris.es"

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

############################################################################################
# hash defining the release RPM release for each of the OS combinations we know about
declare -A PUPPETLABS_RELEASE=(
  ["fedora/f17"]="7"
  ["fedora/f18"]="7"
  ["fedora/f19"]="2"
  ["el/5"]="7"
  ["el/6"]="7"
)

declare -A EPEL_RELEASE=(
  ["el/5"]="4"
  ["el/6"]="8"
)

if [[ -f $REDHAT_RELEASE ]] ; then
    OS_FAMILY=$(awk '{print $1}' $REDHAT_RELEASE)
    OS_VERSION=$(awk '{print $3}' $REDHAT_RELEASE)
    OS_MAJOR_VERSION=${OS_VERSION%%.*}
else
    error "$REDHAT_RELEASE not found" 101
fi

if [[ ${OS_FAMILY} == "Fedora" ]] ; then
    URL_FAMILY="fedora/f"
else
    URL_FAMILY="el/"
fi

# Make sure we know what the release RPM release number is for this os/version
FAMILY_VERSION="${URL_FAMILY}${OS_MAJOR_VERSION}"
PUPPETLABS_RPM_RELEASE="${PUPPETLABS_RELEASE["$FAMILY_VERSION"]}"
if [[ -z $PUPPETLABS_RPM_RELEASE ]] ; then
  error "puppetlabs release rpm not known for $FAMILY_VERSION" 101
fi

# retrieve the release RPM and install it
PUPPETLABS_RELEASE_NAME="puppetlabs-release-${OS_MAJOR_VERSION}-${PUPPETLABS_RPM_RELEASE}"
PUPPETLABS_RELEASE_RPM="${PUPPETLABS_RELEASE_NAME}.noarch.rpm"

if rpm_installed "${PUPPETLABS_RELEASE_NAME}" ; then
  echo "${PUPPETLABS_RELEASE_NAME} installed"
else
  PUPPETLABS_REPO_URL="${PUPPETLABS_REPO_BASE}/${FAMILY_VERSION}/products/$ARCH/${PUPPETLABS_RELEASE_RPM}"
  download "${PUPPETLABS_REPO_URL}" "${TEMP_DIR}/$PUPPETLABS_RELEASE_RPM"
  yum localinstall "${TEMP_DIR}/$PUPPETLABS_RELEASE_RPM"
fi

# Requirements ###################################################################################

# SELinux: permissive
/usr/sbin/setenforce 0
echo '0' > /selinux/enforce

# Stop/Disable IPTables v4/v6
disable_service iptables
disable_service ip6tables

yum -y update

yum -y install gcc-c++ yum-utils tzdata curl-devel zlib-devel openssl-devel apr-devel tree lsof \
git-core wget screen redhat-lsb
yum groupinstall -y "Development Tools" 

# Ntp service ####################################################################################
yum -y install ntp
disable_service ntpd

cat >/etc/ntp.conf<<END
driftfile /var/lib/ntp/drift
restrict default kod nomodify notrap nopeer noquery
restrict -6 default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
restrict -6 ::1

server $TIMESERVER iburst
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
END

ntpdate -q $TIMESERVER
enable_service ntpd

# Puppet-server ###################################################################################
yum -y install puppet-server-2.7.23-1.el6.noarch
#yum -y install puppet-server-3.4.2-1.el6.noarch

testmkdir /etc/puppet



# Necesario para xerar o certificado do puppetmaster
/sbin/service puppetmaster start
/sbin/service puppetmaster stop





# Passenger ######################################################################################

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
