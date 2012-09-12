#!/bin/bash
# set -x
# ABOVE: Uncomment to turn on debug
export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/lib:/usr/local/include:/usr/bin:/bin:/usr/sbin:/sbin"
###############################################################################################
# 		NAME: 			addToDock.sh
#
# 		DESCRIPTION:  	This script adds the Mac AD Utility to the dock if the installation is 
#						deferred by the user 
#               
#		USAGE:			addToDock.sh <Mac username>
###############################################################################################
#		HISTORY:
#						- created by Zack Smith (zsmith@318.com) 	02/04/2011
###############################################################################################

declare -x Script="${0##*/}" 
declare -x ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

# Check for a common file in the same directory
if [ -f "$RunDirectory/common.sh" ] ; then
	source "$RunDirectory/common.sh"
else
	printf "%s\n" "Common file required for this script is missing !($RunDirectory/common.sh)"
	exit 1
fi
# Check for a conf file in the same directory
if [ -f "$RunDirectory/.winnebago.conf" ] ; then
	source "$RunDirectory/.winnebago.conf"
else
	printf "%s\n" "Configuration file required for this script is missing !($RunDirectory/.MacMigrator.conf)"
	exit 1
fi

exec 2>>"$LogFile"

[ $# = 0 ] &&
	FatalError "No arguments Given, but required for $ScriptName.sh"

LocalUser="$1"
DockPath="$2"

# Commands used by this script
declare -x awk="/usr/bin/awk"
declare -x basename="/usr/bin/basename"
declare -x chown="/usr/sbin/chown"
declare -x plutil="/usr/bin/plutil"
declare -x sed="/usr/bin/sed"
declare -x strings="/usr/bin/strings"
declare -x killall="/usr/bin/killall"

# Adds the Mac AD Utility to the user's dock if it does not already exist
AddItemToDock() {
	# Checks to see if Mac AD Utility.app already exists in the dock
	declare DockPlist="/Users/$LocalUser/Library/Preferences/com.apple.dock.plist"
	declare DockIconName="$($basename "$DockPath" | $sed 's@/@@g')"
	
	StatusMSG $FUNCNAME "Checking for $DockIconName in $DockPlist"
	
	declare -i DockStatus="$($strings "${DockPlist:?}" |
													$awk "/$DockIconName/"'{seen ++}END{print seen}')"
	StatusMSG $FUNCNAME "Pattern match found $DockStatus entries for $DockPath"
	
	[ ! -f "$DockPlist" ] &&
		StatusMSG $FUNCNAME "Notice Dock Preference: $DockPlist does not exist"
	# If Mac AD Utility.app does not exists in the dock; adds utility to the users dock
	if [ "${DockStatus:-0}" -eq 0 ]; then
		# Adds Mac AD Utility.app to the user's dock
		
		StatusMSG $FUNCNAME "Adding $DockIconName to the dock"	
		defaults write "${DockPlist%%.plist}" persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$DockPath</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>" ||
			StatusMSG $FUNCNAME "Adding $DockIconName to $DockPlist command failed"
		StatusMSG $FUNCNAME "Converting $DockPlist to xml..."
		$plutil -convert xml1 "$DockPlist" ||
			StatusMSG $FUNCNAME "Converting $DockPlist to xml command failed"
		StatusMSG $FUNCNAME "Resetting ownership ($LocalUser) of $DockPlist"
		$chown "$LocalUser" "$DockPlist" ||
			StatusMSG $FUNCNAME "Resetting ownership ($LocalUser) of $DockPlist failed"
		
		# Kills and restarts the dock
		StatusMSG $FUNCNAME "Restarting Dock..."
		$killall Dock ||
			StatusMSG $FUNCNAME "Restarting Dock Failed"

		StatusMSG $FUNCNAME "Dock respawned with $ScriptName"
	fi	

}

StatusMSG $ScriptName "BEGINNING: addToDock.sh - Mac AD Utility"
AddItemToDock
StatusMSG $ScriptName "FINISHED: addToDock.sh - Mac AD Utility"