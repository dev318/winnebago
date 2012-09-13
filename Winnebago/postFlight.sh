#!/bin/bash
# set -x
# ABOVE: Uncomment to turn on debug
export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/lib:/usr/local/include:/usr/bin:/bin:/usr/sbin:/sbin"
###############################################################################################
###############################################################################################
#		HISTORY:
#						- created by Zack Smith (zsmith@318.com) 	4/18/2012
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

declare -x PLIST_ID="com.github.winnebago"
declare -x PLIST_PATH="/Library/LaunchDaemons/${PLIST_ID:?}.plist"

declare -xr VSControl="/usr/local/Mcafee/AntiMalware/VSControl"
declare -xr defaults="/usr/bin/defaults"
declare -xr pmset="/usr/bin/pmset"
declare -xr sudo="/usr/bin/sudo"
declare -xr killall="/usr/bin/killall"
declare -xr grep="/usr/bin/grep"
declare -xr ifconfig="/sbin/ifconfig"
declare -xr mv="/bin/mv"
declare -xr vpn="/opt/cisco/vpn/bin/vpn"

begin
setInstallPercentage 10.00
StatusMSG $ScriptName "(Re)Enabling Antivirus protection..." uiphase

SystemStarter start cma
if [ -f "$VSControl" ] ; then
  "$VSControl" startoas
fi
setInstallPercentage 30.00

StatusMSG $ScriptName "Configuring PostFlight Actions..." uiphase


#$sudo -u $Username $defaults write com.apple.screensaver askForPassword  
#$sudo -u $Username $defaults -currentHost write com.apple.screensaver idleTime -int 0
setInstallPercentage 50.00

$killall ScreenSaverEngine

$pmset -a displaysleep 0
setInstallPercentage 50.00



# Trying to work around anyconnect timeout issues
declare -ix VPN_UP="$($ifconfig utun0 | $grep -co 'UP')"

# Checking here as this command can hang the system if not connected.
if [ $VPN_UP -ge 1 ] ; then
  StatusMSG $ScriptName "Disconnecting from VPN..." uistatus 0.5
  $vpn disconnect
  
  StatusMSG $ScriptName "Restarting Directory Services" uistatus 0.5
  $killall DirectoryService
  $killall opendirectoryd
fi

# Disabling the Launchd Item
if [ -f "${PLIST_PATH:?}" ] ; then
  $mv -v "$PLIST_PATH" /private/tmp/
fi


# Work around problem http://support.apple.com/kb/HT4100
/usr/libexec/PlistBuddy -c 'add :rights:system.login.console:mechanisms: string builtin:krb5store,privileged' /etc/authorization

# Work around problem http://support.apple.com/kb/TS3287
/usr/libexec/PlistBuddy -c 'set :rights:system.login.screensaver:comment "(Use SecurityAgent.) The owner of any administrator can unlock the screensaver."' /etc/authorization

# Display the AFP/SMB auth dialog with shortname instead of Real Name
$defaults write /Library/Preferences/com.apple.NetworkAuthorization UseDefaultName -bool NO
$defaults write /Library/Preferences/com.apple.NetworkAuthorization UseShortName -bool YES

# Extention Attribute
$defaults write /Library/Application\ Support/Winnebago/com.github.winnebago LocalUserName "$Username"
$defaults write /Library/Application\ Support/Winnebago/com.github.winnebago NetworkUserName "$NewUserName"


setInstallPercentage 90.00

# Deleting the Application
# Removed this as picture don't show if we do this
#$mv "/Library/Application Support/Winnebago/Winnebago.app" /private/tmp/

die 0
