#!/bin/bash
# set -x
###############################################################################################
# 		NAME: 			copyLogs.sh
#
# 		DESCRIPTION:		Copy Logs to share point 
#		SYNOPSIS:		sudo copyLogs.sh -h
###############################################################################################
#		HISTORY:
#						- created by Zack Smith (zsmith@318.com) 	09/28/2010
###############################################################################################


declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"
exec 2>>"$LogFile"

showUsage(){
	printf "%s\n\t" "USAGE:"
	printf "%s\n\t" 
#	printf "%s\n\t" " OUTPUT:"
#	printf "%s\n\t" " -v | # Turn on verbose output"
#	printf "\033[%s;%s;%sm%s\033[0m\n\t" "1" "44" "37" " -C | # Turn on colorized output"
#	printf "\033[0m"
	printf "%s\n\t" " OTHER TASKS:"
	printf "%s\n\t" " -h | # Print this usage message and quit"
	printf "%s\n\t"
	printf "%s\n\t" " EXAMPLE SYNTAX:"
	printf "%s\n\t" " sudo $0 -n zacharrs -u BindAcct -p BindPass"
	printf "%s\n"
	return 0
}

[ $# = 0 ] &&
	FatalError "No arguments Given, but required for $ScriptName.sh"
	

[ "$EUID" != 0 ] && 
	printf "%s\n" "This script requires root access!" && exit 1

StatusMSG "$ScriptName"  "Processing script with $# arguments"
while getopts l:o:n:u:p:U:h SWITCH ; do
	case $SWITCH in
		o ) export OldPass="${OPTARG}" ;;
		l ) export OldUser="${OPTARG}" ;;
		u ) export UnixId="${OPTARG}" ;;
		p ) export NewPass="${OPTARG}" ;;
		h ) showUsage
			exit 1;;
	esac
done # END while


# Do not move this to the .conf file, order will be wrong
# Share is mounted as the  Bind user

# Commands used by this script
declare -x mount_afp="/sbin/mount_afp"
declare -x date="/bin/date"
declare -x defaults="/usr/bin/defaults"
declare -x rmdir="/bin/rmdir"
declare -x mkdir="/bin/mkdir"
declare -x mv="/bin/mv"
declare -x rm="/bin/rm"
declare -x cp="/bin/cp"
declare -x ping="/sbin/ping"
declare -x system_profiler="/usr/sbin/system_profiler"
declare -x scutil="/usr/sbin/scutil"
declare -x umount="/sbin/umount"
# Generate the computer name
export ComputerName="${UnixId:?}-${LastSixSN:?}"

begin
setInstallPercentage 10.00
StatusMSG $ScriptName "Copying logs..." uiphase
StatusMSG $ScriptName "Assembled ComputerName: $ComputerName"
StatusMSG $ScriptName "Assembled Name: $ComputerName" uistatus 0.5
if [ -d "$LocalMount" ] ; then
	# Clean Up any .DS_Store files auto created
	$rm "$LocalMount"/.DS_Store 2>/dev/null
	# Remove any empty Directory (stale)
	$rmdir "$LocalMount" 2>/dev/null
	[ -d "$LocalMount" ] && 
		$mv "$LocalMount" "$LocalMount_$$$RANDOM"
fi
StatusMSG $ScriptName "Connecting to $ShareServer"
# Create the local directory if it does not exist
if [ ! -d "$LocalMount" ] ; then
	$mkdir "$LocalMount" ||
		echo "Unable to make directory..."
else
	echo "Notice: The share is already mounted"
fi
if $ping -c 1 $ShareServer ; then
	$mount_afp -o nobrowse "afp://$ShareUser:$SharePass@$ShareServer/$SharePoint" "$LocalMount" ||
		StatusMSG $ScriptName "Mounting the smb share may have failed"
else
	StatusMSG $ScriptName "$ShareServer is not accessible"
fi
setInstallPercentage 50.00

if [ -d "$LocalMount" ] ; then
	if [ -f "${LogFile:?}" ] ; then
		StatusMSG $FUNCNAME "Found Log File $LogFile"
		
		if [ ! -d "$LocalMount/$ComputerName" ] ; then
			StatusMSG $FUNCNAME "Attempting to create directory structure on share"
			$mkdir "$LocalMount/$SubFolder/$ComputerName" # NO -p here
		fi
		declare -x ComputerNameReal="$($scutil --get ComputerName)"	
		declare -x CopyLogFileNameBase="$(basename $LogFile)"
		declare -x CopyLogFileName="${CopyLogFileNameBase%%.log}-$($date "+%Y-%m-%d_%H_%M_%S").log"
		
		StatusMSG $FUNCNAME "Assembled filename: $CopyLogFileName"
		$cp -p "$LogFile" "$LocalMount/$SubFolder/$ComputerName/$CopyLogFileName" ||
				StatusMSG $FUNCNAME "Copy of LogFile may have failed to :$LocalMount/$ComputerName/$CopyLogFileName"
		StatusMSG $FUNCNAME "Copy of log file to  :$LocalMount/$SubFolder/$ComputerName/$CopyLogFileName complete"
		
		StatusMSG $ScriptName "Generating System Profile..." uistatus 1
		$system_profiler -xml >"$LocalMount/$SubFolder/$ComputerName/$ComputerNameReal.spx"

	else
		StatusMSG $FUNCNAME "Notice , no LogFile Found"
	fi 
fi
setInstallPercentage 90.00
$umount "$LocalMount"
die 0
