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
           
        ## Edit global password policy
        
           ipa pwpolicy-mod --maxlife=0 --minlife=0 global_policy

        ## Add users in IPA

           awk '{print "echo secret#1 | ipa user-add ",$1,"--first ",$2,"--last ",$3,"--password --shell=/bin/bash"}' /tmp/users.txt  > /tmp/ipa-add-users.sh
           chmod 777 /tmp/ipa-add-users.sh
           sh /tmp/ipa-add-users.sh | tee /tmp/users.out

        ## Add groups in IPA

           awk '{print "ipa group-add",$1,""}' /tmp/groups.txt > /tmp/ipa-add-groups.txt
           chmod 777 /tmp/ipa-add-groups.txt
           sh /tmp/ipa-add-groups.txt | tee /tmp/groups.out


        ## Add group-members in IPA

           chmod 777 /tmp/ipa-add-groups-members.sh
           sh /tmp/ipa-add-groups-members.sh
           
        ## Add administrative user in IPA for HDP cluster 
        
           echo secret#1 | ipa user-add hadoopadmin --first=Hadoop --last=Admin --password
           printf "secret#1\nsecret#1\nsecret#1" | kinit hadoopadmin
           echo secret#1 | kinit admin
           
        ## Creating a role and adding the required privileges
        
           ipa role-add hadoopadminrole
           ipa role-add-privilege hadoopadminrole --privileges="User Administrators" 
           ipa role-add-privilege hadoopadminrole --privileges="Service Administrators"
           ipa role-add-member hadoopadminrole --users=hadoopadmin
           
        ## Edit resolv.conf to point to IPA server's DNS
        
           echo "service sssd restart" > /tmp/dns.sh ; echo "echo \"search `hostname -d`\" > /etc/resolv.conf" >> /tmp/dns.sh ; echo "echo \"nameserver \`grep node2 /etc/hosts | awk -F ' ' '{print \$1}'\`\" >> /etc/resolv.conf" >> /tmp/dns.sh ; chmod 777 /tmp/dns.sh
           sed -i '/systemctl start sshd/ash /tmp/dns.sh' /start
           sh /tmp/dns.sh
           
           #rm -rf $USERS $GROUPS /tmp/ipa-add-users.sh /tmp/ipa-add-groups.txt
        ;;
esac
