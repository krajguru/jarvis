#!/bin/bash

yum install -y -q ipa-client
service messagebus restart

## Edit resolv.conf to point to IPA server's DNS 

echo "service sssd restart" >> /etc/rc.local ; echo "echo \"search `hostname -d`\" > /etc/resolv.conf" >> /etc/rc.local ; echo "echo \"nameserver `grep node2 /etc/hosts | awk -F ' ' '{print $1}'`\" >> /etc/resolv.conf" >> /etc/rc.local
chmod +x /etc/rc.d/rc.local

## Setup IPA Client

ipa-client-install --password 'secret#1' --domain `hostname -d` --server `grep node2 /etc/hosts | awk '{print $2}'` --principal admin@`hostname -d| awk '{print toupper($0)}'` --password secret#1 --enable-dns-updates --unattended

## Change the Kerberos cache to FILE cache from KEYRING

sed -i.bak 's/.*default_ccache_name.*/default_ccache_name = FILE:\/tmp\/krb5cc_%{uid}/' /etc/krb5.conf
