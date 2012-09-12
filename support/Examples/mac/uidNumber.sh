#!/bin/bash
# set -xv
declare -x DIRECTORY_ADMIN="diradmin"
declare -x DIRECTORY_PASS="5tgb6yhn"
declare -x REMOTE_LDAP_SERVER="chixserve-md02.chi.publicisgroupe.net"
declare -x REMOTE_SEARCH_BASE="dc=chixserve-md02,dc=chi,dc=publicisgroupe,dc=net"
declare -x REMOTE_KEYWORD="Raptor Migration"

declare -x REFERENCE_ATTRIBUTE="URL"

# Commands used by this script
declare -x dscl="/usr/bin/dscl"
declare -x id="/usr/bin/id"
declare -x ldapsearch="/usr/bin/ldapsearch"

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
	while getopts cvhb:d:m:wd SWITCH ; do
		case $SWITCH in
			b ) declare -ix BOOT_HOUR="$OPTARG" ;;
			d ) set -xv;;
			m ) declare -x RANDOM_NUMBER="$(printf "%02d" "$OPTARG")" ;;
            w ) declare -x WRITE_OUT_CHANGES="YES" ;;	
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
for USER_LIST in `$dscl /LDAPv3/127.0.0.1 -list /Users UniqueID |
	grep -v 'diradmin' |
	grep -vE 'vpn_*' |
	grep -v 'root'`  ; do
	let TOTAL_NUMER++
	# Column One is shortname
	declare -x RECORD_NAME="$(echo "$USER_LIST" |
										awk '{print $1}')"
	# Column Two is uidNumber
    declare -x UNIQUE_ID="$(echo "$USER_LIST" |
										awk '{print $2}')"

	# Check current UID value in LDAP
	declare -x LDAP_SEARCH="$(
	$ldapsearch \
	-LLL \
	-x \
	-H \
	ldap://$REMOTE_LDAP_SERVER \
	-D \
	"uid=$DIRECTORY_ADMIN,cn=users,$REMOTE_SEARCH_BASE" \
	-w \
	"$DIRECTORY_PASS" \
	-b \
	"cn=users,$REMOTE_SEARCH_BASE" \
	"(uidNumber=$UNIQUE_ID)" )"
	
	
	# Check 
	if [ "${#LDAP_SEARCH}" -gt 0 ] ; then
		# Generate a new uid by adding 20000
		declare -xi NEW_UID="$(( $UNIQUE_ID + 20000))"
		
		# Track the number of conflicts
		let NUMBER_OF_CONFLICTS++
		statusMessage notice "Found conflict: $RECORD_NAME($UNIQUE_ID->$NEW_UID)"
		
		# Check the UID against the local resolver
		if $id ${NEW_UID:?} &>/dev/null ; then
			statusMessage error "New UID for $RECORD_NAME already in use"
		fi	
		# Run an LDAP search on the new UID to ensure its not also in conflict
		declare -x LDAP_SEARCH="$(
		$ldapsearch \
		-LLL \
		-x \
		-H \
		ldap://$REMOTE_LDAP_SERVER \
		-D \
		"uid=$DIRECTORY_ADMIN,cn=users,$REMOTE_SEARCH_BASE" \
		-w \
		"$DIRECTORY_PASS" \
		-b \
		"cn=users,$REMOTE_SEARCH_BASE" \
		"(uidNumber=${NEW_UID:?})" )"
		
		# Check the result of the LDAP search for the new uid
		if [ "${#LDAP_SEARCH}" -gt 0 ] ; then
			statusMessage error "New UID for $RECORD_NAME already in use remotely"
		else
		# If we are not in conflict and we have been told to write the new value out do so
			if [ "$WRITE_OUT_CHANGES" = 'YES' ] ; then
			statusMessage notice "Updating UID for $RECORD_NAME ($UNIQUE_ID->$NEW_UID)"
		                $dscl \
							-u "$DIRECTORY_ADMIN" \
							-P "$DIRECTORY_PASS" /LDAPv3/127.0.0.1 \
							-create /Users/$RECORD_NAME UniqueID "$NEW_UID" &&
							statusMessage verbose "DSCL Command successfully added $RECORD_NAME UniqueID->$NEW_UID"
			fi

		fi
			# Add the old UID to the reference attribute which will be picked up by the other script
	       $dscl \
				-u "$DIRECTORY_ADMIN" \
				-P "$DIRECTORY_PASS" /LDAPv3/127.0.0.1 \
				-merge /Users/$RECORD_NAME "$REFERENCE_ATTRIBUTE" "$UNIQUE_ID"


	else
		statusMessage passed "$RECORD_NAME has no conflicts($UNIQUE_ID)"
	fi
	# Add a keyword that we are coming from this Open Diectory
	$dscl \
		-u "$DIRECTORY_ADMIN" \
		-P "$DIRECTORY_PASS" /LDAPv3/127.0.0.1 \
		-merge /Users/$RECORD_NAME Keywords "$REMOTE_KEYWORD"
	
	# Now check the primary Group ID
	declare -xi PRIMARY_GROUP_ID="$($dscl /LDAPv3/127.0.0.1 -read /Users/$RECORD_NAME PrimaryGroupID |
																						awk '{print $NF}')"
	
	# Skip past the Admin and Staff Groups
	if [ $PRIMARY_GROUP_ID -eq 80 ] ; then
                statusMessage passed "$RECORD_NAME has no conflicting PrimaryGroupID ($PRIMARY_GROUP_ID)"
	elif [ $PRIMARY_GROUP_ID -eq 20 ] ; then
       		statusMessage passed "$RECORD_NAME has no conflicting PrimaryGroupID ($PRIMARY_GROUP_ID)"
	else
		declare -x LDAP_SEARCH="$(
        $ldapsearch \
        -LLL \
	-x \
        -H \
        ldap://$REMOTE_LDAP_SERVER \
        -D \
        "uid=$DIRECTORY_ADMIN,cn=users,$REMOTE_SEARCH_BASE" \
	-w \
        "$DIRECTORY_PASS" \
        -b \
        "cn=groups,$REMOTE_SEARCH_BASE" \
		"(gidNumber=${PRIMARY_GROUP_ID:?})" )"
		# Check the results of the LDAP conflict test
		if [ "${#LDAP_SEARCH}" -gt 0 ] ; then
			# If we found a conflict then
		
			# If the PrimaryGroupID shows a conflict on the remote host
                	statusMessage notice "$RECORD_NAME has a conflicting PrimaryGrou
pID ($PRIMARY_GROUP_ID)"	
			# Generate a new one based on the scheme used in the group script
			declare -xi NEW_GID="$(($PRIMARY_GROUP_ID + 20000))"
			# No need to check if the new one is in conflict , may be be site specific
			
			statusMessage notice "Detected PrimaryGroupID conflict for $RECORD_NAME's PrimaryGroupID ($PRIMARY_GROUP_ID)"
			
			# If we have been told to write changes out then
			if [ "$WRITE_OUT_CHANGES" = 'YES' ] ; then
				statusMessage notice "Writing out new GID value for $RECORD_NAME ($PRIMARY_GROUP_ID->$NEW_GID)"
			# Update the PrimaryGroupID with the new generated value
			$dscl \
				-u "$DIRECTORY_ADMIN" \
				-P "$DIRECTORY_PASS" /LDAPv3/127.0.0.1 \
				-create "/Users/$RECORD_NAME" PrimaryGroupID "$NEW_GID"
			fi
		fi # End LDAP search

	fi # End PrimaryGroupID in conflict else exception
done
IFS="$OLDIFS"
statusMessage header "Found ${NUMBER_OF_CONFLICTS:=0} conflicts out of ${TOTAL_NUMER:=0}"
