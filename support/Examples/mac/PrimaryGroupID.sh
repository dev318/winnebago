#!/bin/bash
# set -xv
declare -x DIRECTORY_ADMIN="diradmin"
declare -x DIRECTORY_PASS="5tgb6yhn"
declare -x REMOTE_LDAP_SERVER="chixserve-md02.chi.publicisgroupe.net"
declare -x REMOTE_SEARCH_BASE="dc=chixserve-md02,dc=chi,dc=publicisgroupe,dc=net"


[ "$EUID" != 0 ] && 
	printf "%s\n" "This script requires root access!" && exit 1
	
# Main logging routine
declare -x SCRIPT="${0##*/}" ; SCRIPT_NAME="${SCRIPT%%\.*}"
declare -x SCRIPTPATH="$0" RUNDIRECTORY="${0%/*}"
declare -x LOGLEVEL="NORMAL" SCRIPT_LOG="/Library/Logs/${SCRIPT%%\.*}.log"

# Status message function with type and now color!
# Removed showUIDialog code
# Added Indent
statusMessage() { 
	# Requires Postional Parameters STATUS_TYPE=1 STATUS_MESSAGE=2
	# Required Variables SCRIPT_LOG
	# Commands Required by this Function
	declare date="${date:="/bin/date"}"
	declare DATE="$("$date" -u "+%Y-%m-%d")"
	declare STATUS_TYPE="$1" STATUS_MESSAGE="$2"
	if [ "$ENABLE_COLOR" = "YES"  ] ; then
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

	case "${STATUS_TYPE:?"Error status message with null type"}" in
		progress) \
		[ -n "$LOGLEVEL" ] &&
		printf $format $NOTBOLD $WHITEBG $BLACKFG "PROGRESS:$STATUS_MESSAGE"  ;
		printf "%s\n" "$DATE:PROGRESS: $STATUS_MESSAGE" >> "${SCRIPT_LOG:?}" ;;
		# Used for general progress messages, always viewable
	
		notice) \
		printf "%s\n" "$DATE:NOTICE:$STATUS_MESSAGE" >> "${SCRIPT_LOG:?}" ;
		[ -n "$LOGLEVEL" ] &&
		printf $format $NOTBOLD $YELLOWBG $BLACKFG "NOTICE  :$STATUS_MESSAGE"  ;;
		# Notifications of non-fatal errors , always viewable
	
		error) \
		printf "%s\n\a" "$DATE:ERROR:$STATUS_MESSAGE" >> "${SCRIPT_LOG:?}" ;
		[ -n "$LOGLEVEL" ] &&
		printf $format $NOTBOLD $REDBG $YELLOWFG "ERROR   :$STATUS_MESSAGE"  ;;
		# Errors , always viewable

		verbose) \
		printf "%s\n" "$DATE:VERBOSE: $STATUS_MESSAGE" >> "${SCRIPT_LOG:?}" ;
		[ "$LOGLEVEL" = "VERBOSE" ] &&
		printf $format $NOTBOLD $WHITEBG $BLACKFG "VERBOSE :$STATUS_MESSAGE" ;;
		# All verbose output
	
		header) \
		[ "$LOGLEVEL" = "VERBOSE" ] &&
		printf $format $NOTBOLD $BLUEBG $BLUEFG "VERBOSE :$STATUS_MESSAGE" ;
		printf "%s\n" "$DATE:PROGRESS: $STATUS_MESSAGE" >> "${SCRIPT_LOG:?}" ;;
		# Function and section headers for the script
	
		passed) \
		[ "$LOGLEVEL" = "VERBOSE" ] &&
		printf $format $NOTBOLD $GREENBG $BLACKFG "SANITY  :$STATUS_MESSAGE" ;
		printf "%s\n" "$DATE:SANITY: $STATUS_MESSAGE" >> "${SCRIPT_LOG:?}" ;;
		# Sanity checks and "good" information
		graphical) \
		[ "$GUI" = "ENABLED" ] &&
		showUIDialog "$STATUS_MESSAGE" ;;
	
	esac
	return 0
} # END statusMessage()

showUsage(){
	statusMessage header "FUNCTION: #       $FUNCNAME" ; unset EXITVALUE
	printf "%s\n\t" "USAGE:"
	printf "%s\n\t" 
	printf "%s\n\t" " OUTPUT:"
	printf "%s\n\t" " -v | # Turn on verbose output (logged data)"
	printf "\033[%s;%s;%sm%s\033[0m\n\t" "1" "44" "37" " -c | # Turn on colorized output"
	printf "\033[0m"
	printf "%s\n\t" " OTHER TASKS:"
	printf "%s\n\t" " -d <MTWRFSU> |  The Day to for Startup Schedule (man pmset)"
	printf "%s\n\t" " -b <0> |  boot time"
	printf "%s\n\t" " -s <0> |  shutdown time"
	printf "%s\n\t" " -m | Overide the random number generation and set a specific numbers"
	printf "%s\n\t" " -l | Create the Launchd Item	# This will also recreate"
	printf "%s\n\t" " -r | Randomize the schedule of the launchd item"
	printf "%s\n\t" " -h | # Print this usage message and quit"
	printf "%s\n\t" " -o | Override hardware check and impersonate as a Desktop (launchd edited)"
	printf "%s\n\t"
	printf "%s\n\t" " EXAMPLE SYNTAX:"
	printf "%s\n\t"	"$0 -c -l -o -v -b 3 -s 8 -d MTWRFSU"
	
	printf "%s\n"
	return 0
}

# Check script options
statusMessage header "GETOPTS: Processing script $# options:$@"
# ABOVE: Check to see if we are running as a postflight script,the installer  creates $SCRIPT_NAME
[ $# = 0 ] && statusMessage verbose "No options given"
# If we are not running postflight and no parameters given, print usage to stderr and exit status 1
if [[ "$@" = -* ]] ; then
	 statusMessage verbose "Detected command line arguments"
	while getopts cvlrhs:d:w SWITCH ; do
		case $SWITCH in
			l ) declare -x CREATE_LAUNCHD="YES" ;;
			w ) declare -x WRITE_OUT_CHANGES="YES" ;;
			s ) declare -ix SHUTDOWN_HOUR="$OPTARG" ;;
			v ) declare -x LOGLEVEL="VERBOSE" ;;
			c ) declare -x ENABLE_COLOR="YES" ;;
			h ) declare -x showUsage ;;
	esac
done # END getopts
else
	 statusMessage verbose "No command line arguments detected , using positional parameters"
fi

statusMessage header "Begining Main Routine $($date)"


OLDIFS="$IFS"
IFS=$'\n'
for GROUP_LIST in `dscl /LDAPv3/127.0.0.1 -list /Groups PrimaryGroupID |
        grep -v 'admin' |
        grep -vE 'com.apple*' |
        grep -v 'staff'`  ; do
	let TOTAL_NUMER++
	declare -x RECORD_NAME="$(echo "$GROUP_LIST" | awk '{print $1}')"
	declare -x PRIMARY_GROUP_ID="$(echo "$GROUP_LIST" | awk '{print $2}')"
	declare -x LDAP_SEARCH="$(
	ldapsearch \
	-LLL \
	-x \
	-H \
	ldap://$REMOTE_LDAP_SERVER \
	-D \
	"uid=$DIRECTORY_ADMIN,cn=users,$REMOTE_SEARCH_BASE" \
	-w \
	"$DIRECTORY_PASS" \
	-b \
	"cn=groups,$REMOTE_SEARCH_BASE" "(gidNumber=$PRIMARY_GROUP_ID)" )"
        if [ "${#LDAP_SEARCH}" -gt 0 ] ; then
		let NUMBER_OF_CONFLICTS++
                statusMessage notice "PrimaryGroupID ($PRIMARY_GROUP_ID) for $RECORD_NAME already in use remotely"
	declare -xi NEW_GID="$(($PRIMARY_GROUP_ID + 20000))"
        declare -x LDAP_SEARCH="$(
	        ldapsearch \
        -LLL \
        -x \
        -H \
        ldap://$REMOTE_LDAP_SERVER \
        -D \
        "uid=$DIRECTORY_ADMIN,cn=users,$REMOTE_SEARCH_BASE" \
        -w \
        "$DIRECTORY_PASS" \
        -b \
        "cn=groups,$REMOTE_SEARCH_BASE" "(gidNumber=$NEW_GID)" )"
	        if [ "${#LDAP_SEARCH}" -gt 0 ] ; then
			statusMessage error "Newly generated PrimaryGroupID is in conflict for $RECORD_NAME ($PRIMARY_GROUP_ID->$NEW_GID)"
		else
			statusMessage verbose "No conflicts for new PrimaryGroupID $RECORD_NAME ($NEW_GID)"

dscl -u "$DIRECTORY_ADMIN" -P "$DIRECTORY_PASS" /LDAPv3/127.0.0.1 -merge /Groups/$RECORD_NAME Picture "$PRIMARY_GROUP_ID"
		fi
		if [ "$WRITE_OUT_CHANGES" = 'YES' ] ; then
		statusMessage notice "Commiting changes to $RECORD_NAME ($PRIMARY_GROUP_ID->$NEW_GID)"
		dscl -u "$DIRECTORY_ADMIN" -P "$DIRECTORY_PASS" /LDAPv3/127.0.0.1 -create /Groups/$RECORD_NAME PrimaryGroupID "$NEW_GID"

		fi

	else
		statusMessage passed "No conflicts detected for $RECORD_NAME ($PRIMARY_GROUP_ID)"       	

	fi

	
done
IFS="$OLDIFS"
statusMessage header "Found ${NUMBER_OF_CONFLICTS:=0} conflicts out of ${TOTAL_NUMER:=0}"
