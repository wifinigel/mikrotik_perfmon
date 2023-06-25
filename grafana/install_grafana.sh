#!/usr/bin/env bash

# manual Grafana installation for Mikrotik dashboard

set -e

if [ $EUID -ne 0 ]; then
   echo "This script must be run as root (e.g. use 'sudo')" 
   exit 1
fi

# Check we're connected to the Internet
echo "Checking Internet connection..."
if ping -q -w 1 -c 1 google.com > /dev/null; then
  echo "Connected."
else
  echo "We do not appear to be connected to the Internet (I can't ping Google.com), exiting."
  exit 1
fi

# random pwd generator
rand_pwd() {
  < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-20};echo;
}

# Figure out which dir we're in
SCRIPT_PATH=$(dirname $(readlink -f $0))
cd $SCRIPT_PATH

# Define install log file
INSTALL_LOG="install.log"
echo "====================================================" > $INSTALL_LOG
echo " Installation start..." >> $INSTALL_LOG
echo "====================================================" >> $INSTALL_LOG
echo "" >> $INSTALL_LOG

# Grafana admin user
GRAFANA_PORT=3000
GRAFANA_USER=admin
GRAFANA_PWD=Password1

echo "GRAFANA_PORT=$GRAFANA_PORT" >> $INSTALL_LOG
echo "GRAFANA_USER=$GRAFANA_USER" >> $INSTALL_LOG
echo "GRAFANA_PWD=$GRAFANA_PWD" >> $INSTALL_LOG

# Influx DB admin
DB_USER=mtikuser
DB_PWD=$(rand_pwd)

echo "DB_USER=$DB_USER"  >> $INSTALL_LOG
echo "DB_PWD=$DB_PWD"  >> $INSTALL_LOG

# Influx grafana user
DB_GRAFANA_USER=grafana
DB_GRAFANA_PWD=$(rand_pwd)

echo "DB_GRAFANA_USER=$DB_GRAFANA_USER"  >> $INSTALL_LOG
echo "DB_GRAFANA_PWD=$DB_GRAFANA_PWD"  >> $INSTALL_LOG

# Influx agent user
DB_PROBE_USER=mtik_agent
DB_PROBE_PWD=$(rand_pwd)

echo "DB_PROBE_USER=$DB_PROBE_USER"  >> $INSTALL_LOG
echo "DB_PROBE_PWD=$DB_PROBE_PWD"  >> $INSTALL_LOG

echo "" | tee -a $INSTALL_LOG
echo "* =========================" | tee -a $INSTALL_LOG
echo "* Installing Grafana..." | tee -a $INSTALL_LOG
echo "* =========================" | tee -a $INSTALL_LOG


echo "* Installing pre-req packages." | tee -a $INSTALL_LOG
sudo apt-get install -y adduser libfontconfig1

# get architecture type
ARCH=$(dpkg --print-architecture)

echo "* Downloading Grafana." | tee -a $INSTALL_LOG
wget https://dl.grafana.com/oss/release/grafana_9.5.5_${ARCH}.deb

echo "* Installing Grafana." | tee -a $INSTALL_LOG
sudo dpkg -i grafana_9.5.5_${ARCH}.deb

# remove requirement to set default admin pwd & change default user/pwd to wlanpi/wlanpi
echo "* Customizing Grafana." | tee -a $INSTALL_LOG
sudo sed -i 's/;disable_initial_admin_creation/disable_initial_admin_creation/g' /etc/grafana/grafana.ini
sudo sed -i 's/;admin_user = admin/admin_user = '"$GRAFANA_USER"'/g' /etc/grafana/grafana.ini
sudo sed -i 's/;admin_password = admin/admin_password = '"$GRAFANA_PWD"'/g' /etc/grafana/grafana.ini

# set grafana to listen on port GRAFANA_PORT
sudo sed -i 's/;http_port = 3000/http_port = '"$GRAFANA_PORT"'/g' /etc/grafana/grafana.ini

# take care of grafana service
echo "* Enabling & starting Grafana service." | tee -a $INSTALL_LOG
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# display status of service
echo "* Grafana service status:" | tee -a $INSTALL_LOG
sudo systemctl status --no-pager -l grafana-server | head -n 10
echo "* Grafana Done." | tee -a $INSTALL_LOG


echo "" | tee -a $INSTALL_LOG
echo "* =========================" | tee -a $INSTALL_LOG
echo "* Installing InfluxDB..." | tee -a $INSTALL_LOG
echo "* =========================" | tee -a $INSTALL_LOG


echo "* Getting InfluxDB code...." | tee -a $INSTALL_LOG

wget -q https://repos.influxdata.com/influxdata-archive_compat.key
echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c && cat influxdata-archive_compat.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | sudo tee /etc/apt/sources.list.d/influxdata.list

sudo apt update

echo "* Installing InfluxDB code...." | tee -a $INSTALL_LOG
sudo apt install influxdb
sudo chown influxdb:influxdb /usr/lib/influxdb/scripts/influxd-systemd-start.sh

echo "* Enabling & starting InfluxDB service." | tee -a $INSTALL_LOG
sudo systemctl unmask influxdb.service
sudo systemctl enable influxdb
sudo systemctl start influxdb

# display status of service
echo "* InfluxDB service status:" | tee -a $INSTALL_LOG
sudo systemctl status --no-pager -l influxdb | head -n 10

echo "" | tee -a $INSTALL_LOG
echo "* =========================" | tee -a $INSTALL_LOG
echo "* Configuring InfluxDB..." | tee -a $INSTALL_LOG
echo "* =========================" | tee -a $INSTALL_LOG

echo "* Creating DB & users..." | tee -a $INSTALL_LOG

# create DB
DB_NAME="mikrotik_dashboard"

echo "Database name: ${DB_NAME}" | tee -a $INSTALL_LOG
echo "Database user: ${DB_USER}" | tee -a $INSTALL_LOG
echo "Database password: ${DB_PWD}" | tee -a $INSTALL_LOG

influx -execute "create database $DB_NAME" 
influx -execute "create retention policy wiperf_30_days on $DB_NAME duration 30d replication 1" -database $DB_NAME

# create DB admin user
influx -execute "create user $DB_USER with password '$DB_PWD' with all privileges"

# create grafana user with read-ony to pull stats
influx -execute "CREATE USER $DB_GRAFANA_USER WITH PASSWORD '$DB_GRAFANA_PWD'"
influx -execute "GRANT read ON $DB_NAME TO $DB_GRAFANA_USER"

# create wiperf probe user with write access
influx -execute "CREATE USER $DB_PROBE_USER WITH PASSWORD '$DB_PROBE_PWD'"
influx -execute "GRANT WRITE ON $DB_NAME TO $DB_PROBE_USER"

# enable DB authentication
sudo sed -i 's/# auth-enabled = false/auth-enabled = true/g' /etc/influxdb/influxdb.conf
sudo systemctl restart influxdb

# add data source to Grafana
echo "* Adding DB as data source to Grafana..." | tee -a $INSTALL_LOG

echo "* Adding DB name & credentials for data source." | tee -a $INSTALL_LOG
echo "Script path = $SCRIPT_PATH" | tee -a $INSTALL_LOG
sudo sed -i "s/password:.*$/password: $DB_GRAFANA_PWD/" $SCRIPT_PATH/influx_datasource.yaml
sudo sed -i "s/user:.*$/user: $DB_GRAFANA_USER/" $SCRIPT_PATH/influx_datasource.yaml
sudo sed -i "s/dbname:.*$/dbname: $DB_NAME/" $SCRIPT_PATH/influx_datasource.yaml

sudo cp $SCRIPT_PATH/influx_datasource.yaml /etc/grafana/provisioning/datasources/

# set home page dashboard
sudo sed -i 's/^;default_home_dashboard_path =.*$/default_home_dashboard_path = \/usr\/share\/grafana\/public\/dashboards\/MikroTik_Monitor.json/' /etc/grafana/grafana.ini

echo "* Restarting grafana." | tee -a $INSTALL_LOG
sudo systemctl restart grafana-server

# add dashboard to Grafana
echo "* Adding dashboards to Grafana..." | tee -a $INSTALL_LOG
sudo cp  ${SCRIPT_PATH}/dashboards/*.json /usr/share/grafana/public/dashboards/
sudo cp ${SCRIPT_PATH}/import_dashboard.yaml /etc/grafana/provisioning/dashboards/
sudo systemctl restart grafana-server

# add influx credentials to exporter script
echo "* Adding host IP & DB pwd to MikroTik exporter script.." | tee -a $INSTALL_LOG
EXPORTER_FILE_NAME="../mikrotik_scripts/influx_exporter.rsc"
HOSTNAME=$(hostname -I | cut -d" " -f1)
sudo sed -i "s/local InfluxHost \".*\"/local InfluxHost \"$HOSTNAME\"/" $EXPORTER_FILE_NAME
sudo sed -i "s/local InfluxPassword \".*\"/local InfluxPassword \"$DB_PROBE_PWD\"/" $EXPORTER_FILE_NAME

cat << EOF | tee -a $INSTALL_LOG
******************************************************************
*
* !!! Installation complete. Please review instructions below !!!
*
* ================================================
*  Browse Grafana at: http://${HOSTNAME}:${GRAFANA_PORT}/ 
*  (user/pwd=$GRAFANA_USER/$GRAFANA_PWD)
* ================================================
*
*  Copy the following files from the folder: "../mikrotik_scripts" to your MikroTik device (e.g. sftp):
*
*   - influx_exporter.rsc
*   - interface_stats.rsc
*   - system_stats.rsc
*
*  Add the following scripts to the MikroTik scheduler:
*
*   interface_stats.rsc (1 min interval)
*   system_stats.rsc (5 min interval)
*
*  Watch the MikroTok logs for error indications.
*
******************************************************************

EOF
