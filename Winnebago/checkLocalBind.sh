#!/bin/bash
# set -x
###############################################################################################
# 		NAME: 			checkKeychain
#
# 		DESCRIPTION:  	Checks to see if we need to update the keychain.     
#		SYNOPSIS:		sudo adJoin.sh
###############################################################################################
#		HISTORY:
#						- modified by Zack Smith (zsmith@318.com)    11/15/2011
#						- modified by Zack Smith (zsmith@318.com)   11/17/2011
###############################################################################################

declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"
exec 2>>"$LogFile"

declare -x awk="/usr/bin/awk"
declare -x dscl="/usr/bin/dscl"
declare -x who="/usr/bin/who"

# Check script options
StatusMSG "$ScriptName" "Processing script $# options:$@"
while getopts u:p: SWITCH ; do
	case $SWITCH in
		u ) export UserName="${OPTARG}" ;;
		p ) export PassWord="${OPTARG}" ;;		
	esac
done # END while

export ConsoleUser="$($who |
						$awk '/console/{print $1}')"
begin
						
if [ "$ConsoleUser" = "$UserName" ] ; then
	StatusMSG "${ScriptName:="$0"}" "Usernames match"
fi

$dscl . -authonly "$ConsoleUser" "$PassWord"