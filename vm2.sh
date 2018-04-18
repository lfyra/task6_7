#!/bin/bash
dirname=$(dirname "$(readlink -f "$0")")
cd $dirname

source "vm2.config"
modprobe 8021q

echo "
# Interfaces available
source /etc/network/interfaces.d/*

# Loopback
auto lo
iface lo inet loopback

# Internal
auto $INTERNAL_IF
iface $INTERNAL_IF inet static
address $(echo $INT_IP | cut -d / -f 1)
netmask $(echo $INT_IP | cut -d / -f 2)
gateway $GW_IP
dns-nameserver 8.8.8.8

# VLAN
auto $INTERNAL_IF.$VLAN
iface $INTERNAL_IF.$VLAN inet static
address $(echo $APACHE_VLAN_IP | cut -d / -f 1)
netmask $(echo $APACHE_VLAN_IP | cut -d / -f 2)
vlan_raw_device $INTERNAL_IF" > /etc/network/interfaces

#ifconfig $INTERNAL_IF $INT_IP
#vconfig add $INTERNAL_IF $VLAN
#ifconfig $INTERNAL_IF.$VLAN $VLAN_IP

apt-get -y install apache2
rm /etc/apache2/sites-enabled/*
echo "
<VirtualHost *:80>
	ServerAdmin webmaster@localhost
	ServerName $(hostname)
	DocumentRoot /var/www/html
	ErrorLog ${APACHE_LOG_DIR}/error.log
	CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" > /etc/apache2/sites-available/$(hostname).conf
ln -s /etc/apache2/sites-available/$(hostname).conf /etc/apache2/sites-enabled/$(hostname).conf
sed -i "s/Listen 80/Listen $(echo $APACHE_VLAN_IP | cut -d / -f 1):80/" /etc/apache2/ports.conf
a2ensite $(hostname).conf
service apache2 restart

