#!/bin/bash

# inventoryUpdate.sh
#
# Created by Zack Smith on 3/14/12.
# Copyright 2012 318. All rights reserved.

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

declare -x jamf="/usr/local/bin/jamf"

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

begin

setInstallPercentage 10.00

# If shortname is different from userid - migrate home directory to match userid and update group id and ownership
begin
StatusMSG $ScriptName "Updating Inventory..." uiphase
StatusMSG $ScriptName "This process may take several minutes..." uistatus 0.5

$jamf recon >>"$LogFile"

setInstallPercentage 70.00


setInstallPercentage 80.00


StatusMSG $ScriptName "Enabling user level MDM" uistatus 0.5

$jamf mdm -username "$ADUser" >>"$LogFile"

setInstallPercentage 90.00

StatusMSG $ScriptName "Running tool update script..." uistatus 0.5

$jamf policy -trigger winnebagoexample
die 0
