#!/bin/bash
# set -x
# ABOVE: Uncomment to turn on debug
export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/lib:/usr/local/include:/usr/bin:/bin:/usr/sbin:/sbin"
###############################################################################################
# 		NAME: 			cacheAD.sh
#
# 		DESCRIPTION:  	This script uses the entered Network username and password to log 
#						into AD for the first time to cache the credentials locally
#
#		SYNOPSIS:		cacheAD.sh <Network ADID> <Network ADPASSWORD>
###############################################################################################
#		HISTORY:
#						- 09/28/2010 -- created by Zack Smith (zsmith@318.com) 	
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

# Parse the input options...
while getopts "u:p:o:n:l: h" CredInputs; do
	case $CredInputs in
		u ) UserName="$OPTARG" ;;
		p ) PassWord="$OPTARG" ;;
		o ) OldPass="$OPTARG" ;;
		l ) LocalUser="$OPTARG" ;;
		h ) echo $usage;
			exit 1;;			
	esac
done



# Commands Required by this script
declare -x awk="/usr/bin/awk"
declare -x cat="/bin/cat"
declare -x createmobileaccount="/System/Library/CoreServices/ManagedClient.app/Contents/Resources/createmobileaccount"
declare -x chown="/usr/sbin/chown"
declare -x dscl="/usr/bin/dscl"
declare -x dsimport="/usr/bin/dsimport"
declare -x mv="/bin/mv"
declare -x id="/usr/bin/id"
declare -x rm="/bin/rm"
declare -x sleep='/bin/sleep'
declare -x sed="/usr/bin/sed"


if [ "$DebugScript" = 'Yes' ] ; then
	declare -x Verbose='-v'
fi

# The following is a hopefully a rare scenerio where bind succeed but AD servers are not responding. 
cacheAccountManualPassword(){
	setInstallPercentage $CurrentPercentage.10
	StatusMSG $FUNCNAME "createmobileaccount command failed..."
	StatusMSG $FUNCNAME "Attempting to manually cache password"
	$createmobileaccount -n "$UserName" $Verbose >> "$LogFile" ||
		StatusMSG $FUNCNAME "Caching account without password failed!"
	FlushCache
	StatusMSG $FUNCNAME "Attempting to manually cache password" uistatus 1
	setInstallPercentage $CurrentPercentage.50
	if $id $UserName ; then
	declare UsersGUID="$($dscl /Search -read "/Users/$UserName" GeneratedUID | $awk '{print $NF;exit}')"
	
	StatusMSG $FUNCNAME "Making Shadow Hash File"
		"$RunDirectory/makehash.pl" "$PassWord" > "/var/db/shadow/hash/$UsersGUID"
	else
		StatusMSG $FUNCNAME "Create mobile account creation failed"
	fi
	setInstallPercentage $CurrentPercentage.99
}


userCacher(){
	StatusMSG $FUNCNAME "Starting Cache AD Function : $UserName"
	setInstallPercentage $CurrentPercentage.10
		declare UserName="$1"
		declare PassWord="$2"
		# **** ask about this - Expect?
		StatusMSG $FUNCNAME "Checking Authentication for $UserName"
		until dscl /Search -authonly "$UserName" "$PassWord" ; do
			let TRY++
			if [ "$TRY" -ge 60 ] ; then
				StatusMSG $ScriptName "Waiting for network" uistatus
				StatusMSG $FUNCNAME "Waiting for authentication to become active for $UserName"
				break
			fi
			sleep 1
		done
	setInstallPercentage $CurrentPercentage.50
		if [ -d "/Users/$UserName" ] ; then
			StatusMSG $FUNCNAME "Notice: Home Folder /Users/$UserName already exits"
			declare -i NewUserID="$($dscl /Search -read /Users/$UserName UniqueID | $awk '{print $NF;exit}')"
			if [ $NewUserID -gt 0 ] ; then
				$chown $NewUserID /Users/$UserName
				StatusMSG $FUNCNAME "Ensuring top level folder is owned by $UserName so command does not fail"
			fi
			export HOME_DID_NOT_EXIST="0"
		else
			export HOME_DID_NOT_EXIST="1"
		fi
		
		StatusMSG $FUNCNAME "Cleaning up stale symlinks"
		StatusMSG $ScriptName "Cleaning up old links" uistatus
		$rm "/Users/$UserName" 2>/dev/null
		# Update the ownsership for at least the top level folder so the command does not fail
		$chown "$UserName" "/Users/$UserName"
		$createmobileaccount -n "$UserName" -p "$PassWord" -h /Users/"$UserName" $Verbose >> "$LogFile" ||
			cacheAccountManualPassword
		
		# Add Directory Service Picture to local user account
		declare -x UserPicture="/Library/Caches/$UserName.jpg"
		# Add the LDAP picture to the user record if dsimport is avaiable 10.6+
		if [ -f "$UserPicture" ] ; then
			# On 10.6 and higher this works
			if [ "$OsVersion" -ge "6" ] ; then
				declare -x Mappings='0x0A 0x5C 0x3A 0x2C'
				declare -x Attributes='dsRecTypeStandard:Users 2 dsAttrTypeStandard:RecordName externalbinary:dsAttrTypeStandard:JPEGPhoto'
				declare -x PictureImport="/Library/Caches/$UserName.picture.dsimport"
				printf "%s %s \n%s:%s" "$Mappings" "$Attributes" "$UserName" "$UserPicture" >"$PictureImport"
				# Check to see if the user imported correctly then import picture
 				if $id "$UserName" &>/dev/null ; then
					# No credentials passed as we are running as root
					$dsimport -g  "$PictureImport" /Local/Default M &&
						StatusMSG $FUNCNAME "Successfully imported users picture."
				fi
			fi
		else
			StatusMSG $FUNCNAME "No user picture found at $UserPicture"
		fi
		# If a home folder was created during caching process , move out of way
		# Should not run using the normal command, here as a safe gaurd.

		if [ ${#HOME_DID_NOT_EXIST} -eq 1 ] ; then
                  shopt -s nocasematch
		  if [[ $UserName = $LocalUser ]] ; then
		    StatusMSG $ScriptName "Usernames match case insensitive match, preserving home folder"
		  else
			$mv -vn "/Users/$UserName" "/Users/.$UserName.existing"
		  fi
		  shopt -u nocasematch
		fi
		setInstallPercentage $CurrentPercentage.99
}

begin
StatusMSG $ScriptName "Creating Active Directory Account..." uiphase
	setInstallPercentage 10.00
StatusMSG $ScriptName "Waiting for user authentication work"
until id $UserName ; do
	let TRY++
	if [ "$TRY" -ge 10 ] ; then
		StatusMSG $ScriptName "Timed out waiting for user resolution of $UserName"
		break 
	fi
	# Flush DirectoryService cache
	FlushCache
	setInstallPercentage 20.$TRY
	sleep 1
done
unset TRY

setInstallPercentage 30.00

StatusMSG $ScriptName "Deleting Account: $TMP_USER"

$dscl . -delete "/Users/$TMP_USER" &&
	StatusMSG $ScriptName "Successfully Deleted Account: $TMP_USER"
	
FlushCache
userCacher "$UserName" "$PassWord"

#Added to renabled admin
if [ -f "/Library/Caches/$LocalUser.admin" ] ; then
	StatusMSG $ScriptName "Enabling admin access for $UserName"
	$dscl . merge /Groups/admin users "$UserName"
fi

setInstallPercentage 50.00

# **** INSERT: Error checking for "Login incorrect" - rollback 
# ...or prompt for password again and re-run once - if fail, revert and tell to rerun later
if [ ! -x "$createmobileaccount" ] ; then
	FatalError "Command Missing! $createmobileaccount , check OS Version"
fi

# Capture exit value of the authonly
$dscl /Local/Default -authonly "$UserName" "$PassWord"
declare -i ExitValue="$?" # Use this as script exit status
	setInstallPercentage 80.00

if [ ${ExitValue:-1} -ge 1 ] ; then
	StatusMSG $ScriptName "UserName and Password check Failed for $UserName"
	StatusMSG $ScriptName "Credentials failure" uistatus 0.5
	FatalError "Credentials failure"
else
	StatusMSG $ScriptName "New Account is verified!" uistatus 0.5
	history -c
	unset PassWord
	setInstallPercentage 90.00
	die 0
fi
