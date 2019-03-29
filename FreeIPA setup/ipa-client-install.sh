#!/bin/bash

yum install -y -q ipa-client
service messagebus restart

## Edit resolv.conf to point to IPA server's DNS 

echo "service sssd restart" > /tmp/dns.sh ; echo "echo \"search `hostname -d`\" > /etc/resolv.conf" >> /tmp/dns.sh ; echo "echo \"nameserver \`grep node1 /etc/hosts | awk -F ' ' '{print \$1}' | head -n1 \`\" >> /etc/resolv.conf" >> /tmp/dns.sh ; chmod 777 /tmp/dns.sh
           echo "domain=\$(hostname -d)" >> /tmp/dns.sh
           echo "host=\$(hostname -s)" >> /tmp/dns.sh
           echo "a_rec=\$(nslookup \`hostname -s\` | tail -n2 | head -n1 | awk -F ' ' '{print \$2}')" >> /tmp/dns.sh
           echo "a_ip_addr=\$(grep \$host  /etc/hosts | awk '{print \$1}' | head -n1 )" >> /tmp/dns.sh
           echo "echo secret#1 | kinit admin" >> /tmp/dns.sh
           echo "ipa dnsrecord-mod \$domain. \$host --a-rec=\$a_rec --a-ip-address=\$a_ip_addr" >> /tmp/dns.sh
sed -i '/systemctl start sshd/ash /tmp/dns.sh' /start
sh /tmp/dns.sh

## Setup IPA Client

ipa-client-install --password 'secret#1' --domain `hostname -d` --server `grep node1 /etc/hosts | awk '{print $2}'` --principal admin@`hostname -d| awk '{print toupper($0)}'` --password secret#1 --enable-dns-updates --unattended

## Change the Kerberos cache to FILE cache from KEYRING

sed -i.bak 's/.*default_ccache_name.*/default_ccache_name = FILE:\/tmp\/krb5cc_%{uid}/' /etc/krb5.conf
