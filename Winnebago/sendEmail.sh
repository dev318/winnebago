#!/bin/bash
# set -x
###############################################################################################
# 		NAME: 			sendEmail.sh
#
# 		DESCRIPTION:  	This script sends a custom email to a specified email address when called
#               
#		USAGE:			sendEmail.sh <Subject> <Genentech UNIXID> <Error Code>
###############################################################################################
#		HISTORY:
#						- Randomized Email tmp path (zsmith@318.com)	11/8/2010
###############################################################################################
declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

declare -x awk="/usr/bin/awk"
declare -x cat="/bin/cat"
declare -x date="/bin/date"
declare -x dscl="/usr/bin/dscl"
declare -x touch="/usr/bin/touch"
declare -x grep="/usr/bin/grep"
declare -x networksetup="/usr/sbin/networksetup"
declare -x system_profiler='/usr/sbin/system_profiler'
declare -x sw_vers="/usr/bin/sw_vers"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"

exec 2>>"$LogFile"

# Parse the input options...
while getopts "u:p:o:l: hrc" CredInputs; do
	case $CredInputs in
		u ) export ADUser="$OPTARG" ;;
		l ) export LocalUser="$OPTARG" ;;
		p ) export NewPass="$OPTARG" ;;
		o ) export OldPass="$OPTARG" ;;
		r ) declare -xr Subject="WARNING" ;;
		c ) declare -xr Subject="CRITICAL" ;;
		h ) showUsage
			exit 1;;		
	esac
done
setInstallPercentage 30.00

# Needs fixup for var name change
UnixId="$ADUser"
ShortName="$LocalUser"

EmailMessage="/tmp/emailmessage-$$$RANDOM.txt"

begin
StatusMSG $ScriptName "Generating Email Message" uiphase
StatusMSG $ScriptName "Compiling log of all actions taken and sending it to IT" uistatus



echo "AD samAccountName: $UnixId" > "$EmailMessage"
echo "MAC RecordName (shortname): $ShortName" >> "$EmailMessage"
echo "ERROR: $ErrorCode" >> "$EmailMessage"
echo "  " >> "$EmailMessage"
echo `$system_profiler SPHardwareDataType | $grep "Model Identifier"` >> "$EmailMessage"
echo `$system_profiler SPHardwareDataType | $grep -m 1 "Serial Number"` >> "$EmailMessage"
echo `$sw_vers` >> "$EmailMessage"
echo "Network Service Order" >> "$EmailMessage"
echo `$networksetup -listnetworkserviceorder` >> "$EmailMessage"

setInstallPercentage 50.00





StatusMSG "$ScriptName" "Performing final authentication tests" uistatus

if [ "$Subject" != 'WARNING' ] && [ "$Subject" != 'CRITICAL' ] ; then
	# Capture exit value of the authonly
	$dscl /Local/Default -authonly "$ADUser" "$NewPass"
	declare -i ExitValue="$?" # Use this as script exit status
	setInstallPercentage 80.00
else
	declare -i ExitValue="0"
fi

if [ ${ExitValue:-1} -ge 1 ] ; then
	StatusMSG $ScriptName "UserName and Password check Failed for $UserName"
	StatusMSG $ScriptName "Credentials failure" uistatus
    Subject="ERROR"
    UnixId="$ADUser"
    ErrorCode="Credentials failure"
else
	StatusMSG $ScriptName "New Account is verified!" uistatus
	Subject="SUCCESS"
	UnixId="$ADUser"
	ErrorCode="No validation errors"
fi
StatusMSG "$ScriptName" "Sending Email..." uiphase
declare -i EmailSuccess=0
if [ "$Subject" = "ERROR" ]; then
	StatusMSG $ScriptName "Sending Email about Issue" uistatus
	echo " " >> "$EmailMessage"
	echo "--=== $ProjectName  ===---" >> "$EmailMessage"
	echo " " >> "$EmailMessage"
	echo "--> START" >> "$EmailMessage"
	echo " "
	echo "$ScriptVersion" >> "$EmailMessage"
	echo "<-- END" >> "$EmailMessage"
	"$RunDirectory/sendEmail.pl" -f "$Email" -t "$Email" -u "[ $ProjectName ] $Subject ($UnixId)-- `$date`" -m "$($cat "$EmailMessage")" -s "$SMTPServer" -a "$LogFile" -v -l "$LogFile"
	declare -i EmailSuccess="$?"
else
	StatusMSG $ScriptName "Sending $Subject Email to IT" uistatus
	echo " " >> "$EmailMessage"
	echo "--=== $ProjectName ===---" >> "$EmailMessage"
	echo " " >> "$EmailMessage"
	echo "$ScriptVersion" >> "$EmailMessage"
	echo " " >> "$EmailMessage"
	"$RunDirectory/sendEmail.pl" -f "$Email" -t "$Email" -u "[ $ProjectName ] $Subject ($UnixId)-- `$date`" -m "$($cat "$EmailMessage")" -s "$SMTPServer" -a "$LogFile" -v -l "$LogFile"
	declare -i EmailSuccess="$?"
fi	
	
if [ $EmailSuccess -gt 0 ] ; then
	StatusMSG $ScriptName "Email Script Error, exit value larger the 0" error
	StatusMSG $ScriptName "Email send failure" uistatus
 	$cat "$EmailMessage" > "/Library/Caches/.$UnixId.emailneeded"
else
	StatusMSG $ScriptName "Disabling post reboot email" passed
	$cat "$EmailMessage" > "/Library/Caches/.$UnixId.emailcomplete"
	rm "/Library/Caches/.$UnixId.emailneeded" 2>/dev/null
fi

history -c
unset PassWord

setInstallPercentage 90.00



exit 0
