#!/bin/bash

#OS_VERSION=`lsb_release -a | grep Release | awk '{print $2}' | awk -F . '{print $1}'`

#PASSWORD=secret#1

#USERS=/tmp/users.txt
#GROUPS=/tmp/groups.txt

source /tmp/ipa-setup.properties

case "$OS_VERSION" in

        7) yum install -q -y ipa-server bind bind-dyndb-ldap ipa-server-dns
           echo net.ipv6.conf.lo.disable_ipv6=0 >> /etc/sysctl.conf
           sysctl -p
           service messagebus restart
           ipa-server-install -a 'secret#1' --hostname=`hostname` -r `hostname -d| awk '{print toupper($0)}'` -p 'secret#1' -n `hostname -d` --setup-dns --no-forwarders  --allow-zone-overlap -U
           sed -i.bak 's/.*default_ccache_name.*/default_ccache_name = FILE:\/tmp\/krb5cc_%{uid}/' /etc/krb5.conf
           echo secret#1 | kinit admin

        ## Add users to IPA

           awk '{print "echo secret#1 | ipa user-add ",$1,"--first ",$2,"--last ",$3,"--password --shell=/bin/bash"}' /tmp/users.txt  > /tmp/ipa-add-users.sh
           chmod 777 /tmp/ipa-add-users.sh
           sh /tmp/ipa-add-users.sh | tee /tmp/ipa-add-users.out

        ## Add groups to IPA

           awk '{print "ipa group-add",$1,""}' /tmp/groups.txt > /tmp/ipa-add-groups.txt
           chmod 777 /tmp/ipa-add-groups.txt
           sh /tmp/ipa-add-groups.txt | tee /tmp/ipa-add-group.out


        ## Add groups to IPA

           chmod 777 /tmp/ipa-add-groups-members.sh
           sh /tmp/ipa-add-groups-members.sh

           #rm -rf $USERS $GROUPS /tmp/ipa-add-users.sh /tmp/ipa-add-groups.txt
        ;;
         6) yum install -q -y ipa-server bind bind-dyndb-ldap
            echo net.ipv6.conf.lo.disable_ipv6=0 >> /etc/sysctl.conf
            sysctl -p
            ipa-server-install -a 'secret#1' --hostname=`hostname` -r `hostname -d| awk '{print toupper($0)}'` -p 'secret#1' -n `hostname -d` -U
            sed -i.bak 's/.*default_ccache_name.*/default_ccache_name = FILE:\/tmp\/krb5cc_%{uid}/' /etc/krb5.conf
        ;;
esac
