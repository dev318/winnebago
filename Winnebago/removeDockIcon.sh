#!/bin/bash
# set -x

export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/lib:/usr/local/include:/usr/bin:/bin:/usr/sbin:/sbin"
#===============================================================================
#
#          FILE:  removeDockIcon.sh
#
#   DESCRIPTION:  Removes dock icon 
#       OPTIONS:  ---
#       CREATED:  10/07/2010 3:45 PM
#  LAST REVISED:  12/09/2010 by Zack Smith , zsmith@318.com
#===============================================================================
declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"
exec 2>>"$LogFile"

[ $# = 0 ] &&
	FatalError "No arguments Given, but required for $ScriptName.sh"
	

[ "$EUID" != 0 ] && 
	printf "%s\n" "This script requires root access!" && exit 1

# VARIABLES
# =========
# Commands used by that script
declare -x basename="/usr/bin/basename"
declare -x sed="/usr/bin/sed"
declare -x PlistBuddy="/usr/libexec/PlistBuddy"

# Determines last logged in user 
declare -x LocalUser="$1"
declare -x DockIconPath="$2"


# Type in the unique partial name without spaces of the item you would like removed from the dock
IconNamePartial="$($basename "$DockIconPath" | $sed 's/.app//g')"


# FUNCTIONS
# =========

RemoveDockItem(){
	StatusMSG $FUNCNAME "Removing Dock Icon for this Application" uistatus
	declare -i NumberIcons=(`$PlistBuddy -c "Print :persistent-apps" "/Users/$LocalUser/Library/Preferences/com.apple.dock.plist"  | awk '/GUID/{seen++}END{print seen}'`)
	StatusMSG $FUNCNAME "Found $NumberIcons Dock Icons on the system"
	if [ "$NumberIcons" -eq 0 ] ; then
		StatusMSG $FUNCNAME "Dock icon for $IconNamePartial not found on system ($DockIconPath)" 
		exit 0
	fi 
	for (( n = ${NumberIcons:?}; n >= 1; n-- )); do
		declare -i FoundDockItem="$($PlistBuddy -c "Print :persistent-apps:$n:tile-data:file-label" "/Users/$LocalUser/Library/Preferences/com.apple.dock.plist" | awk "/$IconNamePartial/{seen++}END{print seen}")"
		if [ "$FoundDockItem" -ge 1 ]; then
			$PlistBuddy -c "Delete :persistent-apps:$n" "/Users/$LocalUser/Library/Preferences/com.apple.dock.plist"
		fi
	done
}

# EXECUTE
# =======
begin
StatusMSG $ScriptName "Updating Dock..." uiphase
	setInstallPercentage 10.00
# Removes dock icon
RemoveDockItem
	setInstallPercentage 50.00
# Refreshes Dock so that new updated dock without the icon is visible
killall Dock
	setInstallPercentage 80.00
die 0