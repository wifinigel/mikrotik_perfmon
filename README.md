# mikrotik_perfmon

A simple demo of using MikroTik scripts to send performance data in to InfluxDB and visualize the data in Grafana.

This is not production code, but provides useful demo of visualizing performance data in Grafana for a MikroTik device.

# Instructions

This code uses a bash script to install InfluxDB and Grafana on to an Ubuntu or Raspberry Pi device. It will also perform basic configuration of both software packages. If you're not comfortable with having these packages installed on your Linux device, do not proceed with running the installation script. 

I've done my best to ensure that the installer script will run with no issues, but your system may have some version/configuration/oddities that I can't anticipate and may not run error-free, which could leave your system in a state of having partially installed code. Do not run this on a production system and/or if you are not comfortable with being able to recover the situation yourself.

There is also a removal script to uninstall both Grafana and InfluxDB, but the same caveats apply as for the installer script.

Bottom line: try this out on a VM/device/system you don't care about.

## Installation

```
cd ~
git clone https://github.com/wifinigel/mikrotik_perfmon.git
cd mikrotik_perfmon/grafana
chmod +x *.sh
sudo ./install_grafana.sh
```
