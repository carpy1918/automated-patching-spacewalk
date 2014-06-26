#!/bin/bash

#
#Send notifications of patch events to app owners
#

if [ "$1" = '' ] || [ "$2" = '' ] || [ "$3" = '' ];then 
  echo "Invalid syntax. Syntax: patch-notification.sh <DATE> <PATCH_GROUP> <PRE|POST>"
fi

DATE=$1			#date of patching
PGROUP=$2		#patch group
MFLAG=$3		#message flag
user='apiuser'
passwd=password
server='fclpspcwksch01'
execdir='/home/xcxccarpenter/scripts/trunk/spacewalk'

if [[ "$MFLAG" = "PRE" ]];then
  MESSAGE=$(cat "$execdir/patching-notification.html")
else
  MESSAGE=$(cat "$execdir/patching-complete.html")
fi
 					#$1 is the DATE of execution
DLWEEK1=( zz.Tech.Infra.Notify@tealeafit.com sm-app-nprod-edt-prd@tealeafit.com technology-ApplicationSupport@tealeafit.com interactivesupport@tealeafit.com sm-srv-databaseSupport@tealeafit.com technology-Unix-Operations@tealeafit.com ttReleaseMgmt@tealeafit.com glowilliams@tealeafit.com xcxccarpenter@tealeafit.com curtis@tealeafit.com )	#Distribution list for Week1
#DLWEEK1=( xcxccarpenter@tealeafit.com )	#Distribution list for Week1
DLWEEK2=''				#Distribution list for Week2
DLWEEK3=''				#Distribution list for Week3
DLWEEK4=''				#Distribution list for Week4
FROM='curtis@tealeafit.com'
SUBJECT="$PGROUP - Patch Maintenance Notification"
SVRIGNORE=''
declare -a pbignore;

read -a pbignore <<< `spacecmd -s $server -u $user -p $passwd group_listsystems PB-IGNORE`
for i in "${pbignore[@]}";do
  echo "adding $i to ignore list"
  SVRIGNORE="$SVRIGNORE $i <br>"
done
M="${MESSAGE//PBIGNORELIST/$SVRIGNORE}"
MESSAGE=$M

for i in "${DLWEEK1[@]}";do
(echo "From: $FROM";echo "To: $i";echo "Subject: $SUBJECT";echo "Content-type: text/html";echo "MIME-version: 1.0";echo ${MESSAGE//DATE/$DATE};) | /usr/sbin/sendmail -t

done

