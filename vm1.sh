#!/bin/bash

dname=$(dirname "$(readlink -f "$0")")
cd $dname

source  "vm1.config"
modprobe 8021q

echo "
# Available interfaces
source /etc/network/interfaces.d/*

# Loopback
auto lo
iface lo inet loopback

# Internal
auto $INTERNAL_IF
iface $INTERNAL_IF inet static
address $(echo $INT_IP | cut -d / -f 1)
netmask $(echo $INT_IP | cut -d / -f 2)

# VLAN
auto $INTERNAL_IF.$VLAN
iface $INTERNAL_IF.$VLAN inet static
address $(echo $VLAN_IP | cut -d / -f 1)
netmask $(echo $VLAN_IP | cut -d / -f 2)
vlan_raw_device $INTERNAL_IF 
" > /etc/network/interfaces

#Check DHCP

if  [ "$EXT_IP" == DHCP ]
then
echo "
# Ext
auto $EXTERNAL_IF
iface $EXTERNAL_IF inet dhcp
" >> /etc/network/interfaces
else
echo "
# Ext
auto $EXTERNAL_IF
iface $EXTERNAL_IF inet static
address $(echo $EXT_IP | cut -d / -f 1)
netmask $(echo $EXT_IP | cut -d / -f 2)
gateway $EXT_GW
dns-nameserver 8.8.8.8
" >> /etc/network/interfaces
fi

#Up

ifconfig $EXTERNAL_IF $EXT_IP
ifconfig $INTERNAL_IF $INT_IP

vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF.$VLAN $VLAN_IP

sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o $EXTERNAL_IF -j MASQUERADE

IP=$(ifconfig $EXTERNAL_IF | grep "inet addr" | cut -d: -f2 | cut -d' ' -f1)

#Root certificate

openssl  genrsa -out /etc/ssl/private/root-ca.key 2048
openssl req -x509 -new -key /etc/ssl/private/root-ca.key -days 365 -out /etc/ssl/certs/root-ca.crt -subj "/C=UA/ST=KharkivOblast/L=Kharkiv/O=KhNURE/OU=IMI/CN=rootCA"

#Web certificate

openssl genrsa -out /etc/ssl/private/web.key 2048
openssl req -new -key /etc/ssl/private/web.key -nodes -out /etc/ssl/certs/web.csr -subj "/C=UA/ST=KharkivOblast/L=Karkiv/O=KhNURE/OU=IMI/CN=$(hostname -f)"

openssl x509 -req -extfile  <(printf "subjectAltName=IP:$IP") -days 365 -in /etc/ssl/certs/web.csr -CA /etc/ssl/certs/root-ca.crt -CAkey /etc/ssl/private/root-ca.key -CAcreateserial -out /etc/ssl/certs/web.crt
cat /etc/ssl/certs/root-ca.crt >> /etc/ssl/certs/web.crt
echo $IP $(hostname) > /etc/hosts

#nginx

apt-get -y install nginx
rm  -r /etc/nginx/sites-enabled/*
cp /etc/nginx/sites-available/default /etc/ngnix/sites-available/$(hostname)
echo " 
server {
	listen $IP:$NGINX_PORT ssl;
	server_name $(hostname)
	ssl on;
	ssl_certificate /etc/ssl/certs/web.crt;
	ssl_certificate_key /etc/ssl/private/web.key;

	location / {
	proxy_pass http://$(hostname);
	}
}" > /etc/nginx/sites-available/$(hostname)
ln -s /etc/nginx/sites-available/$(hostname) /etc/nginx/sites-enabled/$(hostname)
service nginx restart
