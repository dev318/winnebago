#!/bin/bash
# dsconfig
#################################################################################
#set -xv # Uncomment for debug , also change LOGLEVEL=VERBOSE
declare -xa EN=( 0 1 2 ) # Interfaces to test en0 , en1

declare -x Script="${0##*/}" ; ScriptName="${Script%%\.*}"
declare -x ScriptPath="$0" RunDirectory="${0%/*}"

source "$RunDirectory/common.sh"

# Commands at known Mac OS X Paths
declare -x awk="/usr/bin/awk"
declare -x date="/bin/date"
declare -x dscl="/usr/bin/dscl"
declare -x dsconfigad="/usr/sbin/dsconfigad"
declare -x dsconfigldap="/usr/sbin/dsconfigldap"
declare -x du="/usr/bin/du"
declare -x defaults="/usr/bin/defaults"
declare -x killall="/usr/bin/killall"
declare -x host="/usr/bin/host"
declare -x launchctl="/bin/launchctl"
declare -x ps="/bin/ps"
declare -x plutil="/usr/bin/plutil"
declare -x python="/usr/bin/python"
declare -x srm="/usr/bin/srm"
declare -x scutil="/usr/sbin/scutil"
declare -x sysctl="/usr/sbin/sysctl"
declare -x id="/usr/bin/id"
declare -x ifconfig="/sbin/ifconfig"
declare -x ioreg="/usr/sbin/ioreg"
declare -x ipconfig="/usr/sbin/ipconfig"
declare -x sleep="/bin/sleep"
declare -x osascript="/usr/bin/osascript"
declare -x mv="/bin/mv"
declare -x nvram="/usr/sbin/nvram"
declare -x ls="/bin/ls"
declare -x scutil="/usr/sbin/scutil"
declare -x ARDAGENT="/System/Library/CoreServices/RemoteManagement/ARDAgent.app"
declare -x rm="/bin/rm"
declare -x systemsetup="${ARDAGENT:?}/Contents/Support/systemsetup"
declare -x networksetup="${ARDAGENT:?}/Contents/Support/networksetup"
declare -x ntpdate="/usr/sbin/ntpdate"
declare -x who="/usr/bin/who"
declare -x wc="/usr/bin/wc"
# 10.5 Updates
[ -f "/usr/sbin/networksetup" ] && declare -x networksetup="/usr/sbin/networksetup"
[ -f "/usr/sbin/systemsetup" ] && declare -x systemsetup="/usr/sbin/systemsetup"
# increase main loop to 20 times for stand alone execution. 6/11/2008

# -- Runtime varibles
declare -x REQCMDS="$awk $date $du $dscl $dsconfigad $defaults $host $killall $sleep $ps $scutil $ifconfig $ioreg $id $ipconfig $ntpdate $who"
declare -x SCRIPT="${0##*/}" ; SCRIPTNAME="${SCRIPT%%\.*}"
declare -x SCRIPTPATH="$0" RUNDIRECTORY="${0%/*}"	
declare -x SYSTEMVERSION="/System/Library/CoreServices/SystemVersion.plist"
declare -x OSVER="$("$defaults" read "${SYSTEMVERSION%.plist}" ProductVersion )"
declare -x CONFIGFILE="${RUNDIRECTORY:?}/.MacMigrator.conf"
declare -x BUILD_VERSION="20122702"
declare -x SCRIPT_DOMAIN="com.nike"

[ "$EUID" != 0 ] && 
	printf "%s\n" "This script requires root access!" && exit 1

# -- Start the script log
# Set to "VERBOSE" for more logging prior to using -v
/bin/mkdir -p /Library/Logs/Nike
declare -x LOGLEVEL="VERBOSE" SCRIPTLOG="/Library/Logs/Winnebago/Winnebago.log"
declare -xi LOG_MAX_SIZE=5

declare -x LDPLIST="/Library/LaunchDaemons/${SCRIPT_DOMAIN:?}.${SCRIPT%%\.*}.plist"
if [ -f "$SCRIPTLOG" ] ; then
	declare -i CURRENT_LOG_SIZE="$("$du" -hm "${SCRIPTLOG:?}" |
					"$awk" '/^[0-9]/{print $1;exit}')"
fi
# Check current log size
if [ ${CURRENT_LOG_SIZE:=0} -gt "$LOG_MAX_SIZE" ] ; then
	"$rm" "$SCRIPTLOG"
	echo "LOGSIZE:$CURRENT_LOG_SIZE, too large removing"
fi

exec 2>>"${SCRIPTLOG:?}" # Redirect standard error to log file

# Strip any extention from scriptname and log stderr to script log
if [ -n ${SCRIPTLOG:?"The script log has not been specified"} ] ; then
	printf "%s\n" \
"STARTED:$SCRIPTNAME:EUID:$EUID:$("$date" +%H:%M:%S): Mac OS X $OSVER:BUILD:$BUILD_VERSION" >>"${SCRIPTLOG:?}"
	printf "%s\n" "Log file is: ${SCRIPTLOG:?}"
fi

# The Property lists we work with in the script 
declare -x ADPLIST="/Library/Preferences/DirectoryService/ActiveDirectory.plist"
declare -x DSPLIST="/Library/Preferences/DirectoryService/DirectoryService.plist"
declare -x SEARCH_PLIST="/Library/Preferences/DirectoryService/SearchNodeConfig.plist"


# Main logging routine
statusMessage() { # Status message function with type and now color!
# Requires SCRIPTLOG STATUS_TYPE=1 STATUS_MESSAGE=2

declare date="${date:="/bin/date"}"
declare DATE="$("$date" -u "+%Y-%m-%d")"
declare STATUS_TYPE="$1" STATUS_MESSAGE="$2"
if [ "$ENABLECOLOR" = "YES"  ] ; then
	# Background Color
	declare REDBG="41" WHITEBG="47" BLACKBG="40"
	declare YELLOWBG="43" BLUEBG="44" GREENBG="42"
	# Foreground Color
	declare BLACKFG="30" WHITEFG="37" YELLOWFG="33"
	declare BLUEFG="36" REDFG="31"
	declare BOLD="1" NOTBOLD="0"
	declare format='\033[%s;%s;%sm%s\033[0m\n'
	# "Bold" "Background" "Forground" "Status message"
	printf '\033[0m' # Clean up any previous color in the prompt
else
	declare format='%s\n'
fi

# AppleScript Display Function
# Function only seems to well work on intel and higher.
showUIDialog(){
statusMessage header "FUNCTION: #	$FUNCNAME" ; unset EXITVALUE TRY
"$killall" -HUP "System Events" 2>/dev/null
declare -x UIMESSAGE="$1"
"$osascript" <<EOF
try
with timeout of 0.1 seconds
	tell application "System Events"
		set UIMESSAGE to (system attribute "UIMESSAGE") as string
		activate
			display dialog UIMESSAGE with icon 2 giving up after "3600" buttons "Dismiss" default button "Dismiss"
		end tell
	end timeout
end try
EOF
return 0
} # END showUIDialog()

case "${STATUS_TYPE:?"Error status message with null type"}" in
	progress) \
	[ -n "$LOGLEVEL" ] &&
	printf $format $NOTBOLD $WHITEBG $BLACKFG "PROGRESS:$STATUS_MESSAGE"  ;
	printf "%s\n" "$DATE:PROGRESS: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;;
	# Used for general progress messages, always viewable
	
	notice) \
	printf "%s\n" "$DATE:NOTICE:$STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;
	[ -n "$LOGLEVEL" ] &&
	printf $format $NOTBOLD $YELLOWBG $BLACKFG "NOTICE  :$STATUS_MESSAGE"  ;;
	# Notifications of non-fatal errors , always viewable
	
	error) \
	printf "%s\n\a" "$DATE:ERROR:$STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;
	[ -n "$LOGLEVEL" ] &&
	printf $format $NOTBOLD $REDBG $YELLOWFG "ERROR   :$STATUS_MESSAGE"  ;;
	# Errors , always viewable

	verbose) \
	printf "%s\n" "$DATE:VERBOSE: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;
	[ "$LOGLEVEL" = "VERBOSE" ] &&
	printf $format $NOTBOLD $WHITEBG $BLACKFG "VERBOSE :$STATUS_MESSAGE" ;;
	# All verbose output
	
	header) \
	[ "$LOGLEVEL" = "VERBOSE" ] &&
	printf $format $NOTBOLD $BLUEBG $BLUEFG "VERBOSE :$STATUS_MESSAGE" ;
	printf "%s\n" "$DATE:PROGRESS: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;;
	# Function and section headers for the script
	
	passed) \
	[ "$LOGLEVEL" = "VERBOSE" ] &&
	printf $format $NOTBOLD $GREENBG $BLACKFG "SANITY  :$STATUS_MESSAGE" ;
	printf "%s\n" "$DATE:SANITY: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;;
	# Sanity checks and "good" information
	graphical) \
	[ "$GUI" = "ENABLED" ] &&
	showUIDialog "$STATUS_MESSAGE" ;;
	
esac
return 0
} # END statusMessage()

die() { # die Function
	statusMessage header "FUNCTION: #	$FUNCNAME" ; unset EXITVALUE
	declare LASTDIETYPE="$1" LAST_MESSAGE="$2" LASTEXIT="$3"
	declare LASTDIETYPE="${LASTDIETYPE:="UNTYPED"}"
	if [ ${LASTEXIT:="192"} -gt 0 ] ; then
		statusMessage error "$LASTDIETYPE :$LAST_MESSAGE:EXIT:$LASTEXIT"
		# Print specific error message in red
	else
		statusMessage verbose "$LASTDIETYPE :$LAST_MESSAGE:EXIT:$LASTEXIT"
		# Print specific error message in white
	fi
	statusMessage verbose "COMPLETED:$SCRIPT IN $SECONDS SECONDS"
	"$killall" "System Events"
	exit "${LASTEXIT}"	# Exit with last status or 192 if none.
	return 1		# Should never get here
} # END die()

cleanUp() { # -- Clean up of our inportant sessions variables and functions.
statusMessage header "FUNCTION: #	$FUNCNAME" ; unset EXITVALUE
statusMessage verbose "TIME: $SCRIPT ran in $SECONDS seconds"
unset -f ${!check*}
[ "${ENABLECOLOR:-"ENABLECOLOR"}" = "YES"  ] && printf '\033[0m' # Clear Color

if [ "$PPID" == 1 ] ; then # LaunchD is always PID 1 in 10.4+
	declare LAUNCHDITEM=$("$launchctl" list |
	"$awk" -F'.' '$2!~/apple/{
	scriptname=ENVIRON["SCRIPTNAME"]
	# Pull the script name
	if ( scriptname == $NF )
	# If the last part of the domain matches the scriptname
		{print $0;exit}}')
	# Automatically find the scripts launchd item base on the script name	
        
	declare LDPLIST="${LAUNCHDITEM:?}.plist"
	statusMessage progress "Self destructing: $CONFIGFILE"

	# If we have a config file, securely remove it
	[ -f "$CONFIGFILE" ] && "$srm" "${CONFIGFILE:?}"
        
	"$killall" -HUP 'System Events'

	# ABOVE: To Restart the UI Messages on intel machines
	if [ ${#LAUNCHDITEM} -gt 0 ] ; then
	        statusMessage verbose "Ran as a startup item, unloading:$LDPLIST"
		# BELOW: Good measure write the disabled key , just incase	
	        "$defaults" write "/Library/LaunchDaemons/${LDPLIST}" Disabled -bool true
		"$plutil" -convert xml1 "/Library/LaunchDaemons/${LDPLIST}"

		"$mv" "/Library/LaunchDaemons/$LDPLIST" "/tmp/${LDPLIST:?}"
		# BELOW : Unload the job from its new home.
		"$launchctl" unload "/tmp/${LDPLIST:?}"
	fi
	statusMessage progress "Self destructing: $0"
	"$srm" "$0"
	# Good bye crule world
fi
	declare CONSOLEUSER=$("$who" | "$awk" '$2~/console/{ print $1;exit}')
	# If their are not console users
	if [ ${#CONSOLEUSER} -eq 0 ] ; then
		[ "$KILL_LOGIN_WINDOW" = "YES"] &&
				"$killall" -HUP 'loginwindow'
	fi
exec 2>&- # Reset the error redirects
return 0
} # END cleanUp()

checkCommands() { # CHECK_CMDS Required Commands installed check using the REQCMDS varible.
declare -i FUNCSECONDS="$SECONDS" # Capture start time
statusMessage header  "FUNCTION: #	${FUNCNAME}" ; unset EXITVALUE
declare REQCMDS="$1"
	for RQCMD in ${REQCMDS:?} ; do
		if [  -x "$RQCMD" ] ; then
			statusMessage passed "PASSED: $RQCMD is executable"
		else
			# Export the command Name to the die status message can refernce it"
			export RQCMD ; return 1
		fi
	done
return 0
declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
[ "${FUNCTIME:?}" != 0 ] &&
statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds to EXIT:$EXITVALUE"
} # END checkCommands()

checkSystemVersion() { 
	# CHECK_OS Read the /Sys*/Lib*/CoreSer*/S*Version.plist value for OS version
	statusMessage header "FUNCTION: #	${FUNCNAME}" ; unset EXITVALUE
	declare OSVER="$1"
	case "${OSVER:?}" in
		10.0* | 10.1* | 10.2* | 10.3*) \
		die ERROR "$FUNCNAME: Unsupported OS version: $OSVER." 192 ;;

		10.4*) \
		statusMessage passed "CHECK_OS: OS check: $OSVER successful!";
		export OS="T" ;return 0 ;;

		10.5*) \
		statusMessage passed "CHECK_OS: OS check: $OSVER successful!";
		export OS="L"; return 0 ;;
	
		10.6*) \
		statusMessage passed "CHECK_OS: OS check: $OSVER successful!";
		export OS="S"; return 0 ;;
		10.7*) \
		statusMessage passed "CHECK_OS: OS check: $OSVER successful!";
		export OS="N"; return 0 ;;
		*) \
		die ERROR "CHECK_OS:$LINENO Unsupported OS:$OSVER unknown error" 192 ;;
	esac
	return 1
} # END checkSystemVersion()


withTimeOut(){ # Resuable timeout function (could be call withRetry instead)
statusMessage header "FUNCTION: #	$FUNCNAME:$1:$2" ; unset EXITVALUE TRY
declare COMMAND="$1" TIMEOUT="$2" STRING="$3"
# Command to try, Number of trys and string to state at begining of re-loop.
declare -i FUNCSECONDS="$SECONDS" # Capture start time
until [ "${FUNCTIME:=0}" -ge "${TIMEOUT:?}" ]; do
	declare EXITVALUE=1
        declare -x TRYNUMBER=$(( ${TIMEOUT:?} - ${FUNCTIME:?} ))
	"${COMMAND:?}" && declare EXITVALUE=0 && break
	# The command is able to break the loop with a 0 return 
	[  "$(( ${FUNCTIME:?} % 2 ))" = 0 ] && # Every other try display status
		statusMessage notice "WAIT:$STRING:RETRY:$TRYNUMBER"
	if [ "${FUNCTIME:=0}" -ge "${GTIMEOUT:?}" ] ; then
		statusMessage error "Script reached global TIMEOUT $GTIMEOUT seconds"
		declare EXITVALUE=1 ; break
	fi
	"$sleep" 1 # Wait one second before restarting the loop
	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
done
[ "${FUNCTIME:?}" != 0 ] &&
statusMessage verbose "TIME:${FUNCNAME}:Took ${FUNCTIME} seconds to EXIT:${EXITVALUE:-1}"
unset TRYNUMBER
return "${EXITVALUE:-"1"}"
} # END withTimeOut()

# Used mainly for .local domains
addSearchDomain(){
	declare SEARCH_DOMAIN="$1"
	declare NETWORK_SERVICES="$($networksetup listallnetworkservices 2>1 |
	                                $awk 'BEGIN{getline}
	                                # Get rid of the first line
	                                { gsub(/\*/,"",$0)
	                                # Remove the * from any line so the name matches
	                                print $0}')"
	OLDIFS="$IFS"
	IFS=$'\n'
	     for SERVICE in ${NETWORK_SERVICES}; do
	        $networksetup -setsearchdomains "${SERVICE:?}" "${SEARCH_DOMAIN:?}"
	             sleep 0.5       # Wait for SC
	     done
	echo $SECONDS
	IFS="$OLDIFS"

}

checkSearchDomain(){
statusMessage header "FUNCTION: #       $FUNCNAME" ; unset EXITVALUE
declare -i FUNCSECONDS="$SECONDS" # Capture start time
declare awk="${awk:="/usr/bin/awk"}"
if $awk 'BEGIN{{
        dns=ENVIRON["DNS_SUFFIX"]
        if ( dns!~/.local/)
                { exit 0 }
        else if ( dns~/.local/)
                { exit 1 }
        }}' ; then
        statusMessage passed "DNS SUFFIX check ($DNS_SUFFIX)"
else
        statusMessage notice "DNS SUFFIX contains .local ($DNS_SUFFIX)"
	if [ -f /etc/resolv.conf ] ; then
	for DOMAIN in $($awk '/^search/{gsub(/^search /,"",$0);print}' /etc/resolv.conf) ; do
			if [ "$DOMAIN" = "$DNS_SUFFIX" ] ; then
				return 0
			else
				continue					
			fi
	done
	fi
	return 1
fi
}

checkNetwork() {
	statusMessage header "FUNCTION: #	$FUNCNAME" ; unset EXITVALUE
	declare -i FUNCSECONDS="$SECONDS" # Capture start time
	# Function required commands
	declare awk="${awk:="/usr/bin/awk"}"
	declare ipconfig="${ipconfig:="/usr/sbin/ipconfig"}"

	declare AIR_CHECK="$("$sysctl" hw.model | 
		"$awk" 'BEGIN {}
		$2~/.*(a|A)ir.*/{
		# RegEx any thing with Air,basic but works
		print "YES" ; exit 0 }
		# If we did not exit then not an AIR
		{print "NO" ;exit}')"

	if [ "$AIR_CHECK" = YES ] ; then
		if [ "${#ENOVERRIDE}" -eq 0 ] ; then
			export ENOVERRIDE=1
		fi
		statusMessage notice "Found MacBook Air Overriding Default name interface"
	
	fi
	statusMessage progress "NETWORK: Begining network check..."
		statusMessage graphical \
	"Begining network check , ensure that machine is connected to the network and IP set"
	"$ipconfig" waitall # Block until the stack comes up, almost always exits 0

for N in ${EN[@]} ; do # For all interfaces in the array such as 0,1,2
	declare -a EN[N]=$("$ifconfig" "en$N" 2>/dev/null |
	"$awk" 'BEGIN {}
	$0~/^.*\tstatus/{
	# For current line, it tab media
	if ( $NF == "inactive" )
	{ print $NF ; exit 0 }
	else if ( $NF == "active" )
	{ print $NF; exit 1 }
	}')
	# Determine if Interface is active/inactive
	declare -a MAC[N]=$("$ifconfig" "en$N" ether  2>/dev/null |
	"$awk" 'BEGIN { FS="ether " }
	/^\tether /{
	ether=toupper($2)
	# Convert MAC addess to uppercase
	gsub(/:/,"",ether)
	gsub(" ","",ether)
	# Remove any white space
	print ether }
	END { exit 0 }')

	# Override for Lion	
	[ $N = $ENOVERRIDE ] && export EN0="${MAC[N]}"
	statusMessage verbose "Found MAC on en$N : ${MAC[N]}"
	
	if [ "${EN[N]}" = "inactive" ] ; then
		statusMessage notice "SKIP: en$N is ${EN[N]}"
		# Catch for Airs with Ethernet devices
	fi
	
	declare -a IP[N]=$("$ipconfig" getifaddr "en$N" 2>/dev/null |
	"$awk" 'BEGIN { FS="." }
	$0~/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/{ ip=$0
	# Regex the inet line, not a huge amount of validation.
	if ( NF = 4 )
		{ print ip }
	# If the number of fields match then print
	} END { exit 0 }')
	# Determine en$N's IP address
	# Check for link local IPs
	
	[[ "${IP[N]}" == 169.254.[0-9]*.[0-9]* ]] &&
	statusMessage error "en$N has self assigned IP:${IP[N]}"

	statusMessage verbose "Found IP: ${IP[N]} on en$N"
	if [ -n "$EN0" ] ; then # Overide automatic interface if $EN0 is not null
		declare MAC="$EN0" # Always use name from EN0
	else
		declare MAC="${MAC[N]}"	# Use name from interface found first
	fi
	statusMessage progress "Using MAC string: ${MAC}"
	statusMessage progress "Found IP: ${IP[N]} for site resolution"
		
	export IPADDR="${IP[$N]}" MACADDR="${MAC}" ENX="en$N"
	# Failure protection
	[ -n "$IPADDR" ] || export IPADDR="0.0.0.0"
	[ -n "$MACADDR" ] || export MACADDR="$RANDOM"
	[ -n "$ENX" ] || export IPADDR="en1"

	declare EXITVALUE="0"
	break
	done

	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "${FUNCTIME:?}" -gt 0 ] &&
	statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds to EXIT:$EXITVALUE"
	return ${EXITVALUE:-"1"}
} # END checkNetwork()

# Check script options
statusMessage header "GETOPTS: Processing script $# options:$@"
# ABOVE: Check to see if we are running as a postflight script,the installer  creates $SCRIPT_NAME
[ $# = 0 ] && statusMessage verbose "No options given"
# If we are not running postflight and no parameters given, print usage to stderr and exit status 1
if [[ "$@" = -* ]] ; then
	 statusMessage verbose "Detected command line arguments"
	while getopts lo:O:a:Ci:kvn:N:u:p: SWITCH ; do
		case $SWITCH in
			p ) export ADBINDPASS="${OPTARG}" ;;
			u ) export BindAccount="${OPTARG}" ;;
			v ) export LOGLEVEL="VERBOSE" ;;
			C ) export ENABLECOLOR="YES" ;;
			N ) export CLI_NAME_FORMAT="${OPTARG}" ;;
			n ) export CLI_CUSTOM_NAME="${OPTARG}" ;;
			k ) export KEEP_CURRENT_NAME='YES' ;;
			i ) export OVERRIDEIP="${OPTARG}" ;
			[ "${#OVERRIDEIP}" -gt 0 ] || ([[ "$OVERRIDEIP" = -* ]] &&
			die "GETOPTS" "IP addess not specified" 1);;
			O ) export ODBIND_OVERRIDE="${OPTARG}";;
			a ) export ADBIND_OVERRIDE="${OPTARG}";;
	esac
done # END getopts
else
	 statusMessage verbose "No command line arguments detected , using posistional parameters"
	export OVERRIDEIP="$4"
fi

guessTagFromName(){ # Attempt to derive Asset tag from name format

	statusMessage header "FUNCTION: #       ${FUNCNAME}" ; unset EXITVALUE TRY
	declare awk="${awk:="/usr/bin/awk"}" scutil="${scutil:="/usr/sbin/scutil"}"
	declare nvram="${nvram:="/usr/sbin/nvram"}"
        declare -x NAME_ASSET_TAG="$( $scutil --get "$NAME_SOURCE"|
                $awk -F"[$NAME_DELIMITER]" "{print $NAME_POSTITION; exit}")"

        if [ -z "$NAME_ASSET_TAG" ] ; then
                statusMessage notice "No Asset Tag found"
                return 1
        else
                statusMessage notice "Found asset tag in name:$NAME_ASSET_TAG"
                export ASSET_TAG="$NAME_ASSET_TAG"
                return 0
        fi
}

# Set tag in firmware
setTagInFW(){
        declare ASSET_TAG="$1"
        $nvram "${ASSET_TAG_KEY:?}"="${ASSET_TAG:?}" 2>/dev/null
        return 0
}
# Set tag in ARD
setTagInARD(){
        declare ASSET_TAG="$1"
        declare N="${ASSET_TAG_ARD:?}"
        $kickstart -configure -computerinfo "-set$N" "-$N" "${ASSET_TAG:?}"
        return 0
}


killDirectoryService(){ # SIGTERM the DirectoryService Daemon
	statusMessage header "FUNCTION: #       ${FUNCNAME}" ; unset EXITVALUE TRY
	# Function Commands
	declare ps="${ps:=/bin/ps}" id="${id:=/usr/bin/id}" awk="${awk:=/usr/bin/awk}"
	declare killall="${killall:=/usr/bin/killall}" sleep="${sleep:=/bin/sleep}"
	# Runtime Varibles
	declare -i FUNCSECONDS="$SECONDS" # Capture start time
	declare -i WAIT_FOR_DS=60 # DirectoryService can take a while to reload
	# Lion Override
	if [ "$OS" = 'N' ] ;then
		declare -i OLDDSPID=$("$ps" -awxx |
			"$awk" '$NF~/[o]pendirectoryd$/{ print $1;exit}')
	        statusMessage progress "TERM: Restarting opendirectoryd deamon PID:$OLDDSPID"
	        "$killall" opendirectoryd # Main function command
	else
		declare -i OLDDSPID=$("$ps" -awxx |
		        "$awk" '$NF~/[D]irectoryService$/{ print $1;exit}')
		statusMessage progress "TERM: Restarting DirectoryService deamon PID:$OLDDSPID"
		"$killall" DirectoryService # Main function command
	fi

	until [ "${DSPID:-0}" -gt 0 ] ; do # Until the DirectoryService daemon is visible
		let "TRY++" # Start the TRY count
		"$id" root &>/dev/null || statusMessage error "User resolution failed"
		[  "$(( ${TRY:?} % 2 ))" = 0 ] &&  # Every other try show a notice
		statusMessage notice "WAIT:Waiting for DirectoryService to (re)start:$TRY"
		"$sleep" 1 # Wait 1 second for to reassign the DSPID varible
		# Lion overide
		if [ "$OS" = 'N' ] ;then
       		 	declare -i DSPID=$("$ps" -awxx |
        	        	"$awk" '$NF~/[o]pendirectoryd$/{ print $1;exit}')
		else
        		declare -i DSPID=$("$ps" -awxx |
        	        	"$awk" '$NF~/[D]irectoryService$/{ print $1;exit}')
		fi
		# Reset the varible for the next until loop
		if [ "${DSPID:?}" != "${OLDDSPID:?}" ] ; then # Directory Service Deamon restarted in process table
			statusMessage progress "DirectoryService/opendirectoryd successfully restarted PID:$DSPID"
			declare EXITVALUE=0 ; break
		fi
		[ "${TRY:?}" == "${WAIT_FOR_DS:?}" ] && return 1
	# If timeout is reached then exit unsuccessfully
	done # END until 

	if [ ${DSPID:?} == ${OLDDSPID:?} ] ; then # If they are the same then TERM did not work
		statusMessage error "DirectoryService did not restart $DSPID:$OLDDSPID"
		declare EXITVALUE=1
	fi

	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "${EXITVALUE:-1}" = 0 ] ||
		statusMessage error "Unable to kill DirectoryService/opendirectoryd" 
	[ "${FUNCTIME:?}" -gt 0 ] &&
		statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds EXIT:$EXITVALUE"
	"$id" "$$" &>/dev/null # here to try and jumpstart DirectoryService
	return ${EXITVALUE:-1}
} # END killDirectoryService()	


setMachineType(){ # This funciton users ioreg to pull the machine type integer
statusMessage header "FUNCTION: #	${FUNCNAME}" ; unset EXITVALUE
declare -i FUNCSECONDS="$SECONDS" # Capture start time
declare ioreg="${ioreg:="/usr/sbin/ioreg"}" awk="${awk:="/usr/bin/awk"}"
declare sysctl="${sysctl:="/usr/sbin/sysctl"}"
# Intel and future systems test
declare IOREG="$("$ioreg" -l |
	"$awk" 'BEGIN {FS="[<>]"}
	/.*\"system-type\".=./{
	systype=$2
	if ( systype == 1 )
		{ print "D" ; exit 0 }
	# System type 1 is a Desktop
	else if ( systype == 2 )
		{ print "L" ; exit 0 }
	# System type 2 is a Laptop
	}')"

# PowerPC test , hopefully can go aways some day
declare SYSCTL="$("$sysctl" hw.model | 
	"$awk" 'BEGIN {}
	$2~/.*(b|B)ook.*/{
	# RegEx any thing with Book,basic but works
	print "L" ; exit 0 }
	# If we did not exit then desktop
	{print "D" ;exit}')"
	
	# Declare "L" or "D" depening on the tests above 
	if [ -n "$IOREG" ] ; then
		export LD="$IOREG" ; declare EXITVALUE=0
	elif [ -n "$SYSCTL" ] ; then
		export LD="$SYSCTL" ; declare EXITVALUE=0
	else
		statusMessage error "Unable to lookup Mac type"
		declare EXITVALUE=1
	fi
	# U for Unknown, not used anywhere but here
	[ ${LD:-"U"} == "D" ] && declare EXITVALUE="0" &&
	statusMessage verbose "MACTYPE:${LD:?}: This Machine is a desktop"
	[ ${LD:-"U"} == "L" ] && declare EXITVALUE="0" &&
	statusMessage verbose "MACTYPE:${LD:?}: This Machine is a Laptop"

	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "$FUNCTIME" -gt 0 ] &&
statusMessage verbose "TIME:${FUNCNAME}:Took ${FUNCTIME} seconds:$EXITVALUE"
return ${EXITVALUE:-0}
} # END setMachineType()

setNetworkTimeServer(){ # This sets the network time servers.
statusMessage header "FUNCTION: #	$FUNCNAME" ; unset EXITVALUE
declare -i FUNCSECONDS="$SECONDS" # Capture start time
	declare NTPSERVER="$1" NTPTIMEOUT="$3"

	[ -f "$systemsetup" ] || 
		declare systemsetup="${RUNDIRECTORY}/systemsetup"
	# If you add systemsetup to your package installer you can use it here.
	[ -f "/usr/sbin/systemsetup" ] &&
		declare systemsetup="/usr/sbin/systemsetup"
	# Command override check for 10.5's version of systemsetup and overide the ARD

	"$systemsetup" -setusingnetworktime off  >> "${SCRIPTLOG:?}"  # Shut off just in case of timeouts
	"$systemsetup" -setnetworktimeserver "${NTPSERVER:?}"  >> "${SCRIPTLOG:?}" &&
	# We will manually update from NTPServer 1 as well if there is a bind failure
	# Status Message block
	statusMessage progress "Configured Time Servers:" &&
	statusMessage progress "NTP: Primary :$NTPSERVER" &&

	# Set the NTP Servers, failover to time.apple.com if not set.
	"$systemsetup" -setusingnetworktime on  >> "${SCRIPTLOG:?}" ; declare EXITVALUE=0
	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
[ "$FUNCTIME" -gt 0 ] && statusMessage verbose "TIME:${FUNCNAME}:Took ${FUNCTIME} seconds"
return ${EXITVALUE:-0} 
} # END setNetworkTimeServer()

genComputerName(){
statusMessage header "FUNCTION: #       ${FUNCNAME}" ; unset EXITVALUE
declare -x ASSET_TAG="$($nvram -p "$ASSET_TAG_KEY" |
                        $awk '/^asset-tag/{print $NF;exit}')"
# Update the tag in firmware and ARD
if [ -z "$ASSET_TAG" ] ; then
	guessTagFromName && setTagInFW "${ASSET_TAG:?}" &&
	if [ "$SET_TAG_IN_ARD" = "YES" ] ; then
		setTagInARD "$ASSET_TAG"
	fi
fi
export COMPNAME="$("$awk" 'BEGIN {{
	format=ENVIRON["NAME_FORMAT"]
	# Read in the format varible
	assettag=ENVIRON["ASSET_TAG"]
	gsub("%a",assettag,format)
	macaddr=ENVIRON["MACADDR"]
	gsub("%m",macaddr,format)
	# sub Mac Address for %m
	ld=ENVIRON["LD"]
	gsub("%c",ld,format)
	# sub the Computer type for %c
	os=ENVIRON["OS"]
	gsub("%o",os,format)
	# sub the OS version type for %o
	delimiter=ENVIRON["DELIMITER"]
	gsub("%d",delimiter,format)
	# sub the Delimter type for %d
	sitename=ENVIRON["SITENAME"]
	gsub("%s",sitename,format)
	# sub the Site Name for %s
	customname=ENVIRON["CUSTOM_NAME"]
        gsub("%n",customname,format)
	format=toupper(format)
	# Make upper case
 	print format}}')"

       # Double check for server
	# Disabled for Lion as Client can have server installed
#	if [ -f '/System/Library/CoreServices/ServerVersion.plist' ] ; then
#	  	statusMessage notice "Server Detected using current hostname:$($hostname)"
#	  	export COMPNAME="$($hostname -s)" 
#	fi

	statusMessage progress "Assembled Computer name: ${COMPNAME:?}"
	export ADCOMPNAME="$("$awk" 'BEGIN {
	adname=ENVIRON["COMPNAME"]
	gsub(" ","-",adname)
	# Change any spaces to - to follow old DNS conventions
	{adname=tolower(adname)}
	# Make lowercase ,as the plugin will anyway when we bind
	{adname=substr(adname,1,15)}
	# Trunicate the name to 15 Characters per basename standards
 	{print adname}}')"
	declare CURRENTCOMPNAME="$( "$dsconfigad" -show |
		"$awk" 'BEGIN { FS=" = " }
		$0~/^.*Computer Account/{
		# Find the Computer Account Domain line
		sub(" ","",$2) # Remove white space
		currentcompname=$2
		if ( currentdomain == ENVIRON["ADCOMPNAME"] )
			{print currentcompname ; exit 0 }
		else
		        {print currentcompname ; exit 1 }
		}')"
		statusMessage verbose "Assembleing name with format:$NAME_FORMAT"
		if [ "${AD_KEEP_NAME}" = "YES" ] ; then
			if [ "${CURRENTCOMPNAME:="$ADCOMPNAME"}" != "${ADCOMPNAME:-"none"}" ] ; then
				export ADCOMPNAME="$CURRENTCOMPNAME"
				export COMPNAME="$CURRENTCOMPNAME"
				statusMessage notice "COMPNAME: Old name:${CURRENTCOMPNAME} does not match:${ADCOMPNAME}"	
				statusMessage notice "Setting new name to old name"
			fi
		fi
}

setComputerNames(){ # Set the local "Mac" computer names
statusMessage header "FUNCTION: #	${FUNCNAME}" ; unset EXITVALUE
	declare -i FUNCSECONDS="$SECONDS" # Capture start time
	declare scutil="${scutil:="/usr/sbin/scutil"}"
	statusMessage verbose "Set AD computer name to:$ADCOMPNAME"
	"$scutil" --set LocalHostName ${COMPNAME:?} >> "${SCRIPTLOG:?}" &&
		statusMessage passed "LOCALHOSTNAME: set to ${COMPNAME:?}.local"
	"$scutil" --set ComputerName "${COMPNAME:?}" >> "${SCRIPTLOG:?}" &&
        	statusMessage passed "COMPUTERNAME: set to ${COMPNAME:?}"
	"$scutil" --set HostName "${ADCOMPNAME:?}.${DNS_SUFFIX:?}" >> "${SCRIPTLOG:?}" &&
        	statusMessage passed "HOSTNAME: set to ${COMPNAME:?}"
	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
[ "$FUNCTIME" -gt 0 ] &&
	statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds"
return 0
} # END setComputerNames()

setADTimeout(){ # Modified from Philip Rinehart's python script on macenterprise
	statusMessage header "FUNCTION: #	${FUNCNAME}" ; unset EXITVALUE
	declare ADTIMEOUT=$1
	declare plutil="${plutil:="/usr/bin/plutil"}"
	declare python="${python:="/usr/bin/python"}"
	declare file="${file:="/usr/bin/file"}"

	if [ -d "$LION_DSDIR" ] ; then
		OLDIFS="$IFS"
		IFS=$'\n'
		for AD_SERVER in "${LION_DSDIR}"/*.plist ; do
			export ADPLIST="$AD_SERVER"
		done
	fi


	# Check file XML format and convert if nes 
	declare -i XML_FILE="$($file "$ADPLIST" |
				$awk '/XML/{seen++}END{print seen}')"

	if [ "$XML_FILE" -eq 0 ]; then
		$plutil -convert xml1 "$ADPLIST"
		declare -i NEEDS_CONVERT=1
	else
		declare -i NEEDS_CONVERT=0
	fi
# Set the time out for Tiger Systems
"$python" <<EOF
import plistlib
import sys
import os
adtimeout = (os.environ["ADTIMEOUT"])
adplist = (os.environ["ADPLIST"])
osver = (os.environ["OS"])
try:
        plist = plistlib.Plist.fromFile(adplist)
        # Lion
        if osver == "N" :
                plist['options']['query timeout'] = int(adtimeout)
        # Snow Leopard
        if osver == "S" :
                plist['LDAP Connection Timeout'] = adtimeout
        # Leopard
        if osver == "L" :
                plist['LDAP Connection Timeout'] = adtimeout
        # Tiger Code
        if osver == "T" : 
                for key in plist['AD Domain Node List']:
                        plist['AD Domain Node List'][key]['LDAP Connection Timeout'] = adtimeout

except IOError, (strerror):
        print strerror
except:
        print "Unexpected error:", sys.exc_info()[0]
plist.write(adplist)
EOF
	declare -i EXIT_VALUE=$?
	if [ "$NEEDS_CONVERT" -eq 1 ]; then
		$plutil -convert binary1 "$ADPLIST"
	fi
	return "$EXIT_VALUE"
} # END setADTimeout()

verifyDNSConfig(){ # This is a sub function of checkDNS()
statusMessage header "SUB:FUNCTION: #       ${FUNCNAME}" ; unset EXITVALUE
# Validate the DNS configuration by checking /etc/resolv.conf for our variables
declare -i FUNCSECONDS="$SECONDS" # Capture start time
if [ -f "/etc/resolv.conf" ] ; then # /etc/resolv.conf does not always exist
	"$awk" 'BEGIN { FS="^nameserver " }
	$2~/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/{ 
	ip=$2 # Regex the inet line, with out a huge amount of IP validation
	if ( ip == ENVIRON["ADDNS1"] )
		{ print "MATCH IP:",ip,"in /etc/resolv.conf" ; exit 0  }
	else if ( ip == ENVIRON["ADDNS2"]  )
		{ print "MATCH IP:",ip,"in /etc/resolv.conf" ; exit 0  }
	else
	    {  exit 1 }}' "/etc/resolv.conf" >>"${SCRIPTLOG:?}" || return 1
	
	statusMessage passed "Configured DNS Servers match" ; return 0
else
        statusMessage error "No DNS Servers configured" ; return 1
fi
declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
[ "$FUNCTIME" -gt 0 ] &&
	statusMessage verbose "TIME:${FUNCNAME}:Took ${FUNCTIME} seconds"
return 0 
} # END verifyDNSConfig()


checkDNS(){ # Main Check DNS function and fix routine, calls verifyDNSConfig
statusMessage header "FUNCTION: #	${FUNCNAME}" ; unset EXITVALUE
declare -i FUNCSECONDS="$SECONDS" # Capture start time
until verifyDNSConfig ; do
statusMessage error "System's primary DNS does not match:$ADDNS1"
statusMessage error "System's primary DNS does not match:$ADDNS2"

declare ENNAME="$("$networksetup" -listnetworkserviceorder 2>/dev/null |
	"$awk" 'BEGIN{ FS="(:" " |," ")" }
	$0~/^\(Hardware.*/{ # Dont list disabled interfaces, or order
	gsub(/^\(|\)$/,"",$0)
	# Remove pesky () from begining and end of lines
	en=$NF # This field will be the en0,en1, etc
	if ( en == ENVIRON["ENX"] )
		{ print $(NF -2) ; exit 0 }}')"
statusMessage verbose "Attempting to repair DNS configuration..."
# Check the DHCP supplied DNS Server by extracting the Offer packet
if [ -n "$("$ipconfig" getpacket "${ENX:?}")" ] ; then	
	statusMessage verbose "Interface: ${ENX:?} is using DHCP"
	"$ipconfig" getoption "${ENX:?}" domain_name_server  |
	"$awk" 'BEGIN {}
	$0~/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/{
	# Basic IP validation, not much more needed
	dhcpdns=$0
	if ( dhcpdns == ENVIRON["ADDNS1"] )
		{ print "MATCH IP:",dhcpdns,"in DHCP packet" ; exit 0  }
	else if ( dhcpdns == ENVIRON["ADDNS2"] )
		{ print "MATCH IP:",dhcpdns,"in DHCP packet" ; exit 0  }
	else
	{	print "DHCP:Server is handing out address:",dhcpdns
		exit 1
	}
	}' >>"${SCRIPTLOG:?}" || statusMessage error "DHCP lease not contain correct DNS Server(s)"
	statusMessage verbose "DHCP server packet matches primary DNS"
	# If we did short circuit above , then blank out any statuc DNS entries
	statusMessage notice "Removing static DNS Servers from $ENX"
	"$networksetup" -setdnsservers "${ENNAME}" "Empty"
	statusMessage notice "Attempting DNS check again..."
	continue # try again now that we cleared the static items
	# TODO: Need to check for Option 95 servers, for LDAP check
else
	statusMessage notice "Interface: ${ENNAME} has static DNS servers"
	statusMessage notice "Attempting to contact:${ADDNS1:?}"
	checkHostReachable "${ADDNS1:?}" "${ADTIMEOUT:?}" || return 1
	statusMessage notice "Manually configuring DNS:${ADDNS1:?},${ADDNS2:?}"
	"$networksetup" -setdnsservers "${ENNAME}" "${ADDNS1:?}" "${ADDNS2:?}" || return 1
	continue # try again now that we have statically set the servers
fi
if [ "${FUNCTIME:-0}" -ge "${GTIMEOUT:?}" ] ; then
	statusMessage error "verbose Script reached global TIMEOUT $GTIMEOUT seconds"
	declare EXITVALUE=1 ; break
fi
"$sleep" 1
done
statusMessage passed "DNS servers are configured correctly"
declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
[ "$FUNCTIME" -gt 0 ] &&
statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds:$EXITVALUE"
return "${EXITVALUE:=0}"
} # END checkDNS()

setGChost(){ # Pull the Global Catalog and export for later functions
statusMessage header "FUNCTION: #	${FUNCNAME}" ; unset EXITVALUE
# Function Commands
declare awk="${awk:=/usr/bin/awk}" host="${host:=/usr/bin/host}"
declare -i FUNCSECONDS="$SECONDS" # Capture start time

declare ADDOMAIN="$1"
statusMessage verbose "DNS: lookup of GC for $ADDOMAIN"
export GCHOST="$("$host" -t SRV _gc._tcp."${ADDOMAIN:?}" |
	"$awk" 'BEGIN {}
	$1~/^_gc._tcp..*/{
	gc=$NF # Get the last field
	if ( NF = 8 )
		{ print gc ; exit 0}
	else
		{ print gc ;exit 1}
	}')"

if [ -n "$GCHOST" ] ; then
	statusMessage passed "FOUND: Global Catalog Server: $GCHOST"
	declare -i EXITVALUE=0	
else
	statusMessage error "DNS: Could not resolve GC for domain:	$ADDOMAIN"
	declare -i EXITVALUE=1
fi
declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
[ "$FUNCTIME" -gt 0 ] &&
	statusMessage verbose "TIME:${FUNCNAME}:Took ${FUNCTIME} seconds:$EXITVALUE"
return ${EXITVALUE:-0}
} # END setGChost()

checkHostReachable(){
statusMessage header "FUNCTION: #	$FUNCNAME" ; unset EXITVALUE TRY
declare HOSTTOCHECK="$1" 
declare -i FTIMEOUT="$2"
declare -i FUNCSECONDS="$SECONDS" # Capture start time
declare scutil="${scutil:="/usr/sbin/scutil"}" awk="${awk:="/usr/bin/awk"}"

# Begin specfic host check
until "$scutil" -r "${HOSTTOCHECK:?}" |
	"$awk" 'BEGIN { FS=","}
	$1~/^Reachable/{ 
	if ( $3 == "Connection Required")
        	{ exit 1 }
	# scutil can test if a conneciton is required i.e VPN or PPP
	else if ( $2 == "Connection Required" )
		{ exit 1 }
	# scutil can test if a conneciton is required i.e VPN or PPP
	else if ( $1 == "Reachable" )
        	{ exit 0 }
	}
	$1~/^Not Reachable/{
	if ( $1 == "Not Reachable" )
        { exit 1 }}'
do # Parse the scutil output for checking if the host is reachable
# I wish apple would check their exit statuses so this could be used outside
declare CURRENT_RETRY=$((${FTIMEOUT} - ${TRY:-0}))
statusMessage notice "Waiting for $HOSTTOCHECK to become Reachable RETRY:$CURRENT_RETRY"
        let "TRY++" # Add one to the TRY, status message acutally set it 0 for us above.
        "$sleep" 1
        if [ "${TRY:?}" == "${FTIMEOUT:?}" ] ;  then
                statusMessage error "Timed out waiting for $HOSTTOCHECK"
		return 1
        fi
done
statusMessage passed "CHECK: $HOSTTOCHECK is Reachable"
return 0 
} # END checkHostReachable()

checkBinding(){ # Check AD binding by using the WINNT domain as lookup 10.4/10.5 
	statusMessage header "FUNCTION: #	$FUNCNAME" ; unset EXITVALUE TRY
	declare -i FUNCSECONDS="$SECONDS" ; unset  EXITVALUE # Capture start time
	declare FTIMEOUT="30"
	declare lookupd="${lookupd="/usr/sbin/lookupd"}"
	declare dscacheutil="${dscacheutil:="/usr/bin/dscacheutil"}"
	[ -x "$lookupd" ] && declare oscacheutil="${lookupd}"
	[ -x "$dscacheutil" ] && declare oscacheutil="${dscacheutil}"
	# 10.5 overide for dscacheutil
        declare USER_TEST="${ADBINDUDN:?}"	
	# Active Directory
	if [ "$ADBIND" = "YES" ] ; then
	until "$id" "$USER_TEST" &>/dev/null ; do 
		let "TRY++"
		# Updated for Lion
		[ "${TRY}" = 2 ] &&
		"$dscl" localhost changei /Search CSPSearchPath 1 "/Active Directory/${ADDOMAIN:?}" 2>/dev/null |
				"$dscl" localhost changei /Search CSPSearchPath 1 "/Active Directory/${ADDOMNT:?}"
		if [ "${TRY:?}" -ge  "${FTIMEOUT:?}" ] ;  then
	       		statusMessage error "Timed out using: \"$id $USER_TEST\""
	       		declare ADEXIT=1 ; break

	       elif [ "${FUNCTIME:-0}" -ge "${GTIMEOUT:?}" ] ; then
       			statusMessage error "verbose Script reached global GTIMEOUT $GTIMEOUT seconds"
	       		declare ADEXIT=1 ; break
	       fi
		if [  "$(( ${TRY:-0} % 2 ))" = 0 ] ; then # Every other loop
			statusMessage verbose "Waiting for user resolution:TRY:$(( ${FTIMEOUT} - ${TRY:-0} ))"
			"$oscacheutil" -flushcache &&
		        statusMessage verbose "FLUSH: Cleared user lookup cache"
			# Restart loop if successful in updating the index Number to 1 (top)
		fi
		"$id" "${ADDOMNT:?}"'\'"${ADBINDUDN:?}" &>/dev/null && break
		"$sleep" 5 # If we did not break above, sleep and retry loop
		done
	else
        	declare ADEXIT=0
		# Used if only configuring Active Directory
	fi
	# Open Directory
	if [ "$ODBIND" = "YES" ] ; then
		declare ODEXIT="$("$dscl" "/LDAPv3/${ODSERVER[CONFIG]}" read /Users/root  UniqueID |
		"$awk" 'BEGIN{FS=": "}$2~/[0-9]+/{print "0"}')"
		# Much less complicated test for Open Directory, just find the LDAP root users UID
		[ "${ODEXIT:-1}" = 0 ] && statusMessage progress "Open Directory user resolution verified" 
	else
		declare ODEXIT=0
		# here in case we want to ditch OD as some point
	fi
	if "$id" $USER_TEST &>/dev/null ;  then
		statusMessage passed "Active Directory binding verified!"
		declare ADEXIT=0
	fi
	[ ${ADEXIT:-1 } = 0 -a "$ADBIND" = "YES" ] &&
		statusMessage progress "Active Directory user resolution verified"
	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "$FUNCTIME" != 0 ] &&
		statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds $EXITVALUE"
	return "$(( ${ODEXIT:-1} + ${ADEXIT:-1} ))" #If either fail its 1+, otherwise 0
} # END checkBinding()

flushMCX(){
	statusMessage header "FUNCTION: #	$FUNCNAME" ; unset EXITVALUE TRY
	declare -i FUNCSECONDS="$SECONDS" ; unset  EXITVALUE # Capture start time
    ## Remove any cached preferences stored in /Library/Managed Preferences,
    ## Regardless of OS version.
    if [ -d "/Library/Managed Preferences" ]; then
    	"$rm" -r "/Library/Managed Preferences"
    fi
    
    ## If host version is tiger, use mcxcacher
    if [ "$OS" == "T" ]; then
    	statusMessage verbose "Flushing MCX for 10.4 Client"
        "$nicl" / -delete /config/mcx_cache
    	/System/Library/CoreServices/mcxd.app/Contents/Resources/MCXCacher -f
    
    
    ## If host is Leopard, manually clean out all remnants
    ## of cached MCX settings from our local directory services
    elif ([ "$OS" == "L" ] || [ "$OSVER" == "s" ]); then
    	[ "$OS" == "L" ] && statusMessage verbose "Flushing MCX for 10.5 Client"
        [ "$OS" == "S" ] && statusMessage verbose "Flushing MCX for 10.6 Client"

        ## Clean out computer MCX
        declare -x COMPUTERRECORDS="$("$dscl" . list /Computers)"
        for COMPUTER in $COMPUTERRECORDS; do
        	statusMessage verbose " - Flushing MCX for computer record:'$COMPUTER'"
		"$dscl" . delete /Computers/"$COMPUTER" MCXSettings
        	"$dscl" . delete /Computers/"$COMPUTER" MCXFlags
        	"$dscl" . delete /Computers/"$COMPUTER" cached_groups
        done
        
        ## Iterate through users, clean out MCX settings for all accounts
        declare -x USERACCOUNTS="$("$dscl" . list /Users | "$grep" -ve '^_' | "$grep" -ve root)"
        for USERACCOUNT in $USERACCOUNTS; do
        	## If we are 10.6, use mcxrefresh, otherwise clear out the settings
            ## manually using dscl
        	statusMessage verbose " - Flushing MCX for user account:'$USERACCOUNT'"
            if [ "$OS" == "S" ]; then
            	"$mcxrefresh" -n "$USERACCOUNT"
            elif [ "$OS" == "L" ]; then
                "$dscl" . delete /Users/"$USERACCOUNT" MCXSettings
                "$dscl" . delete /Computers/"$USERACCOUNT" MCXFlags
                "$dscl" . delete /Computers/"$USERACCOUNT" cached_groups
            fi
        done
    else
    	statusMessage verbose "Could not determine target OS from value:$OS"
        return 2
	fi
    
    statusMessage verbose " - Restarting DirectoryService/opendirectoryd"
    ## Restart the Directory services daemon
    killDirectoryService
    
	statusMessage verbose "MCX Flush Complete!"
	
	if [ "$JAMF_MIGRATE" = "YES" ] ; then # Set this to yes to remove OD binding, and refresh MCX
   		statusMessage verbose "Telling Jamf Binary to refresh MCX"
		$jamf mcx >> "$SCRIPTLOG"
	fi

	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "$FUNCTIME" != 0 ] &&
		statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds $EXITVALUE"
	return 0
} ## end flushMCX()


setCustomSearchPath(){
	statusMessage header "FUNCTION: #       $FUNCNAME" ; unset EXITVALUE TRY
	declare -i FUNCSECONDS="$SECONDS" # Capture start time
	for SPATH in /Search /Search/Contacts ; do
		declare SEARCHPOLICY="$("$dscl" "$SPATH" -read / |
			"$awk" 'BEGIN{ FS=":" }/^SearchPolicy/{
			gsub("^ ","",$NF) # Remove any spaces in 10.4
			searchpolicy=$NF  # Last field on either OS 
			$NF~/^(C|L|N)SPSearchPath/
				{ print searchpolicy; exit 0 }}')"
		case "${SEARCHPOLICY}" in
			CSPSearchPath	) \
			statusMessage verbose "$SPATH is already set as Custom" ; continue;;
			LSPSearchPath	) \
			statusMessage notice "$SPATH: is using Local Search path"	;;
			NSPSearchPath 	) \
			statusMessage notice "$SPATH: is using Automatic Search path"	;;
			*	) \
			statusMessage notice "$SPATH: is unknown: ${SEARCHPOLICY}" ;return 1 ;;
		esac
		statusMessage notice "Attempting to change ${SPATH:?} to Custom Path"
		"$dscl" "$SPATH" -change / SearchPolicy "${SEARCHPOLICY:?}" CSPSearchPath &&
		statusMessage passed  "SUCCSESS: set ${SPATH:?} path to Custom"
	done
	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "$FUNCTIME" != 0 ] &&
		statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds $EXITVALUE"

	return 0 
} # END setCustomSearchPath()


removeSearchPath(){
	statusMessage header "FUNCTION: #       $FUNCNAME" ; unset EXITVALUE TRY
	declare defaults="${defaults:=/usr/bin/defaults}" dscl="${dscl:=/usr/bin/dscl}"
	declare -i FUNCSECONDS="$SECONDS" # Capture start time
	declare OLDIFS="$IFS"
	declare IFS=$'\n' # Change the field seperartor for Active Directory/All Domains
	if [ "${DSPLUGIN:-"$FUNCNAME"}" = 'plist' ] ; then
		# Plist rewrite at the end of a failed main loop
		"$defaults" write "${SEARCHPLIST%.plist}" delete 'Search Node Custom Path Array' &&
	        statusMessage notice "${SEARCHPLIST}: Deleted (Search Node Custom Path Array)"
		killDirectoryService
		return 0
	fi
	for SERVER in $("$dscl" localhost list "/${DSPLUGIN:?}") ; do
		[ "${SERVER}" = 'list: Invalid Path' ] && break
		statusMessage notice "Removing /${DSPLUGIN:?}/${SERVER:?} from SearchPath"
		declare AUTHSEARCHPATH="$("$dscl" /Search -read / |
			"$awk" '/^SearchPolicy:/{print $2 ; exit}')"
		"$dscl" /Search -delete / "${AUTHSEARCHPATH:?}" "/${DSPLUGIN:?}/${SERVER:?}" &&
			statusMessage progress  "Removed:/${DSPLUGIN:?}/${SERVER:?} from /Search"
	
		"$dscl" /Search/Contacts -delete / "${AUTHSEARCHPATH:?}" "/${DSPLUGIN:?}/${SERVER:?}" &&
			statusMessage progress  "Removed:/${DSPLUGIN:?}/${SERVER:?} from /Search/Contacts"
		set +xv
		declare IFS="$OLDIFS"
	done
	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "$FUNCTIME" != 0 ] &&
		statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds $EXITVALUE"
	return 0
} # END removeSearchPath()

removeBinding(){
	statusMessage header "FUNCTION: #       $FUNCNAME" ; unset EXITVALUE ; unset TRY
	declare -i FUNCSECONDS="$SECONDS" # Capture start time
	if [ -r "${ADPLIST:?}" -a "${DSPLUGIN:?}" == 'Active Directory' ] ; then
	if [ "$OS" == 'N' ] ; then
                        declare -i MACHINEISBOUND="$($ls "$LION_DSDIR"/*.plist 2>/dev/null | $wc -l)"
	else
			declare -i MACHINEISBOUND="$("$defaults" read "${ADPLIST%.plist}" 'AD Bound to Domain' 2>/dev/null )" # 1 = yes
	fi
		declare PREVIOUSDOMAIN="$("$defaults" read "${ADPLIST%.plist}" 'AD Default Domain' 2>/dev/null )"
		declare PREVIOUSCOMPNAME="$("$defaults" read "${ADPLIST%.plist}" 'AD Computer ID' 2>/dev/null)"
	elif [  "${DSPLUGIN:?}" == 'Active Directory' ]; then
		statusMessage notice "No previous Active Directory binding(plist) found"
		# If preference file does not exist then we have never bound before
	fi
	# Loop through all DS Plugin entries
	declare OLDIFS="$IFS"
	declare IFS=$'\n' # Change the field seperartor for Active Directory/All Domains
	# Open Directory
	if [ "${DSPLUGIN:?}" == 'LDAPv3' ] ; then
		# ABOVE: Remove all ldap servers, no way of removing DHCP supplied option 95 though
		for SERVER in $("$dscl" localhost list "/${DSPLUGIN:?}") ; do
			[ "${SERVER}" = 'list: Invalid Path' ] && break
			# LDAPv3 Plugin routine
			"$dsconfigldap" -f -r "${SERVER:?}" -u ${ODBINDADMIN:-"FORCEUNBIND"} -p "${ODBINDPASS:-"UNBIND"}" &&
				statusMessage passed "Removal of ${SERVER:?} ${DSPLUGIN:?} server appears successful"
		done
	# Active Directory
	elif [ "${DSPLUGIN:?}" == 'Active Directory' ] ; then
		# ABOVE: Active Directory Plugin routine , only used if already bound
		statusMessage verbose "Processing Active Directory Plugin"
		declare CURRENTDOMAIN="$("$dsconfigad" -show |
			"$awk" 'BEGIN { FS=" = " }
			$0~/^.*Active Directory Domain/{
			# Find the Active Directory Domain line
			sub(" ","",$2) # Remove white space
			currentdomain=$2
			if ( currentdomain == ENVIRON["ADDOMAIN"] )
				{ print currentdomain ; exit 0} # Exits NA
			else
			{ print currentdomain ; exit 1} # Exits NA
			}')"
		if [ ${#CURRENTDOMAIN} -eq 0 ] ; then
			statusMessage notice "dsconfigad -show returned no output"
			declare EXITVALUE=0
			return $EXITVALUE	
		fi
		declare CURRENTCOMPNAME="$( "$dsconfigad" -show |
			"$awk" 'BEGIN { FS=" = " }
			$0~/^.*Computer Account/{
			# Find the Computer Account Domain line
			sub(" ","",$2) # Remove white space
			currentcompname=$2
			if ( currentdomain == ENVIRON["ADCOMPNAME"] )
			{print currentcompname ; exit 0 }
			else
	       	 	{print currentcompname ; exit 1 }
			}')"
		# ABOVE: Read from dsconfigad,for active configuration
		statusMessage notice "BIND: System is already bound to ${ADDOMAIN}"

	if [ "${CURRENTDOMAIN}" == "${ADDOMAIN:?}" -o "${CURRENTDOMAIN}" == "${ADDOMNT}" ] ; then
		statusMessage notice "WAIT: Attempting un-bind with from ${ADDOMAIN}"
		statusMessage notice "DN:${ADBINDUDN} COMPNAME:${CURRENTCOMPNAME:="$PREVIOUSCOMPNAME"}"
		# Lion Updates	
		if [ "$OS" == 'N' ] ; then
			"$dsconfigad" -force -remove -username ${ADBINDUDN:?} -password "${ADBINDPASS:?}" >> "${SCRIPTLOG:?}" && break
			"$dsconfigad" -force -remove -username FORCEUNBIND -password NONE >> "${SCRIPTLOG:?}" && break
		else
			"$dsconfigad" -f -r -u ${ADBINDUDN:?} -p "${ADBINDPASS:?}" >> "${SCRIPTLOG:?}" && break 
			"$dsconfigad" -f -r -u FORCEUNBIND -p NONE >> "${SCRIPTLOG:?}" && break
		fi
		declare EXITVALUE=1
	else
		statusMessage notice "Current DOMAIN:${CURRENTDOMAIN} does not match ${ADDOMAIN:?}"
		if [ "$OS" == 'N' ] ; then
			"$dsconfigad" -force -remove -username FORCEUNBIND -password NONE >> "${SCRIPTLOG:?}" && break
		else
			"$dsconfigad" -f -r -u FORCEUNBIND -p NONE >> "${SCRIPTLOG:?}" && break
		fi
		declare EXITVALUE=0
		fi
	fi
	declare IFS="$OLDIFS"
	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "$FUNCTIME" != 0 ] && statusMessage verbose "TIME:${FUNCNAME}:Took ${FUNCTIME} seconds $EXITVALUE"
	return "${EXITVALUE:-0}"
} # END removeBinding()

addSearchpath(){
	statusMessage header "FUNCTION: #	${FUNCNAME}:/${DSPLUGIN}/${DIRSERVER}" ; unset EXITVALUE
	# Failover protection for LDAP server , if we have a CONFIG without a host
	declare -i FUNCSECONDS="$SECONDS" # Capture start time
	declare -i FUNCRETRY=7
	
	# Lion Updates
	if [ "$OS" == 'N' ]; then
		if [ "$DSPLUGIN" == 'Active Directory' ] ; then
			declare -x DIRSERVER="$ADDOMNT"
		fi
	fi
	declare -i PRENODES="$("$defaults" read "${SEARCHPLIST%.plist}" 'Search Node Custom Path Array' 2>/dev/null |
		"$awk" -F'[","]' '/^\(/{
		for(i=1;i<=NF;++i)
		if($i~/\//)num++}
		# Find the number of nodes
		# Using / as the criteria
		END{print num}')"
	declare AUTHORDER="$("$defaults" read "${SEARCHPLIST%.plist}" 'Search Node Custom Path Array' 2>/dev/null |
		"$awk" -F'[,]' 'BEGIN{RS="\""}{print $1}' | 
		"$awk" '/^\//{print $0}')" 
	statusMessage verbose "The current Search path is:"
	statusMessage verbose " ${AUTHORDER:-"No Servers Configured"}"
	declare AUTHSEARCHPATH="$("$dscl" /Search -read / | "$awk" '/^SearchPolicy:/{print $2 ; exit}')"
	# This gets around the change in formatting differences between 10.4 and 10.5
	# but its just for good measure and not really required as you can call the atr

	for (( try = 1 ; try <=$FUNCRETRY; try++ )) ; do # Loop as this somtimes does not happen
		statusMessage progress "Adding $AUTHSEARCHPATH /${DSPLUGIN}/${DIRSERVER} to search path:TRY:$try"
		"$dscl" /Search -append / "${AUTHSEARCHPATH:?}" "/${DSPLUGIN:?}/${DIRSERVER:?}" && return 0
		# We stop at this point if we successfully appended the path
		"$sleep" 1
	done # End for (try) loop

	statusMessage error "Appending /${DSPLUGIN:?}/${DIRSERVER:?} seems to have failed"
	statusMessage notice " Manually adding keys and restarting DirectoryService/opendirectoryd"
	if [ -w "${SEARCHPLIST:?}" ] ; then
		# Manually Add the Keys to the Directory Service Plist
	"$defaults" write "${SEARCHPLIST%.plist}" 'Search Policy' -int 3 && 
		statusMessage passed "Successfully updated SearchNodeConfig.plist:Search Policy:3"
	"$defaults" write "${SEARCHPLIST%.plist}" 'Search Node Custom Path Array' -array-add "/${DSPLUGIN:?}/${DIRSERVER:?}" &&
		statusMessage passed "Added SearchNodeConfig.plist:Search Node Custom Path Array:/${DSPLUGIN:?}/${DIRSERVER:?}"
		killDirectoryService ; "$sleep" 2 
	else
		statusMessage error "PLIST ${SEARCHPLIST:?} is not writable"
	fi
	for (( try = 1 ; try <=$FUNCRETRY; try++ )) ; do # Loop as this somtimes does not happen
		if "$dscl" localhost -read "/${DSPLUGIN:?}/${DIRSERVER:?}/Users" >/dev/null ; then
			statusMessage passed "Appending /${DSPLUGIN:?}/${DIRSERVER:?} appears successful"
			declare EXITVALUE=0
			break # If we can read the /Users record then break
		else
			statusMessage error "Failed to add search path"
			sleep 2 
			declare EXITVALUE=1
		fi
		"$sleep" $try
	done
	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "$FUNCTIME" != 0 ] &&
		statusMessage verbose "TIME:${FUNCNAME}:Took ${FUNCTIME} seconds $EXITVALUE"
	return ${EXITVALUE:-1}
} # END addSearchpath()


bindADServer(){
	statusMessage header "FUNCTION: #       ${FUNCNAME}" ; unset EXITVALUE
	declare -i FUNCSECONDS="$SECONDS" # Capture start time
	# To turn on DirectoryService debug logging during the bind:
	# /usr/bin/killall -USR 1 DirectoryService
	statusMessage progress "Starting bind with Active Directory"
	StatusMSG "dsconfig" "Starting bind with Active Directory" uistatus

export ADOU="$($awk 'BEGIN {{
	adou=ENVIRON["ADOU_FORMAT"]
	# Read in the ADOU format varible
	sitetype=ENVIRON["STYPE"]
	gsub("%t",sitetype,adou)
	# sub the Site Name for %s
	sitename=ENVIRON["SITENAME"]
	gsub("%s",sitename,adou)
	# sub the Site Name for %s
 	print adou}}')"
	statusMessage progress "ADOU:$ADOU"
	statusMessage progress "ADCOMPNAME:${ADCOMPNAME}:DN:${ADBINDUDN} DOMAIN:${ADDOMAIN}"
	declare ADMSG="$($dsconfigad -f -a ${ADCOMPNAME:?} -u ${ADBINDUDN:?} -p "${ADBINDPASS:?}" -domain "${ADDOMAIN:?}" -ou "${ADOU:?}" 2>&1)"
	# Parse the output while running the command, probobly the most important line.

	case "${ADMSG:-"No data was returned by dsconfigad"}" in
	# Parse dsconfig output , (strings `whereis dsconfigad`) if your curious
		Error:*passwo*invalid*	) statusMessage error "$ADMSG" ; return 1;;
		Error:*accoun*expired*	) statusMessage error "$ADMSG" ; return 1;;
		Error:*account*privil*	) statusMessage error "$ADMSG" ; return 1;;
		Error:*invalid*Domain*	) statusMessage error "$ADMSG" ; return 1;;
		Error:*unknown*reason*	) statusMessage error "$ADMSG" ;
		statusMessage progress "Failing over to  OU to CN=Computers,$ADBASEDN" ;
		export ADOU_FORMAT="CN=Computers,${ADBASEDN:?}" ; return 1 ;;
		Error:*variati*clocks*  ) statusMessage error "$ADMSG" ; 
			statusMessage notice "Updating Time via : ${NTPSERVER:?}";
		        "$ntpdate" -u "${NTPSERVER:?}" ; return 1 ;;
		# ABOVE: Only uptime the time (which takes time ) if we need it
		Error:*container*exist*  ) statusMessage error "$ADMSG" ;
			statusMessage progress "Failing over to  OU to CN=Computers,$ADBASEDN" ;
			export ADOU_FORMAT="CN=Computers,${ADBASEDN:?}" ; return 1 ;;
		# ABOVE: Fail over check for missing OU
		*computer*already*Bound* ) statusMessage error "$ADMSG" ;
			statusMessage error "Directory Service conflict, removing binding" ;
			"$dsconfigad" -f -r -u N -p A >> "${SCRIPTLOG:?}" ; return 1;;
		# ABOVE: For weird issues where Remove Binding function did not work
		Computer*successfully*	) statusMessage progress "$ADMSG" ;;
				*	) statusMessage notice "$ADMSG" ; "$sleep" 2;;
	esac
	StatusMSG "dsconfig" "Setting AD Configuration Options" uistatus

	# Set the Active Directory plugin options 
	"$dsconfigad" -mobile "${ADMOBILE:?}" >>"${SCRIPTLOG:?}" &&
		statusMessage passed "1:ADPLUGIN: mobile ${ADMOBILE}"
	"$dsconfigad" -mobileconfirm "${ADPREFCONFIRM:?}" >>"${SCRIPTLOG:?}" &&
		statusMessage passed "2:ADPLUGIN: mobileconfirm ${ADPREFCONFIRM}"
	"$dsconfigad" -alldomains "${ADALLDOMAIN:?}" >>"${SCRIPTLOG:?}" &&
		statusMessage passed "3:ADPLUGIN: alldomains ${ADALLDOMAIN}"
	"$dsconfigad" -localhome "${ADLOCALHOME:?}" >>"${SCRIPTLOG:?}" &&
		statusMessage passed "4:ADPLUGIN: localhome $ADLOCALHOME"
	"$dsconfigad" -useuncpath "${ADPREFUNCPATH:?}" >>"${SCRIPTLOG:?}" &&
		statusMessage passed "5:ADPLUGIN: useuncpath ${ADPREFUNCPATH}"
	"$dsconfigad" -shell "${ADPREFSHELL:?}" >>"${SCRIPTLOG:?}" &&
		statusMessage passed "6:ADPLUGIN: shell ${ADPREFSHELL}"
	"$dsconfigad" -protocol "${ADHOMEPROTO:?}" >>"${SCRIPTLOG:?}" &&
		statusMessage passed "7:ADPLUGIN: protocol ${ADHOMEPROTO}"
	"$dsconfigad" -groups "$ADDOMNT\\$ADADMIN" >>"${SCRIPTLOG:?}" &&
		statusMessage passed "8:ADPLUGIN: groups $ADDOMNT\\$ADADMIN"
	
	# TODO: Needs to be an array 
	declare DSCONFIGSHOW="DSCONFIGAD:$("$dsconfigad" -show |
		"$awk" '{getline;gsub(":","",$0);print $0;exit}')"
	# Just helpful for debug	
	# Use dsconfig to report for our statusMessage whether we are bound or not
	statusMessage progress "${DSCONFIGSHOW:-"ADBIND: An error occured"}"
	statusMessage progress "Waiting for DirectoryService to refresh"
	"$sleep" 3 # Somewhat arbitrary value , but better then a whole bunch of sleeps
        if [ "$OS" == 'N' ] ; then
                        declare -i MACHINEISBOUND="1"
        else
                        declare -i MACHINEISBOUND="$("$defaults" read "${ADPLIST%.plist}" 'AD Bound to Domain' 2>/dev/null )" # 1 = yes
        fi
	# ABOVE: Read directly from the Active Directory plist , 1 = yes
	# Read Directly from the plist to see if DirectoryService has wrote the keys
	if [ "${MACHINEISBOUND:?}" -ge 1 ] ; then
		statusMessage passed "Plist Preference successfully written: Bound"
		declare EXITVALUE=0
	elif [ "${MACHINEISBOUND:?}" = 0 ] ; then
		statusMessage error "Machine does not seem to have bound"
		StatusMSG "dsconfig" "Please wait, server not ready..." uistatus
		statusMessage notice "Initiating 2 second pause" ; "$sleep" 2
		declare EXITVALUE=1
	fi
	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "$FUNCTIME" != 0 ] &&
		statusMessage verbose "TIME:${FUNCNAME}:Took ${FUNCTIME} seconds $EXITVALUE"
	return ${EXITVALUE:-1} 
}

enablePlugin(){ # Enable the LDAP plugins
	statusMessage header "FUNCTION: #	${FUNCNAME}:${DSPLUGIN}" ; unset EXITVALUE
	declare -i FUNCSECONDS="$SECONDS" # Capture start time
	declare DSPLUGIN="$1"
	declare PLUGIN="$("$defaults" read "${DSPLIST%.plist}" "${DSPLUGIN:?}")"
	# [ -w "${DSPLIST:?}" ] || die ERROR "LINENUM:$LINENO:${DSPLIST} is not writable" 193
	if [ "${PLUGIN:-"PLUGIN"}" = 'Active' ] ; then
		declare EXITVALUE=0
	else
		[ "${PLUGIN:-"PLUGIN"}" = 'Inactive' ] &&
		statusMessage notice "Plugin ${DSPLUGIN} is inactive"
		# If plugin was not active:
		statusMessage progress "Enabliing DS Plugin:${DSPLUGIN}"
	        "$defaults" write "${DSPLIST%.plist}" "${DSPLUGIN:?}" 'Active' &&
		statusMessage verbose "Successfully added preference key ${DSPLUGIN:?}:Active"
		export KILLDS=1	
		declare EXITVALUE=0
	fi
	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "$FUNCTIME" != 0 ] &&
		statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds $EXITVALUE"
	return ${EXITVALUE:-1}
} # END enablePlugin()

bindODServer(){
	statusMessage header "FUNCTION: #       ${FUNCNAME}" ; unset EXITVALUE
	declare -i FUNCSECONDS="$SECONDS" # Capture start time
	declare -i FUNCRETRY=5
	until (checkHostReachable "${ODSERVER[CONFIG]}" "${ODTIMEOUT:?}") ; do
		export DIRSERVER="${ODSERVER[0]}"
		statusMessage notice "Could not reach ${ODSERVER[CONFIG]} failing over to: ${ODSERVER[0]}"
		export CONFIG=0 # Export 0 for checkbinding test that occurs after binding.
		break # Break and use new data below
	done
	for (( try = 1 ; try <=$FUNCRETRY; try++ )) ; do # Loop for safty
		if [ "${AUTHODBIND}" = "NO" ] ; then
			if "$dsconfigldap" -v -a "${DIRSERVER:?}" -n "${DIRSERVER:?}" -c "${COMPNAME:?}" $ODSSL >> "${SCRIPTLOG:?}" ; then
				statusMessage notice "dsconfigldap exited with 0"
				return 0
			else
                        	statusMessage notice "dsconfigldap exited with non 0"
				export CONFIG="$(($$$RANDOM % ${#ODSERVER[@]}))"
				statusMessage notice "Choosing random retry server: ${ODSERVER[$CONFIG]}"
			fi
	
		else
			if "$dsconfigldap" -f -v -a "${DIRSERVER:?}" -n "${DIRSERVER:?}" -c "${COMPNAME:?}" $ODSSL -u $ODBINDADMIN -p "$ODBINDPASS" >> "${SCRIPTLOG:?}" ; then
                	        statusMessage notice "dsconfigldap exited with 0"
				return 0        
               		 else
                        	statusMessage notice "dsconfigldap exited with non 0"
                        	export CONFIG="$(($$$RANDOM % ${#ODSERVER[@]}))"
	                        statusMessage notice "Choosing random retry server: ${ODSERVER[$CONFIG]}"

			fi
		fi
		# Exit ( return ) the function, show failure message if not
		statusMessage notice "Open Directory binding , may have failed"
	done

	declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
	[ "$FUNCTIME" != 0 ] &&
		statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds $EXITVALUE"
	return ${EXITVALUE:-1} # Exit 1 if not set
} # END bindODServer()


if [ -r "${CONFIGFILE:?}" ] ; then
	statusMessage verbose "Found configuration file: $CONFIGFILE"
	source "${CONFIGFILE:?}"
	statusMessage verbose "Checking for overide options ($CLI_NAME_FORMAT)"

        if [ -n "$IP_NAME_FORMAT" ] ; then
                statusMessage verbose "Detected IP name format: $IP_NAME_FORMAT"
                export NAME_FORMAT="$IP_NAME_FORMAT"
        fi

        if [ -n "$IP_CUSTOM_NAME" ] ; then
                statusMessage verbose "Detected IP name based on IP:$IP_CUSTOM_NAME"
                export CUSTOM_NAME="$IP_CUSTOM_NAME"
        fi

	if [ -n "$CLI_NAME_FORMAT" ] ; then
		statusMessage verbose "Detected custom name format overide: $CLI_NAME_FORMAT"
		export NAME_FORMAT="$CLI_NAME_FORMAT"
	fi

        if [ -n "$CLI_CUSTOM_NAME" ] ; then
                statusMessage verbose "Detected custom name overide: $CLI_CUSTOM_NAME"
                export CUSTOM_NAME="$CLI_CUSTOM_NAME"
        fi

	if [ "$NAME_FORMAT" = '%n' ] ; then
		if [ ${#CUSTOM_NAME} -eq 0  ] ; then
			statusMessage error "CUSTOM_NAME is empty for format is %n, reverting to config file"
		        source "${CONFIGFILE:?}"
		fi
	fi
else
###############################################################################
#       BEGIN CONFIGFILE						      #
###############################################################################
statusMessage verbose "Configuration File not found at path:$CONFIGFILE"
# Comment the line below to run the script with varibles set in the script
"$sleep 60" ; die ERROR "Configuration file is missing or has been deleted" 192 

###############################################################################
#	END CONFIGFILE							      #
###############################################################################

fi # End Configuration File Check
# Begin Main:
statusMessage header "MAIN:     #	BEGIN Main Routine"

begin

# Override settings for revert
export ADBIND="${ADBIND_OVERRIDE:="$ADBIND"}"
export ODBIND="${ODBIND_OVERRIDE:="$ODBIND"}"

# Sanity checks, with exit codes that can match up to a pkg install strings file

checkSystemVersion "${OSVER:?}" ||
	die ERROR "LINENUM:$LINENO:Version Check failed" $(( 1<<5 | 18 ))

checkCommands "${REQCMDS:?"ERROR: REQCMDS varible has not been set "}" ||
	die ERROR "$SCRIPT: the command $RQCMD is not available, aborting" $(( 1<<5 | 19 )) 


withTimeOut checkNetwork "${TIMEOUT:="60"}" "Waiting for network timeout"  ||
	die NETWORK "LINENUM$LINENO:Unable to connect to network" $(( 1<<5 | 20 ))

setMachineType || # Laptop = L Desktop = D Unknown = U
	die HARDWARE "LINENUM:$LINENO:Unable to determine hardware type" $(( 1<<5 | 21 ))

if [ "$DNS_CHECK" = 'YES' ] ; then
	checkSearchDomain ||
		addSearchDomain "${DNS_SUFFIX}"

	checkDNS ||
		die ERROR "LINENUM:$LINENO:DNS CONFIG missing/incorrect" $(( 1<<5 | 22 ))
        setGChost "${ADDOMAIN:?}" ||
	                statusMessage error "LINENUM:$LINENO:Check configured DNS Servers"

        checkHostReachable "${GCHOST:?}" '30' ||
	                die ERROR "LINENUM:$LINENO:Unable to reach host: ${GCHOST:?}" $(( 1<<5 | 23 ))

fi
setNetworkTimeServer ${NTPSERVER:?} ${NTPTIMEOUT:?} ||
	die ERROR "LINENUM:$LINENO:Unable to set network time server: ${NTPSERVER:?}" $(( 1<<5 | 24 ))

       setSiteName "${IPADDR:="0.0.0.0"}"
	   genComputerName

if [ -f "${RUNDIRECTORY}/machine_specific_data.csv" ] ; then
	# Future code
	statusMessage notice "Found:/machine_specific_data.csv, skipping setComputerNames"
elif [ "$KEEP_CURRENT_NAME" = 'YES' ] ; then
	statusMessage notice "Recieved override to keep current name"
else
        setComputerNames
fi

declare -i FUNCSECONDS="$SECONDS" # Capture start time
while true ; do
	[ "${MAINTRY:-0}" -ge 1 ] && statusMessage notice "Restarting Loop due to failure:$MAINTRY"
	let "MAINTRY++"
	
	if [ "${MAINTRY:?}" -ge 20 ] ;  then
                statusMessage error "Main loop reached retry limit"
                statusMessage error "Resetting DirectoryServices"
		$rm /Library/Preferences/DirectoryService/*
		killDirectoryService
		break

        elif [ "$SECONDS" -ge "${GTIMEOUT:?}" ] ; then
                statusMessage error "Script reached global TIMEOUT $GTIMEOUT seconds"
                break

        fi

	setCustomSearchPath

	declare -x KILLDS=0
StatusMSG "dsconfig" "Removing Old Connections" uiphase	
for DSPLUGIN in 'LDAPv3' 'Active Directory' ; do
	StatusMSG "dsconfig" "Removing current $DSPLUGIN connections" uistatus
	statusMessage progress "Removing old Directory Servers for $DSPLUGIN"
	removeSearchPath "${DSPLUGIN:?}"
        statusMessage verbose "verifying $DSPLUGIN is enabled"
	enablePlugin "${DSPLUGIN:?}"
done
if [ "$KILLDS" = 1 ] ; then
	statusMessage notice "Must kill DS to pickup on plugin's being enabled"
	removeSearchPath 'plist' # Reset the Plists Search Paths
	killDirectoryService
	"$sleep" 2
	unset KILLDS DSPLUGIN
fi

# BEGIN Configure Active Directory

# Always Remove LDAP Binding
declare -x DSPLUGIN='LDAPv3'
withTimeOut removeBinding '10' "Attempting to unbind from : $DSPLUGIN" 



if [ "$ADBIND" = 'YES' ] ; then

	setInstallPercentage 10.00

	StatusMSG "dsconfig" "Binding to Active Directory" uiphase
	
		
	declare -x DSPLUGIN='Active Directory'
	StatusMSG "dsconfig" "Binding to $DSPLUGIN" uistatus	
	
	declare -x DIRSERVER="${ADDOMAIN:?}"

	statusMessage verbose "Starting $DSPLUGIN bind with $DIRSERVER" 

	StatusMSG "dsconfig" "System is currently automatically binding to: $DSPLUGIN" uistatus
	
	setInstallPercentage 50.00
	
	withTimeOut removeBinding '10' "Attempting to unbind from : $DSPLUGIN" || continue
		
	withTimeOut bindADServer '10' "Attempting rebind of Active Directory" || continue
	
	setADTimeout "${ADTIMEOUT:?}" ||
		statusMessage error "ADPLUGIN: Setting timeout value $ADTIMEOUT"
	
	withTimeOut addSearchpath '5' "Attempting to add searchpath for $DIRNODE" || continue
	
fi
# END Configure Active Directory

# To Be used for OD Removal
if [ "$ODBIND" = 'NO' ] ; then
	declare -x DSPLUGIN='LDAPv3'
	declare -x DIRSERVER="${ODSERVER[CONFIG]}"

	withTimeOut removeBinding '10' "Attempting to unbind from : $DSPLUGIN" || continue

	flushMCX

fi

# BEGIN Configure Open Directory
if [ "$ODBIND" = 'YES' ] ; then
	declare -x DSPLUGIN='LDAPv3'
	declare -x DIRSERVER="${ODSERVER[CONFIG]}"
	
	statusMessage verbose "Starting $DSPLUGIN bind with $DIRSERVER"
	
        statusMessage graphical "System is currently automatically binding to: ${DSPLUGIN:+"Open Directory"}, Please wait a moment  to login"
	
	withTimeOut removeBinding '10' "Attempting to unbind from : $DSPLUGIN" || continue

	bindODServer || continue

	withTimeOut addSearchpath '5' "Attempting to add searchpath for $DIRSERVER" || continue
fi
# END Configure Open Directory

	checkBinding && break # This also has a "fix" for the /Seach order index and AD
	
	# The loop ends here if the AD/OD auth checks work

	statusMessage progress "Restarting entire loop, waiting for 5 seconds ($MAINTRY)"

	"$sleep" 5	
	
	# Forcefully delete the Custom Search path entries and restart DirectoryService
	
	statusMessage notice "Removing plist keys for retry"
	
	removeSearchPath 'plist'
	
	continue
done		
statusMessage header "MAIN:     #	END Main Routine"

# End Main
unset ${!AD*} # Clear all our AD Credentials 
unset ${!OD*} # Clear all our OD Credentials
cleanUp || (printf "%s\n" "ERROR: There was a error during cleanup" >>"${SCRIPTLOG:?}" && exit 192)
setInstallPercentage 90.00
die NOTICE "Scripted Exited: $EXITVALUE" $?
trap die EXIT
unset -f die
exit 1		# Should never get here.	
