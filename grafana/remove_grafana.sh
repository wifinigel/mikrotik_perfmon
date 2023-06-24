#!/usr/bin/env bash

# manual Grafana removal for WLANPi RPi edition

if [ $EUID -ne 0 ]; then
   echo "This script must be run as root (e.g. use 'sudo')" 
   exit 1
fi

GRAFANA_PORT=3000

# Figure out which dir we're in
SCRIPT_PATH=$(dirname $(readlink -f $0))
cd $SCRIPT_PATH

echo ""
echo "* ========================="
echo "* Removing Grafana..."
echo "* ========================="


echo "* Stopping services."
sudo systemctl stop grafana-server
sudo systemctl disable grafana-server
sudo systemctl reset-failed grafana-server

echo "* Removing packages & files."
sudo apt-get purge grafana -y
sudo rm -rf /etc/grafana
sudo rm -rf /var/lib/grafana
sudo rm -rf /var/log/grafana
sudo rm -rf /usr/share/grafana

echo "* Restoring firewall port."
sudo ufw delete  allow ${GRAFANA_PORT}/tcp

echo "* Done."


echo ""
echo "* ========================="
echo "* Removing Influxdb..."
echo "* ========================="

sudo systemctl stop influxdb
sudo systemctl disable influxdb
sudo apt-get purge influxdb -y
sudo systemctl reset-failed influxdb
sudo rm /usr/lib/systemd/system/influxdb.service
echo "* Tidying up non-empty folders."
sudo rm -rf /var/lib/influxdb
sudo rm /etc/default/influxdb

# tidy up grafana binaries downloaded
echo "* Removing downloaded .deb files."
sudo rm $SCRIPT_PATH/grafana*.deb*

echo "* Done."