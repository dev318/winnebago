#!/bin/bash
# set -x
###############################################################################################
# 		NAME: 			createMacTempUser.sh
#
# 		DESCRIPTION:  	This script creates the Mac Auth Temp User
#               
#		USAGE:			migrateAccount.sh <network> <local>
###############################################################################################
#		HISTORY:
#						- created by Zack Smith (zsmith@318.com) 	09/28/2010
###############################################################################################
declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

# Check for a conf file in the same directory
if [ -f "$RunDirectory/.winnebago.conf" ] ; then
	source "$RunDirectory/.winnebago.conf"
else
	printf "%s\n" "Configuration file required for this script is missing !($RunDirectory/.MacMigrator.conf)"
	exit 1
fi
source "$RunDirectory/common.sh"
exec 2>>"$LogFile"

[ "$EUID" != 0 ] && 
	printf "%s\n" "This script requires root access!" && exit 1

[ $# = 0 ] &&
	FatalError "No arguments Given, but required for $ScriptName.sh"


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
		o ) export LocalPassword="${OPTARG}" ;;
		l ) export LocalUser="${OPTARG}" ;;
		u ) export UnixId="${OPTARG}" ;;
		p ) export NewPass="${OPTARG}" ;;
		h ) showUsage
			exit 1;;
	esac
done # END while


# GUID Code and rem others
declare -x awk="/usr/bin/awk"
declare -x cp="/bin/cp"
declare -x chown="/usr/sbin/chown"
declare -x dscl="/usr/bin/dscl"
declare -x defaults="/usr/bin/defaults"
declare -x uuidgen="/usr/bin/uuidgen"
declare -x id="/usr/bin/id"
declare -x mkdir="/bin/mkdir"

CreateTempUser(){
	setInstallPercentage 10.00
	# Rename HD to Macintosh HD for later adfixid tasks
	diskutil rename / Macintosh\ HD &&
		StatusMSG $FUNCNAME "Renamed HD to Macintosh HD."
	
	StatusMSG $FUNCNAME "Backing up local password."
	# Get the local user's GUID
	UserGUID="$($dscl . -read "/Users/$LocalUser" GeneratedUID | $awk '{print $NF}')"
	if [ ${#UserGUID} -eq 0 ] ; then
		StatusMSG $FUNCNAME "Unable to lookup GeneratedUID trying /Search path"
		UserGUID="$($dscl /Search -read "/Users/$LocalUser" GeneratedUID | $awk '{print $NF}')"
		[ ${#UserGUID} -eq 0 ] && FatalError "Unable to lookup User GUID for $LocalUser"
	fi
	
	# Generate a new GUID as to not conflict with the old user
	export NewUserGUID="`$uuidgen`"
	# ABOVE: This really does not do much but can be left in the script
	StatusMSG $FUNCNAME "Hiding users under 500 from the login window"
	$defaults write /Library/Preferences/com.apple.loginwindow Hide500Users - bool 
	# Create new hidden backup user
	if ! $id $TMP_USER 2>/dev/null ; then
		$dscl . -create /Users/$TMP_USER
		$dscl . -create /Users/$TMP_USER RealName "$Project"
		$dscl . -create /Users/$TMP_USER UniqueID 498 
		$dscl . -create /Users/$TMP_USER NFSHomeDirectory /Users/$TMP_USER
		$dscl . -create /Users/$TMP_USER PrimaryGroupID 80
		$dscl . -create /Users/$TMP_USER GeneratedUID $NewUserGUID
		$dscl . -passwd /Users/$TMP_USER "$LocalPassword"
		$dscl . -merge /Groups/admin GroupMembership $TMP_USER
		FlushCache
	else
		StatusMSG $FUNCNAME "$TMP_USER user already exists"
		$dscl . -create /Users/$TMP_USER GeneratedUID $NewUserGUID ||
			FatalError "FAILED to set GeneratedUID for $TMP_USER"
		StatusMSG $FUNCNAME "SUCCEEDED to backup password to $TMP_USER"
	fi
	setInstallPercentage 50.00

	# ZS
	StatusMSG $FUNCNAME "Adding self destructing LaunchAgent to remove: $TMP_USER"
	if [ -f "$RunDirectory/$Identifier.remove.$TMP_USER.plist" ] ; then
		$cp -f "$RunDirectory/$Identifier.remove.$TMP_USER.plist" "/Library/LaunchAgents/$Identifier.remove.$TMP_USER.plist"
		$chown 0:0 "/Library/LaunchAgents/$Identifier.remove.$TMP_USER.plist"
		$chmod 700 "/Library/LaunchAgents/$Identifier.remove.$TMP_USER.plist"
	else
		StatusMSG $FUNCNAME "LaunchD item is missing at path: $RunDirectory/$Identifier.remove.$TMP_USER.plist"
	fi 

	if [ "$OsVersion" -le 6 ] ; then
		$cp -vp "/var/db/shadow/hash/$UserGUID" "/var/db/shadow/hash/$NewUserGUID" ||
                        FatalError "FAILED to copy $LocalUser's password to $TMP_USER"	
	else
		StatusMSG $FUNCNAME "Processing shadow hash plist transplant for lion user"
                declare -x SHADOW_HASH="$($defaults read  "/var/db/dslocal/nodes/Default/users/$LocalUser" ShadowHashData)"
		$defaults write /var/db/dslocal/nodes/Default/users/$TMP_USER ShadowHashData "$SHADOW_HASH"	
	fi
	# BELOW: This command is the exit value for this function
	$id "$TMP_USER"
	setInstallPercentage 90.00
 
}



# If shortname is different from userid - migrate home directory to match userid and update group id and ownership

begin
CreateTempUser
die 0
