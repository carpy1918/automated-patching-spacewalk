#!/bin/bash

#
#spacecmd-wrapper.sh
#
user='apiuser'
passwd=password
server='spacewalk.tealeafit.com'
execdir='/home/xcxccarpenter/scripts/trunk/spacewalk'
groupList=$1
parseEachSvr=1                  #execute spacecmd on each group - 0, or execute spacecmd on each server - 1
localGroups=0                   #use "servers/groups.txt" for server groups to parse - 0, or query Spacewalk - 1
parseSpacewalk=1                #query Spacewalk for packages - 0, otherwise execute on "packages/default.txt" - 1
serverGroup=''                  #track the group of a server
packageString=''                #compiled upgrade packages in string
logfile="/tmp/spacecmd-wrapper-$(date +%m%d%Y).log"
declare -a patchGroups          #server patch groups
declare -a packages             #packages to upgrade
declare -a exceptions           #packages to ignore
declare -a servers              #list of servers
declare -a pbignore		#spacewalk ignore list

if [ "$groupList" = "" ] && [ $localGroups -eq 0 ];then
  echo "Syntax: patching_command.pl <Spacewalk_group_list>"
  exit
fi

#
#getGroups
#
function getGroups {
  echo "getGroups: gathering Spacewalk groups" >> $logfile
  if [ $localGroups = 0 ];then
    read -a patchGroups <<< `cat $groupList`
  else
    read -a patchGroups <<< `spacecmd -s $server -u $user -p $passwd -y group_list`
  fi

  for i in $(cat $execdir/servers/group-exceptions.txt);do
    declare -i c=0
    for j in "${patchGroups[@]}";do
      if [ "$j" = "$i" ];then
        unset $patchGroups[$c]
      fi
      c=$(($c+1))
    done
  done
} #end function

#
#getPB-IGNORE
#
function getIgnore {
  echo "getIgnore: getting the servers in the Spacewalk ignore list" >> $logfile
  read -a pbignore <<< `spacecmd -s $server -u $user -p $passwd group_listsystems PB-IGNORE` 
} #end function

#
#applyErrata
#
function applyErrata {
  obj=$1
  echo "obj: $obj and type $2" >> $logfile
  if [ $2 = "group" ];then
    type='group:'
  elif [ $2 = "server" ];then
    type=''
  else
    echo 'applyErrata: failure in patch type assignment' >> $logfile
  fi

  rm -f /tmp/errata.txt
  spacecmd -s $server -u $user -p $passwd system_listerrata $type$obj | egrep -i '(CEBA|FEDORA|RHEL|Redhat)' | awk '{print $1}' > /tmp/errata.txt
  for i in $(cat /tmp/errata.txt);do
    echo "applyErrata: looping with $type and $obj and $i" >> $logfile
    spacecmd -s $server -u $user -p $passwd -y system_applyerrata $type$obj $i
  done
} #end function

#
#getGroupSvrs
#
function getGroupSvrs {
  serverGroup=$1
  echo "getGroupSvrs: getting servers in group: $serverGroup" >> $logfile
  read -a servers <<< `spacecmd -s $server -u $user -p $passwd group_listsystems $serverGroup`

  for i in $(cat $execdir/servers/server-exceptions.txt);do
    declare -i c=0
    for j in "${servers[@]}";do
      if [ "$j" = "$i" ];then
        unset $servers[$c]
      fi
      c=$(($c+1))
    done
  done
} #end function

#
#getExceptions
#
function getExceptions {
  serverGroup=$1
  echo "getExceptions: getting exceptions for $serverGroup" >> $logfile

  if ls $execdir/exceptions/$serverGroup > /dev/null;then
    read -a exceptions <<< `cat $execdir/exceptions/$serverGroup`
  else
    echo "getExceptions: no exceptions found for $serverGroup" >> $logfile
    exceptions=()
  fi
} #end function

#
#getPackages
#
function getPackages {
object=$1
echo "getPackages: getting packages for $object" >> $logfile
if [ "$parseSpacewalk" = "0" ];then
  getGroupSvrs $object
  read -a packages <<< `spacecmd -s $server -u $user -p $passwd system_listupgrades $servers`
else
  read -a packages <<< `cat $execdir/packages/default.txt`
fi

for i in "${packages[@]}";do                    #parse array and create patch string
  dirty=0                                       #flag for exception match
  for j in "${exceptions[@]}";do
    if [ $i = $j ];then
      dirty=1
    fi
  done
  if [ $dirty = 0 ] && [[ ! "$i" =~ i[6|3]86 ]]; then
    echo $i > /tmp/temp
    str=`gawk -F "-[0-9]" '{print $1}' < /tmp/temp`
#    packageString="$packageString $str"
    packageString="$packageString $str"
  fi
dirty=0
done
} #end function

#
#parseEachServer
#
function parseEachServer {
for i in "${patchGroups[@]}"; do
  serverGroup=$i
  echo "parseEachServer: parsing loop with: $serverGroup" >> $logfile
  if [[ $serverGroup =~ ^PB ]] && [[ ! "$serverGroup" = "PB-IGNORE" ]];then
    if [[ "$serverGroup" =~ ^PB ]];then
    getGroupSvrs $serverGroup
    for j in "${servers[@]}";do
      dirty=0
      for k in "${pbignore}";do
        echo "parseEachServer: $serverGroup : $k and $j" >> $logfile
        if [ $k = $j ];then
          echo "parseEachServer: pbignore: $k match. dirty." >> $logfile
          dirty=1
        fi
      done
      if [ $dirty = 0 ];then
        svr=$j
        getExceptions $serverGroup
        getPackages $serverGroup
        patch $svr "server"
        #spacecmd -s $server -u $user -p $passwd -y system_reboot $svr
      fi
    done
    fi
  else
    echo "parseEachServer: $i is being skipped" >> $logfile
  fi
done
} #end function

#
#patch
#
function patch {
  object=$1
  COMMAND="spacecmd"
  COUNT=`ps aux | grep "$COMMAND" | wc -l`
  MAX=30

  if [ $2 = "group" ];then
    type='group:'
  elif [ $2 = "server" ];then
    type=''
  else
    echo 'patch: failure in type assignment' >> $logfile
  fi

  for i in "${packages[@]}";do
    dirty=0
    for j in "${exceptions[@]}";do
      if [ $i = $j ];then
	dirty=1
      fi
    done
    if [ $dirty = 0 ];then
      FLAG=0
      while [[ $FLAG = 0 ]];do
        COUNT=`ps aux | grep $COMMAND | wc -l`
        echo "while: COUNT: $COUNT MAX: $MAX" >> $logfile
        if [[ $COUNT -le $MAX ]];then
          echo "patch: in function with spacecmd system_upgradepackage $object $i" >> $logfile
          exec spacecmd -s $server -u $user -p $passwd -y system_upgradepackage $type$object $i &
	  FLAG=1
	else
      	  echo "Spacewalk connections at $COUNT sleeping 15 seconds" >> $logfile
          sleep 15
        fi
      done
    fi
  done
  echo "entering applyErrata with: $object and $type" >> $logfile
#  applyErrata $object $type
} #function

echo "Start time: `date`" >> $logfile
getGroups
getIgnore
if [ $parseEachSvr = 0 ]; then
  for i in "${patchGroups[@]}"; do
  serverGroup=$i
    if [[ "$serverGroup" =~ ^PB ]] && [[ "$serverGroup" = "PB-IGNORE" ]];then
      echo "parsing loop with: $serverGroup" >> $logfile
      getExceptions $serverGroup
      getPackages $serverGroup
      patch $serverGroup "group"
      #spacecmd -s $server -u $user -p $passwd -y system_reboot group:$serverGroup
    else
      echo "$i group is not covered by this patching script" >> $logfile
    fi
  done
else
  parseEachServer
fi
$execdir/patching-notification.sh $date $serverGroup POST
echo "End time: `date`" >> $logfile

