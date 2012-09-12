#!/bin/bash
# set -x
###############################################################################################
###############################################################################################
#		HISTORY:
#						- modified by Zack Smith (zsmith@318.com)    4/20/2012
###############################################################################################

declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"
exec 2>>"$LogFile"

declare -rx awk="/usr/bin/awk"
declare -rx pmset="/usr/bin/pmset"
declare -rx grep="/usr/bin/grep"

# Made this lowercase for 10.7 Compatibility
declare -ix CHECK_AC_POWER="$($pmset -g batt | $grep -c 'AC Power')"

begin
if [ $CHECK_AC_POWER -ge 1 ] ; then
	StatusMSG "$ScriptName" "Checking AC Power..." uiphase
else
	FatalError "Machine is running on battery power $ScriptName"
fi

die 0