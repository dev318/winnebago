#!/bin/bash
#set -x
###############################################################################################
# 		NAME: 			checkBind.sh
#
# 		DESCRIPTION:  	Checks to make sure computer is connected to the Mac AD network     
#		SYNOPSIS:		sudo adJoin.sh
###############################################################################################
#		HISTORY:
#						- created by Zack Smith (zsmith@318.com) 	09/28/2010
###############################################################################################
# NEED TO ADD: return AD Username
declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/.winnebago.conf"
source "$RunDirectory/common.sh"
exec 2>>"$LogFile"

declare -x awk="/usr/bin/awk"
declare -x ldapsearch="/usr/bin/ldapsearch"

adLookup(){
  header
  StatusMSG "$FUNCNAME" "Attempting lookup of uid: $uidNumber"
  setInstallPercentage $CurrentPercentage.10
		$ldapsearch \
		-LLL \
		-x \
		-H "ldap://$DomainController0" \
		-D "$UserName@$DefaultDomain" \
		-w "$PassWord" \
		-b "$DefaultSearchBase" "sAMAccountName=$UserName" sAMAccountName #>> "$LogFile"
		return $?
}

checkCredentials(){
  header
	setInstallPercentage $CurrentPercentage.10
	declare -xi CheckOneStatus
	declare -xi CheckTwoStatus
	
	# Do not reorder, exit capture	
	adLookup
        declare -xi CheckOneStatus=$?
	StatusMSG "$FUNCNAME" "adLookup Found LDAP Results: $ADRecord"
	setInstallPercentage $CurrentPercentage.50
	
	# So we only get one result on success
	if [ $CheckOneStatus != 0 ] ; then
		StatusMSG "$FUNCNAME" "First Check Failed for server :$LdapServer"		
		adLookup
			declare -xi CheckTwoStatus=$?
		    StatusMSG "$FUNCNAME" "adLookup Found LDAP Results: $ADRecord"
	fi
	setInstallPercentage $CurrentPercentage.70

	if [ $CheckOneStatus != 0 ] || [ $CheckTwoStatus != 0 ] ; then
		StatusMSG "$FUNCNAME" "Credentials Check Failed on both Servers"
		setInstallPercentage $CurrentPercentage.99
		return 1
	else
		StatusMSG "$FUNCNAME" "Credentials Check Succeeded!" uistatus
		setInstallPercentage $CurrentPercentage.99
		return 0	
	fi
}


# Check script options
StatusMSG "$ScriptName" "Processing script $# options:$@"
while getopts u:p: SWITCH ; do
	case $SWITCH in
		u ) export UserName="${OPTARG}" ;;
		p ) export PassWord="${OPTARG}" ;;		
	esac
done # END while

# Initialize Vars,
declare -ix UserNameCheck
declare -ix PassWordCheck

begin
StatusMSG "$ScriptName" "Checking Bind..." uiphase
	setInstallPercentage 20.00

if [ ${#UserName} -lt 0 ] ; then
	FatalError "UserName not passed to script"

fi

echo "$ADRecord"
if [ ${#PassWord} -gt 0 ] ; then
	if checkCredentials ; then
		setInstallPercentage 50.00
		StatusMSG "$FUNCNAME" "Found ADRecord: $ADRecord"
		if [ ${#ADRecord} -gt 0 ] ; then
			echo "<result>$ADRecord</result>"
	    else
			echo "<result>$UserName<result>"
		fi
	else
		echo "<result>$UserName<result>"
		setInstallPercentage 99.00
		FatalError "User provided invalid credentials ($UserName)"
	fi

else
	FatalError "Password not passed to script"
fi
setInstallPercentage 80.00
die 0


