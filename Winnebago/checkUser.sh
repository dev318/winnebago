#!/bin/bash
# set -x
###############################################################################################
# 		NAME: 			checkUser
# 		DESCRIPTION:  	This script checks if a current user is a AD User
#               
# 		LOCATION: 		/Applications/Utities/PasswordUtility.app/Contents/Resources/
#		USAGE:			checkUser
###############################################################################################
#		HISTORY:
#						- modified by Zack Smith (zsmith@318.com)	11/27/2011
###############################################################################################
declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"
exec 2>>"$LogFile"

# Parse the input options...

# Commands Required by this Script
declare -x awk="/usr/bin/awk"
declare -x dscl="/usr/bin/dscl"
declare -x id="/usr/bin/id"
declare -x who="/usr/bin/who"

begin

export UserName="$($who |
						$awk '/console/{print $1;exit}')"
						
						
if $id ${UserName:?} &>/dev/null ; then
    declare -xi IsLocalUser="$($dscl . -search /Users RecordName "$UserName" 2>/dev/null|
                                $awk '{seen++}END{print seen}')"
	printf "%s" "<result>$UserName</result>"
	die 0
fi
