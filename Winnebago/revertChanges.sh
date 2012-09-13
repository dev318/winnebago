#!/bin/bash
# set -xv
###############################################################################################
# 		NAME: 			migrateAccount.sh
#
# 		DESCRIPTION:  	This script reverts back to old local user account if there 
#						was a critical error during the migration or AD join
#               
###############################################################################################
#		HISTORY:
#						- modified by Zack Smith (zsmith@318.com)	11/9/2010
#							- Updated sed quote marks , made double rather then single (var exp)
###############################################################################################
declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

declare -x dsconfigad="/usr/sbin/dsconfigad"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"
exec 2>> "$LogFile"

[ "$EUID" != 0 ] && 
	printf "%s\n" "This script requires root access!" && exit 1


showUsage(){
	printf "%s\n" "USAGE:"
	printf "%s\n" 
	printf "%s\n" " OUTPUT:"
	printf "\t%s\n" " -v | # Turn on verbose output"
	printf "\t\033[%s;%s;%sm%s\033[0m\n" "1" "44" "37" " -c | # Turn on colorized output"
	printf "\033[0m"
	#	printf "%s\n\t" " -D | # Turn on debug (all function's name will be displayed at runtime)."
	printf "%s\n"
	printf "\t%s\n" " MAIN:"
	printf "\t%s\n" " -n <unixid>| # The Yelp UnixID"
	printf "\t%s\n" " -N <unixpass| # The Yelp Password"
	printf "\t%s\n"
	printf "\t%s\n" " -l | # The local account"
	printf "\t%s\n" " -L | # The local Password"
	printf "%s\n"
	printf "\t%s\n" " -u | # The Centrify Bind Account"

	printf "\t%s\n" " -p | # The Centrify Bind Password"

	printf "%s\n" " OTHER TASKS:"
	printf "\t%s\n" " -h | # Print this usage message and quit"
	printf "\t%s\n"
	printf "%s\n" " EXAMPLE SYNTAX:"
	printf "\t%s\n" " sudo $0 -n zacharrs -N 'myN3tPass' -l zack -L myL0calpass # When performing offline"
	printf "\t%s\n" " sudo $0 -n zacharrs -N 'myN3tPass' -l zack -L myL0calpass -u CentrifyBindAcct -p CentrifyBindPass -U CentrifyZPAAcct -P CentrifyZPAPass"
	printf "\t%s\n" " -u,-U/,-p/,-P should be specified but may containt invalid data if forced binding is required"
	printf "%s\n"
	return 0
}

# Sanity Checks
if [ $# = 0 ] ; then
	showUsage
	FatalError "No arguments Given, but required for $ScriptName"
fi


[ "$EUID" != 0 ] && 
	printf "%s\n" "This script requires root access!" && exit 1
	
# Check script options
StatusMSG "$ScriptName"  "Processing script with $# arguments"
while getopts cn:N:u:p:U:P:l:L:h SWITCH ; do
	case $SWITCH in
		c ) export EnableColor="YES" ;;
		n ) export UnixId="${OPTARG}" ;;
		N ) export UnixPassword="${OPTARG}" ;;
		l ) export LocalUser="${OPTARG}" ;;
		L ) export LocalPassword="${OPTARG}" ;;
		u ) export BindAcct="${OPTARG}" ;;
		p ) export BindPass="${OPTARG}" ;;
		h ) showUsage && exit 1 ;;
		* ) showUsage && exit 1 ;;
	esac
done # END while

# Commands used by this script
declare -x awk="/usr/bin/awk"
declare -x cat="/bin/cat"
declare -x dsconfigad="/usr/sbin/dsconfigad"
declare -x cp="/bin/cp"
declare -x dscl="/usr/bin/dscl"
declare -x dsimport="/usr/bin/dsimport"
declare -x id="/usr/bin/id"
declare -x killall="/usr/bin/killall"
declare -x rm="/bin/rm"

# Functions used by this script
# FlushCache

###############################################################################################

LeaveDomainForce(){
	StatusMSG $FUNCNAME "Leaving AD Domain by force..."
	$rm -r /Library/Preferences/DirectoryService/*
	$rm -r /Library/Preferences/OpenDirectory/*
	$killall DirectoryService
	$killall opendirectoryd
	# Added to rebind to Open Directory, redirect for log duplication issues
	"$RunDirectory/dsconfig.sh" -O NO -a NO

}

# Removes computer from the domain 
LeaveDomain(){
	StatusMSG $FUNCNAME "Leaving AD Domain..."
	LeaveDomainForce	
}


# Migrates local user account to use AD for authentication
ImportLocalUser() {
	StatusMSG $FUNCNAME "Archiving previous users UniqueID"

	$dscl . -read "/Users/$LocalUser" UniqueID |
		$awk '/UniqueID/{print $2;exit}' >"/Library/Caches/$LocalUser.UniqueID"	

	StatusMSG $FUNCNAME "Removing Active Directory Account"
	$dscl . -delete "/Users/${UnixId:?}" ||
		StatusMSG $FUNCNAME "FAILED - Deletion of AD account /Users/$UnixId failed, may not have been created"
	
	StatusMSG $FUNCNAME "Reimporting old user accounts"
	if [ "$OsVersion" == "6" ]; then
		$dsimport /Library/Caches/$LocalUser.dsimport  /Local/Default O  >> "$LogFile" &&
			StatusMSG $FUNCNAME "SUCCESS - Command to import local user: $LocalUser completed"
	elif [ "$OsVersion" == "5" ];then
		$dsimport -g "/Library/Caches/$LocalUser.dsimport"  /Local/Default O -u "$TMP_USER" -p "$LocalPassword" >> "$LogFile" &&
			StatusMSG $FUNCNAME "SUCCESS - Command to import local user: $LocalUser completed"
	fi

	declare GeneratedUID="$($dscl . -read "/Users/$UnixId" GeneratedUID |
								$awk '{print $NF;exit}')"
	
	if [ "${#GeneratedUID}" -eq 0 ] ; then
		StatusMSG $FUNCNAME "GUID in /Local/Default Directory Node was empty!"
		StatusMSG $FUNCNAME "Reverting to Backup guid stored with hash files"
		BackupGUIDFile="/Library/Caches/$LocalUser.hash.guid"
		if [ -f "$BackupGUIDFile" ] ; then
			declare GeneratedUID="$($cat "$BackupGUIDFile")"
		else
		  "$RunDirectory/sendEmail.sh" -u "$UnixId" -p "$UnixPassword" -l "$LocalUser" -o "$LocalPassword" -c
		  FatalError "Unable to resolve GUID file to users password file!"
		fi
	fi 
	
	if [ "$OsVersion" -le "6" ]; then
	        StatusMSG $FUNCNAME "Restoring user's password file"
		$cp -vp "/Library/Caches/$LocalUser.hash" "/var/db/shadow/hash/$GeneratedUID"  >> "$LogFile"
	else
	        StatusMSG $FUNCNAME "Restoring user's plist file"
		export DSPlist="/Library/Caches/$LocalUser.plist"
	        export UserPlist="/var/db/dslocal/nodes/Default/users/$LocalUser.plist"
		$cp -f "$DSPlist" "$UserPlist"
		 StatusMSG $FUNCNAME "Restarting opendirectoryd..."
		$killall opendirectoryd 				
	fi	
	StatusMSG $FUNCNAME "Flushing Directory Service Cache"
	
	FlushCache
	$id $LocalUser
}

# Deletes the temporary backup account
DeleteTmpUser(){
	StatusMSG $FUNCNAME "Deleting Password Backup User"
	$dscl . -delete /Users/$TMP_USER ||
			StatusMSG $FUNCNAME "Command Failed to delete $TMP_USER user"
	
}

RemoveReceipt() {
	if [ -w "$ReceiptFile" ] ; then
		$rm "$ReceiptFile"
	else
		StatusMSG $FUNCNAME "No Receipt File Found (or not writable): $ReceiptFile"
	fi
}

begin
StatusMSG "$ScriptName" "Reverting Changes..." uiphase

setInstallPercentage 10.00

StatusMSG "$ScriptName" "Leaving Active Directory" uistatus
LeaveDomain

StatusMSG "$ScriptName" "Restoring  $LocalUser from backup" uistatus

if  ImportLocalUser ; then
 StatusMSG "$ScriptName" "Imported Previous User" uistatus
else
  "$RunDirectory/sendEmail.sh" -u "$UnixId" -p "$UnixPassword" -l "$LocalUser" -o "$LocalPassword" -c
  FatalError "FAILED - importing original (local) user $LocalUser"
fi
DeleteTmpUser
setInstallPercentage 50.00

StatusMSG $ScriptName "Cleaning up symlinks"
$rm "/Users/$UnixId" 2>/dev/null
$rm "/Users/$LocalUser" 2>/dev/null

# Attempt to revert password back
#StatusMSG $ScriptName "Fix permissions appears to have run, reverting changes"
StatusMSG $ScriptName "Fix permissions appears to have run, reverting changes"

#"$changeKeychainPass" "$LocalUser" "${UnixPassword:="$LocalPassword"}" "$Password" "$LocalUser"


RemoveReceipt

FileOwnershipUpdate "${UnixId:?}" "${LocalUser:?}" "$($id -u "$UnixId")"
# This file is created in fixPerms.sh, will always run on multi-user installs
if [ -f /Library/Caches/.fixperms ] ; then
	StatusMSG $ScriptName "Fix permissions appears to have run, reverting changes"
	FixHDOwnership "$UnixId" "$LocalUser" "$($id -u "$UnixId")"
fi

setInstallPercentage 80.00

# logOutUser

# Our exit status is the account working , DO NOT Add anything below this line
#ZS:10.7 Added condtional statement
if [ "$OsVersion" -le 6 ] ; then
	$killall DirectoryService
else
	$killall opendirectoryd
fi
until $id "$LocalUser" ; do
	let TRY++
	StatusMSG "$ScriptName" "Waiting for DirectoryService to resolve ($LocalUser)"
	# Do not remove the line below, or replace with a sleep 1 
	StatusMSG "$ScriptName" "Waiting for DirectoryService" uistatus 1
	if [ "$TRY" -gt 60 ] ; then
		StatusMSG "$ScriptName" "Timed out waiting for user resolution ($LocalUser)"
		break
	fi
done
unset TRY
until $dscl /Search authonly "$LocalUser" "$LocalPassword" ; do
	let TRY++
	StatusMSG "$ScriptName" "Waiting for DirectoryService to authenticate($LocalUser)"
	# Do not remove the line below, or replace with a sleep 1 
	StatusMSG "$ScriptName" "Attempting to validate Authentication" uistatus 1
	if [ "$TRY" -gt 60 ] ; then
		StatusMSG $ScriptName "Timed out waiting for user authenticate($LocalUser)"
		die 1
	fi
done
# Adding for keychain revert if we have got that far.
"$RunDirectory/changeKeychainPass.sh" -l "$UnixId" -u "$LocalUser" -p "$LocalPassword" -o "$UnixPassword"
declare -rx Subject="REVERT"
declare -rx ErrorCode="User reverted due to warning"
"$RunDirectory/sendEmail.sh" -u "$UnixId" -p "$UnixPassword" -l "$LocalUser" -o "$LocalPassword" -r
setInstallPercentage 90.00
unset LocalPassword
die 0
