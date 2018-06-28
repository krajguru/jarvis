#!/bin/bash

#user=/tmp/firstname.txt
#group=/tmp/groups

source /tmp/ipa-setup.properties
 
x=1
y=10

line_count_users=`cat "$FIRSTNAME" | wc -l`
line_count_groups=`cat $GROUPNAME | wc -l`


for (( i=1; i<=$line_count_groups; i++ ))
do
	group_name=`sed -n "$i"p "$GROUPNAME"`
	user_names=""
	for (( j=$x; j<=$y; j++ ))
	do
		user_names="${user_names}`sed -n "$j"p "$FIRSTNAME"`,"
		x=$((x + 1))
	done
	y=$((y + 10))
	user_list=`echo "${user_names::-1}"`

	echo "ipa group-add-member $group_name --user={$user_list}" >> /tmp/group-add-member.sh
done
chmod 777 /tmp/group-add-member.sh
sh /tmp/group-add-member.sh
