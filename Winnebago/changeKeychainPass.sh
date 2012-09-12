#!/bin/bash
# set -x
# ABOVE: Uncomment to turn on debug
export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/lib:/usr/local/include:/usr/bin:/bin:/usr/sbin:/sbin"
###############################################################################################
# 		NAME: 			changeKeychainPassword.sh
#
# 		DESCRIPTION:  	This script attempts to update the KeyChain password for the user to  
#               		match their winnebago password; If unsuccessful - it moves the
#						login keychain to ~/Library/Caches/username.login.keychain.backup
#               
#		USAGE:			changeKeychainPassword.sh <username> <old password> <new password>
###############################################################################################
#		HISTORY:
#						- created by Zack Smith (zsmith@318.com) 	09/28/2010
###############################################################################################

declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"
exec 2>>"$LogFile"

[ $# = 0 ] &&
	FatalError "No arguments Given, but required for $ScriptName"

[ "$EUID" != 0 ] && 
	printf "%s\n" "This script requires root access!" && exit 1
	
# Quickly define proper usage of this script
usage="$0 -u Username -p NewPass -o OldPass"

# Parse the input options...
while getopts "u:p:o:l: h" CredInputs; do
	case $CredInputs in
		l ) Username="$OPTARG" ;;
		u ) NewUserName="$OPTARG" ;;
		p ) NewPass="$OPTARG" ;;
		o ) OldPass="$OPTARG" ;;
		h ) echo $usage
			exit 1;;			
	esac
done
if [ "${#NewUserName}" -eq 0 ]; then
	export NewUserName="$Username"
fi

setInstallPercentage 0.00	
begin
StatusMSG $ScriptName "Updating your Keychain password..." uiphase
setInstallPercentage 10.00		

# Commands used by this script
declare -x mv="/bin/mv"
declare -x chown="/usr/sbin/chown"
declare -x security="/usr/bin/security"
declare -x LoginKeychain="/Users/$Username/Library/Keychains/login.keychain"

if [ ! -e "$LoginKeychain" ]; then
	StatusMSG $FUNCNAME "Keychain $LoginKeychain does not exist - Skipping"
	setInstallPercentage 30.00
	StatusMSG $ScriptName "Login Keychain NOT FOUND; Skipping." uistatus
else
	setInstallPercentage 40.00
	StatusMSG $ScriptName "Login Keychain FOUND" uistatus		
	StatusMSG $FUNCNAME "Attempting to update login.keychain password to match the users $Company password"
	StatusMSG $ScriptName "Updating login Keychain to match new $Company password" uistatus
	# ZS Add check for Passwords being the same on the system
	if [ "$OldPass" = "$NewPass" ] ; then
		StatusMSG $ScriptName "Old and new passwords match, no action necessary"
	else
		if $security 'set-keychain-password' -o "$OldPass" -p "$NewPass" "${LoginKeychain:?}" ; then
			StatusMSG $ScriptName "Keychain updated successfully"
		else
			StatusMSG $ScriptName "Updating users keychain failed, creating new keychain"
			$mv "${LoginKeychain:?}" "/Library/Caches/$Username.login.keychain.backup"
			$security create-keychain -p "$NewPass" "$LoginKeychain" &&
				StatusMSG $ScriptName "Created new keychain: $LoginKeychain"
			$security default-keychain -s "$LoginKeychain" &&
				StatusMSG $ScriptName "Set $LoginKeychain as default"

		fi
	fi
	if [ -f "${LoginKeychain:?}" ]; then
		StatusMSG $FUNCNAME "Successfully updated login Keychain password to match the users $Company password"
		$chown "$Username" "$LoginKeychain" &&
			StatusMSG $FUNCNAME "Successfully updated ownership of login.keychain to $NewUserName:admin"
			StatusMSG $ScriptName "Successfully synchronized login Keychain password" uistatus
	else
		StatusMSG $FUNCNAME "Failed updating keychain password.  Moved KeyChain to /Library/Caches/$Username.login.keychain.backup"
		StatusMSG $ScriptName "Failed updating login Keychain password." uistatus	
	fi
	setInstallPercentage 70.00
fi
setInstallPercentage 90.00		

die 0