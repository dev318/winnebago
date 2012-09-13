#!/bin/bash
#set -x
###############################################################################################
# 		NAME: 			geUserPicture.sh
#
# 		DESCRIPTION:  	This script looks up the URL of the user picture
#						Downloads it and converts it for use in AppleScript
#               
#		USAGE:			checkADZone.sh -h
###############################################################################################
#		HISTORY:
#						- created by Zack Smith (zsmith@318.com) 	10/28/2010
###############################################################################################
declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"

showUsage(){
	printf "%s\n\t" "USAGE:"
	printf "%s\n\t" 
	printf "%s\n\t" " OUTPUT:"
	printf "%s\n\t" " -u | # Get Picture URL"
	printf "%s\n\t"
	printf "%s\n\t" " EXAMPLE SYNTAX:"
	printf "%s\n\t" " sudo $0 -u username"
	printf "%s\n"
	return 0
}

exec 2>>"${LogFile:?}" # Redirect standard error to log file

if [ $# = 0 ] ; then
	showUsage
	FatalError "No arguments Given, but required for $ScriptName"
fi
	
# Check script options
while getopts clru:w:h SWITCH ; do
	case $SWITCH in
		u ) export UserName="${OPTARG}" ;;
		h ) showUsage ;;
		
	esac
done # END while

# Commands required by this script
declare -rx awk="/usr/bin/awk"
declare -rx ldapsearch="/usr/bin/ldapsearch"
declare -rx sed="/usr/bin/sed"
declare -rx xxd="/usr/bin/xxd"
declare -rx who=/usr/bin/who

export SaveDirectory="/Library/Caches"

declare -rx CONSOLE_USER="$($who | $awk '/console/{print $1;exit}')"


ldapAttribute(){
		declare -x UserShortName="$1" UserAttribute="$2"
		$ldapsearch -LLL -h "$LdapServer" -x -b "uid=$UserName,$LdapBase" "$UserAttribute" | 
				$sed "s/^$UserAttribute:: //g"
}

#export UserPictureURL="$(ldapAttribute "$UserName" 'jpegPhoto')"
export UserPictureURL="DISABLED"

if [ ${#UserPictureURL} -gt 0 ]; then

	# This is where we temporaryly save the Photo
	declare -x EXPORT_PICTURE="$SaveDirectory/$UserName.jpg"
	
	# Use an existing one if there
	if [ ! -f "$EXPORT_PICTURE" ] ; then
		dscl /Search read /Users/$CONSOLE_USER JPEGPhoto |
			$awk '{getline}END{print}'|
			$xxd -r -p > "$EXPORT_PICTURE"
	fi
	
	printf "%s\n"  "<result>file://localhost/$EXPORT_PICTURE</result>"
else
	printf "%s" '<result>74DBE8F9-BFCD-4CA1-98DC-FC89CCE41439</result>'
fi
exit 0

