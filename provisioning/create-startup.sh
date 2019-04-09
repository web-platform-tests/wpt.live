#!/bin/bash

function inject {
  source=$1
  destination=$2

  cat << HERE
cat > ${destination} << 'THERE'
$(cat ${source})
THERE
HERE
}

cat << 'HERE'
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export TZ=UTC
apt-get update
apt-get install --yes certbot git python2.7 python-pip tzdata
echo ${TZ} > /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata

mkdir /var/www-data/wpt
chown www-data /var/www-data/wpt
HERE

inject files/sync-wpt.sh /usr/local/bin/sync-wpt.sh
echo chmod +x /usr/local/bin/sync-wpt.sh

inject files/wpt-sync.service /etc/systemd/system/wpt-sync.service
echo systemctl enable wpt-sync.service
echo systemctl start wpt-sync.service

inject files/wpt-sync.timer /etc/systemd/system/wpt-sync.timer
echo systemctl enable wpt-sync.timer
echo systemctl start wpt-sync.timer

inject files/wpt.service /etc/systemd/system/wpt.service
echo systemctl enable wpt.service
echo systemctl start wpt.service
