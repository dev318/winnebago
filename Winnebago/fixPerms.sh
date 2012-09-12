#!/bin/bash
# set -x
###############################################################################################
# 		NAME: 			fixPerms
# 		DESCRIPTION:  	This script attempts fix user permissions on the machine
#					
#               
#		USAGE:			fixPerms.sh <olduser> <new user> <old user UID>
###############################################################################################
#		HISTORY:
#						- created by Zack Smith (zsmith@318.com) 	10/28/2010
#						- modified by Zack Smith (zsmith@318.com)	12/07/2010
###############################################################################################

declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

declare -x cat="/bin/cat"
declare -x id="/usr/bin/id"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"

exec 2>>"$LogFile"

[ $# = 0 ] &&
	FatalError "No arguments Given, but required for $ScriptName.sh"
	

[ "$EUID" != 0 ] && 
	printf "%s\n" "This script requires root access!" && exit 1

StatusMSG "$ScriptName"  "Processing script with $# arguments"
while getopts l:o:n:u:p:U:h SWITCH ; do
	case $SWITCH in
		o ) export OldPass="${OPTARG}" ;;
		l ) export LocalUser="${OPTARG}" ;;
		u ) export UserNameFix="${OPTARG}" ;;
		p ) export NewPass="${OPTARG}" ;;
		h ) showUsage
			exit 1;;
	esac
done # END while

declare -xr BREAD_CRUM="/Library/Caches/$LocalUser.UniqueID"

if [ -f "${BREAD_CRUM:?}" ] ; then
  export OldUIDFix="$($cat "$BREAD_CRUM")"
else
	FatalError "Missing file BREAD_CRUM: $BREAD_CRUM : $ScriptName"
fi
begin
# No Progress Bars here as the functions do most of that work
StatusMSG $ScriptName "Updating Permissions..." uiphase

FileOwnershipUpdate "$LocalUser" "$UserNameFix" "$OldUIDFix"

# Run the find command to search for all files on the HD owned by the old UID
FixHDOwnership "$LocalUser" "$UserNameFix" "$OldUIDFix" &&
die 0
