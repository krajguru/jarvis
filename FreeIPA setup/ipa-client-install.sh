#!/bin/bash

yum install -y ipa-client
service messagebus restart
ipa-client-install --password 'secret#1' --domain `hostname -d` --server `grep node2 /etc/hosts | awk '{print $2}'` --principal admin@`hostname -d| awk '{print toupper($0)}'` --password secret#1 --unattended
sed -i.bak 's/.*default_ccache_name.*/default_ccache_name = FILE:\/tmp\/krb5cc_%{uid}/' /etc/krb5.conf
