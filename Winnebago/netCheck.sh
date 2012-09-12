#!/bin/bash
# set -x
###############################################################################################
# 		NAME: 			netCheck.sh
#
# 		DESCRIPTION:  	Checks to make sure computer is connected to the $Company network     
###############################################################################################
#		HISTORY:
#						- modified by Zack Smith (zsmith@318.com)    11/15/2011
#						- modified by Zack Smith (zsmith@318.com)   11/17/2011
###############################################################################################

declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"
exec 2>>"$LogFile"

declare -x dscacheutil="/usr/bin/dscacheutil"
declare -x ping="/sbin/ping"
declare -x ldapsearch="/usr/bin/ldapsearch"

StatusMSG "${ScriptName:="$0"}" "Checking network connectivity..." uiphase
FlushCache
# Flush DirectoryService/opendirectoryd before running (helps with loop)
StatusMSG $ScriptName "Checking Connectivity to $DomainController0" uistatus
CheckZero=`$ping -c 1 "$DomainController0"`
declare -i CheckZeroStatus=$?
# LDAP Connectivity Test
setInstallPercentage 10.00
CheckLDAP=`$ldapsearch -H ldaps://$DomainController0 -x`
declare -i CheckLDAPStatus=$?

setInstallPercentage 20.00
# If we have ping connectivity to load balencer then
if [ "$CheckZeroStatus" = 0 ] ; then
	# Do a quick LDAP query and check for can't connect error 255+
	if [ $CheckLDAPStatus -lt 255 ] ; then
        	StatusMSG $FUNCNAME "CONFIRMED - Connected to $Company network" passed
       		StatusMSG $FUNCNAME "Connected to $Company network" uistatus
	        setInstallPercentage $CurrentPercentage.99
		die 0
	fi
	else
	StatusMSG $ScriptName "Begining extended check..." uistatus
fi

StatusMSG $ScriptName "Checking Connectivity to $DomainController1" uistatus
CheckOne=`$ping -c 1 "$DomainController1"`
declare -i CheckOneStatus=$?
setInstallPercentage 40.00


StatusMSG $ScriptName "Checking Connectivity to $DomainController2" uistatus
CheckTwo=`$ping -c 1 "$DomainController2"`
declare -i CheckTwoStatus=$?
setInstallPercentage 60.00


StatusMSG $ScriptName "Checking Connectivity to $DomainController3" uistatus
CheckThree=`$ping -c 1 "$DomainController3"`
declare -i CheckThreeStatus=$?
setInstallPercentage 90.00

CheckNet(){
	setInstallPercentage $CurrentPercentage.10
 # ZS Added check for load balencer first
 if [ "$CheckZeroStatus" = 0 ] ; then
        StatusMSG $FUNCNAME "CONFIRMED - Connected to $Company network" passed
        StatusMSG $FUNCNAME "Connected to $Company network" uistatus
        setInstallPercentage $CurrentPercentage.99
	return 0
 fi
 if [ $CheckOneStatus != 0 ] || [ $CheckTwoStatus != 0 ] || [ $CheckThreeStatus != 0 ]; then
   	StatusMSG $FUNCNAME "FAILED - Not Connected to $Company network" error
 	StatusMSG $FUNCNAME "Not Connected to $Company network" uistatus
	setInstallPercentage $CurrentPercentage.99
	return 1
 else
	StatusMSG $FUNCNAME "CONFIRMED - Connected to $Company network" passed
	StatusMSG $FUNCNAME "Connected to $Company network" uistatus
	setInstallPercentage $CurrentPercentage.99
	return 0	
 fi
	
}
	
begin
CheckNet || die 1
die 0

