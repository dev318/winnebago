#!/bin/bash
# set -x
###############################################################################################
# 		NAME: 			migrateAccount.sh
#
# 		DESCRIPTION:  	This script adds users to privileged users list on machine and migrates 
#               		the local user account to use AD for authentication
#               
#		USAGE:			./migrateAccount.sh <adaccount> <localaccount>
###############################################################################################
#		HISTORY:
#						- created by Zack Smith (zsmith@318.com) 	02/03/2011
###############################################################################################
# Standard Script Common
declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"
exec 2>>"$LogFile"


# Sanity Checks

[ $# = 0 ] &&
	FatalError "No arguments Given, but required for $ScriptName"

[ "$EUID" != 0 ] && 
	printf "%s\n" "This script requires root access!" && exit 1

# Positional parameters passed to the script

showUsage(){
	printf "%s\n\t" "USAGE:"
	printf "%s\n\t" 
#	printf "%s\n\t" " OUTPUT:"
#	printf "%s\n\t" " -v | # Turn on verbose output"
#	printf "\033[%s;%s;%sm%s\033[0m\n\t" "1" "44" "37" " -C | # Turn on colorized output"
#	printf "\033[0m"
	printf "%s\n\t" " -n | # The  Network ID"
	printf "%s\n\t" " -u | # The  Bind Account"

	printf "%s\n\t" " -p | # The  Bind Password"
#	printf "%s\n\t" " -D | # Turn on debug (all function's name will be displayed at runtime)."
	printf "%s\n\t" " -U | # The  ZPA Account"
	printf "%s\n\t" " -P | # The  ZPA Password"

	printf "%s\n\t" " OTHER TASKS:"
	printf "%s\n\t" " -h | # Print this usage message and quit"
	printf "%s\n\t"
	printf "%s\n\t" " EXAMPLE SYNTAX:"
	printf "%s\n\t" " sudo $0 -n zacharrs -u BindAcct -p BindPass"
	printf "%s\n"
	return 0
}

# Parse the input options...
while getopts "u:p:o:l: h" CredInputs; do
	case $CredInputs in
		u ) export ADUser="$OPTARG" ;;
		l ) export LocalUser="$OPTARG" ;;
		p ) export NewPass="$OPTARG" ;;
		o ) export OldPass="$OPTARG" ;;
		h ) showUsage
			exit 1;;		
	esac
done

# Catch missing paramter
export LocalUser=${LocalUser:=$ADUser}

# Commands used by this script
declare -x awk="/usr/bin/awk"
declare -x cp="/bin/cp"
declare -x dscl="/usr/bin/dscl"
declare -x dscacheutil="/usr/bin/dscacheutil"
declare -x dsexport="/usr/bin/dsexport"
declare -x sudo="/usr/bin/sudo"
declare -x atsutil="/usr/bin/atsutil"
declare -x groups="/usr/bin/groups"
declare -x id="/usr/bin/id"

# Migrate local user account to use AD for authentication
ModifyLocalUser(){
	setInstallPercentage $CurrentPercentage.10
	# Get the local user's GUID
	[ ${#LocalUser} -eq 0 ] &&
		FatalError "Missing parameter LocalUser=($LocalUser)"

	export UserGUID=$($dscl . -read "/Users/$LocalUser" GeneratedUID |
									$awk '{print $NF;exit}')
						
	export ShadowHash="/var/db/shadow/hash/$UserGUID"
	export ShadowHashBackup="/Library/Caches/$LocalUser.hash"
	setInstallPercentage $CurrentPercentage.30
	
	# Store the GUID in a txt file just in case
	# /Library/Genentech/Centrify/$LocalUser.hash.guid
	printf "%s" "$UserGUID" > "$ShadowHashBackup.guid"

	if [ -f "$ShadowHash" ]; then
		$cp -p "$ShadowHash" "$ShadowHashBackup"
		StatusMSG $FUNCNAME "SUCCESS - backed up password for $LocalUser"
	else
		#ZS:10.7 Added condtional check for Lion
		if [ "$OsVersion" -le 6 ] ; then
			StatusMSG $FUNCNAME "FAILED - backup password for $LocalUser missing ($ShadowHash)"
			exit 1
		else
			StatusMSG $FUNCNAME "LION: - hash file will be backed up in user plist"
		fi
	fi
	setInstallPercentage $CurrentPercentage.40
	#ZS:10.7 Added condtional check for Lion
	if [ ! -f  "$ShadowHashBackup" ] && [ "$OsVersion" -le 6 ] ; then
		FatalError "User password was unable to be backed up to:$ShadowHashBackup"
	fi
	setInstallPercentage $CurrentPercentage.50
	# Export local user account to /Library/Caches/
	export DSImport="/Library/Caches/$LocalUser.dsimport"
	export DSPlist="/Library/Caches/$LocalUser.plist"
	#ZS:10.7 Added --N
	$dsexport --N "$DSImport" /Local/Default dsRecTypeStandard:Users -r "$LocalUser" ||
		StatusMSG $FUNCNAME "Command dsexport did not complete sucessfully"
	
	#ZS:10.7 Added support for backing up user plist
	export UserPlist="/var/db/dslocal/nodes/Default/users/$LocalUser.plist"
	
	StatusMSG $FUNCNAME "Copying the user plist: $UserPlist"
	if [ -f "$UserPlist" ] ; then
		$cp "$UserPlist" "$DSPlist" ||
			StatusMSG $FUNCNAME "Copying the user plist: $UserPlist may have failed"	
	fi
	#ZS:10.7 Made condtional on both tests failing, though both should succeed
	if [ ! -f  "$DSImport" ] && [ ! -f "$DSPlist" ]; then
		FatalError "User account was unable to be backed up to: ( $DSImport ) or ( $DSPlist ) "
	fi
	
	# Delete local user account
	setInstallPercentage $CurrentPercentage.80
	# Added for file Vault access
	StatusMSG $ScriptName "Checking for File Vault" uistatus 0.5
	$dscl . -read "/Users/$LocalUser" HomeDirectory |
		$awk '/HomeDirectory/{print $2;exit}' >"/Library/Caches/$LocalUser.HomeDirectory"
		
	# Back the users uid for the File System Permissions fix
	$dscl . -read "/Users/$LocalUser" UniqueID |
		$awk '/UniqueID/{print $2;exit}' >"/Library/Caches/$LocalUser.UniqueID"	
	StatusMSG $ScriptName "Saving" uistatus 0.5
	# Added to preserve admin access
	
	#https://github.com/acidprime/NikeADUtility/issues/11
	#for GROUP in $($groups "$LocalUser") ; do
    #    if [ "$GROUP" = "admin" ] ; then
                printf "$ADUser" >"/Library/Caches/$LocalUser.admin"
    #    fi
	#done
	$dscl . -delete /Users/$LocalUser ||
		StatusMSG $FUNCNAME "Failed to Delete local user:$LocalUser"
	$dscacheutil -flushcache

	StatusMSG $FUNCNAME "SUCCESS - deleted user local user $LocalUser"
	setInstallPercentage $CurrentPercentage.99
} # END ModifyLocalUser()

# If shortname is different from userid - migrate home directory to match userid and update group id and ownership
begin
StatusMSG $ScriptName "Migrating Account..." uiphase

# Remove from local ( if there )
StatusMSG $ScriptName "Updating configuration files" uistatus
setInstallPercentage 10.00
ModifyLocalUser
setInstallPercentage 99.00
die 0
