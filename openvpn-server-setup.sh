#!/bin/bash
# Set up OpenVPN server on RPi
# See: http://www.jacobsalmela.com/setting-up-an-openvpn-server-on-the-raspberry-pi/
# See: https://github.com/Nyr/openvpn-install

ROOT_UID=0     # Only users with $UID 0 have root privileges.
LINES=50       # Default number of lines saved.
E_XCD=86       # Can't change directory?
E_NOTROOT=87   # Non-root exit error.

# Run as root or else.
if [ "$UID" -ne "$ROOT_UID" ]
then
  echo "Must be root to run this script."
  exit $E_NOTROOT
fi

if [ -n "$1" ]

# Test whether command-line argument is present (non-empty).
then
  lines=$1
else  
  lines=$LINES # Default, if not specified on command-line.
fi

# Run apt-get update and install OpenVPN, OpenSSL, and git
apt-get update
apt-get install -y openvpn openssl git

# Copy the Easy-RSA example files over to main OpenVPN directory
# cp -r /usr/share/doc/openvpn/examples/easy-rsa/2.0 /etc/openvpn/easy-rsa

# Get the Easy-RSA stuff from github; TODO: don't rely on github
git clone https://github.com/OpenVPN/easy-rsa.git /etc/openvpn/easy-rsa

# Set an absolute directory for the easy-rsa parent folder
export EASYRSA="/etc/openvpn/easy-rsa"

# TODO: pass all the KEY_* values automatically

# Build the certificate authority
/etc/openvpn/easy-rsa/easyrsa3/easyrsa init-pki
/etc/openvpn/easy-rsa/easyrsa3/easyrsa build-ca nopass #TODO: encrypt the file

# Build the certificate for a server and client
/etc/openvpn/easy-rsa/easyrsa3/easyrsa build-server-full servername nopass
/etc/openvpn/easy-rsa/easyrsa3/easyrsa build-client-full client1 nopass

# Generate the Diffie-Hellman
/etc/openvpn/easy-rsa/easyrsa3/easyrsa gen-dh

# So now we have a lot of nice files, keys, and certificates. They must be copied to the directory where OpenVPN will look for them
cp /etc/openvpn/easy-rsa/easyrsa3/pki/issued/servername.crt /etc/openvpn
cp /etc/openvpn/easy-rsa/easyrsa3/pki/ca.crt /etc/openvpn
cp /etc/openvpn/easy-rsa/easyrsa3/pki/dh.pem /etc/openvpn/dh2048.pem # Note the name change
cp /etc/openvpn/easy-rsa/easyrsa3/pki/private/ca.key /etc/openvpn
cp /etc/openvpn/easy-rsa/easyrsa3/pki/private/servername.key /etc/openvpn

# Make a copy of the example server config file to edit.  It is compressed by default, so it needs to be uncompressed and then renamed to match the server
cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/servername.conf.gz
gunzip /etc/openvpn/servername.conf.gz

# Update the Config File With the Correct Paths to the Keys Generated
sed -i -e 's/ca ca.crt/ca ca.crt/g' /etc/openvpn/servername.conf
sed -i -e 's/cert server.crt/cert servername.crt/g' /etc/openvpn/servername.conf
sed -i -e 's/key server.key/key servername.key/g' /etc/openvpn/servername.conf
sed -i -e 's/dh dh1024.pem/dh dh2048.pem/g' /etc/openvpn/servername.conf

# Enable Gateway Re-direct to Allow All Traffic to Flow Through the VPN
# sed -i -e 's/;push "redirect-gateway def1 bypass-dhcp"/push "redirect-gateway def1 bypass-dhcp"/g' /etc/openvpn/servername.conf

# Enable Client-to-client Communications
# sed -i -e 's/;client-to-client /client-to-client /g' /etc/openvpn/servername.conf

# Enable Routing
# /sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s 10.0.0.0/8 ! -d 10.0.0.0/8 -o eth0 -j MASQUERADE
iptables-save

# Start the OpenVPN Server
openvpn servername.conf

# Start the OpenVPN Automatically When the RPi Starts
sed -i -e 's/#AUTOSTART="all"/AUTOSTART="servername"/g' /etc/default/openvpn