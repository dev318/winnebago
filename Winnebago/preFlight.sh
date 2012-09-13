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

declare -xr VSControl="/usr/local/Mcafee/AntiMalware/VSControl"
declare -xr defaults="/usr/bin/defaults"
declare -xr pmset="/usr/bin/pmset"
declare -xr sudo="/usr/bin/sudo"
declare -xr killall="/usr/bin/killall"

begin
setInstallPercentage 10.00

StatusMSG $ScriptName "Disabling Antivirus temporarily..." uiphase


SystemStarter stop cma
if [ -f "$VSControl" ] ; then
  "$VSControl" stopoas
fi


setInstallPercentage 30.00

StatusMSG $ScriptName "Disabling Screen Saver temporarily..." uiphase

StatusMSG $ScriptName "Processing: $Username" uistatus 0.5

# Need to disable as we are switching passwords 
$sudo -u $Username $defaults write com.apple.screensaver askForPassword 0 
$sudo -u $Username $defaults -currentHost write com.apple.screensaver idleTime -int 0


setInstallPercentage 50.00
$killall ScreenSaverEngine

StatusMSG $ScriptName "Disabling Display Sleep temporarily..." uiphase

$pmset -a displaysleep 0
setInstallPercentage 90.00

# Added for testing, so we don't block reboots
/usr/bin/sudo -u $Username /usr/bin/killall Self\ Service
/usr/bin/killall Self\ Service

die 0
