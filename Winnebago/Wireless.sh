#!/bin/bash
# set -x	# DEBUG. Display commands and their arguments as they are executed
# set -v	# VERBOSE. Display shell input lines as they are read.
# set -n	# EVALUATE. Check syntax of the script but dont execute
export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/lib:/usr/local/include:/usr/bin:/bin:/usr/sbin:/sbin"

# ZS Updated to use Python Script

declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"

exec 2>>"$LogFile"

[ $# = 0 ] &&
	FatalError "No arguments Given, but required for $ScriptName"
	
StatusMSG $ScriptName "Processing options $@"
StatusMSG $ScriptName "Running as LOGNAME=$LOGNAME"
StatusMSG $ScriptName "Running as USER=$USER"

# Quickly define proper usage of this script
usage="Wireless.sh -u UNIXusername -p UNIXpassword"

# Parse the input options...
while getopts "u:p:o: h" CredInputs; do
	case $CredInputs in
		u ) UNIXuser="$OPTARG" ;;
		p ) UNIXpass="$OPTARG" ;;
		o ) NotUsed="$OPTARG" ;;
		h ) echo $usage
			exit 1;;
		* ) usage
			exit 1;;			
	esac
done

StatusMSG $ScriptName "Was passed Username: $UNIXuser"
#StatusMSG $ScriptName "Was passed Password: $UNIXpass"

declare -x wifiutil="$RunDirectory/wifiutil.py"
"$wifiutil" --plist="$RunDirectory/wifiutil.settings.plist" --username="$UNIXuser" --password="$UNIXpass"
