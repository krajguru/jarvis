#!/bin/bash

#OS_VERSION=`lsb_release -a | grep Release | awk '{print $2}' | awk -F . '{print $1}'`

#PASSWORD=secret#1

#USERS=/tmp/users.txt
#GROUPS=/tmp/groups.txt

## Change the default port of Ambari server to 8081 as IPA servers port conflicts with Ambari 

yum install -y -q ambari-agent
ambari-agent start

echo client.api.port=8081 >> /etc/ambari-server/conf/ambari.properties
ambari-server restart

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
           
           
           
        ## Script to check validity of HTTP keytab for GSSPROXY (IPA) and to edit resolv.conf to point to IPA server's DNS
        
echo "if [ -f /etc/security/keytabs/spnego.service.keytab ]" > /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "then" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "if [ -L /var/lib/ipa/gssproxy/http.keytab ]" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "then" >> /etc/gssproxy-ipa-httpkeytab-validity.sh 
echo "exit 0" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "else" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "rm -rf /var/lib/ipa/gssproxy/http.keytab" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "ln -s /etc/security/keytabs/spnego.service.keytab /var/lib/ipa/gssproxy/http.keytab" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "chmod 666 /etc/security/keytabs/spnego.service.keytab" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "fi" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "else" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "kinit -kt /var/lib/ipa/gssproxy/http.keytab HTTP/`hostname -f`" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "var1=\`echo \$?\`" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "if [ \$var1 -gt 0 ]" >> /etc/gssproxy-ipa-httpkeytab-validity.sh 
echo "then" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "echo secret#1 | kinit admin" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "rm -rf /var/lib/ipa/gssproxy/http.keytab" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "kadmin.local -q \"xst -k /var/lib/ipa/gssproxy/http.keytab HTTP/`hostname -f`\"" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "fi" >> /etc/gssproxy-ipa-httpkeytab-validity.sh
echo "fi" >> /etc/gssproxy-ipa-httpkeytab-validity.sh

chmod 770 /etc/gssproxy-ipa-httpkeytab-validity.sh

           echo "s1=\$(hostname -d)" > /tmp/dns.sh
           echo "s2=\$(grep search /etc/resolv.conf | awk -F ' ' '{print $2}')" >> /tmp/dns.sh
           echo "n1=\$(grep node1 /etc/hosts | awk -F ' ' '{print $1}' | head -n1)" >> /tmp/dns.sh
           echo "n2=\$(grep nameserver /etc/resolv.conf | awk -F ' ' '{print $2}')" >> /tmp/dns.sh
           echo "if [[ \$s1 == \$s2 && \$n1 == \$n2 ]]" >> /tmp/dns.sh
           echo "then" >> /tmp/dns.sh
           echo "exit 0" >> /tmp/dns.sh
           echo "else" >> /tmp/dns.sh
           echo "service sssd restart" >> /tmp/dns.sh ; echo "echo \"search `hostname -d`\" > /etc/resolv.conf" >> /tmp/dns.sh ; echo "echo \"nameserver \`grep node1 /etc/hosts | awk -F ' ' '{print \$1}' | head -n1 \`\" >> /etc/resolv.conf" >> /tmp/dns.sh ; chmod 777 /tmp/dns.sh
           echo "domain=\$(hostname -d)" >> /tmp/dns.sh
           echo "host=\$(hostname -s)" >> /tmp/dns.sh
           echo "a_rec=\$(nslookup \`hostname -s\` | tail -n2 | head -n1 | awk -F ' ' '{print \$2}')" >> /tmp/dns.sh
           echo "a_ip_addr=\$(grep \$host  /etc/hosts | awk '{print \$1}' | head -n1)" >> /tmp/dns.sh
           echo "echo secret#1 | kinit admin" >> /tmp/dns.sh
           echo "ipa dnsrecord-mod \$domain. \$host --a-rec=\$a_rec --a-ip-address=\$a_ip_addr" >> /tmp/dns.sh
           echo "exit 0" >> /tmp/dns.sh
           echo "fi" >> /tmp/dns.sh
           
           chmod 777 /tmp/dns.sh
           
           ##sed -i '/systemctl start sshd/ash /tmp/dns.sh' /start
           sh /tmp/dns.sh
        
           ## Crontab to run the validity scripts 
           
           echo "* * * * * root /tmp/dns.sh" >> /etc/crontab 
           echo "* * * * * root /etc/gssproxy-ipa-httpkeytab-validity.sh" >> /etc/crontab
        ## Setup a systemd servive                     
         
           ##echo -e "[Unit]\nDescription=Update IPA DNS Records after IP change\nAfter=ipa.service\n\n[Service]\nType=simple\nUser=root\nExecStart=/bin/bash /tmp/dns.sh\n\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/ipa-dns-update.service
           ##chmod 664 /etc/systemd/system/ipa-dns-update.service
           ##systemctl daemon-reload
           ##systemctl enable ipa-dns-update.service
           ##systemctl start ipa-dns-update.service
           
           #rm -rf $USERS $GROUPS /tmp/ipa-add-users.sh /tmp/ipa-add-groups.txt
        ;;
esac
