#!/bin/bash

declare -x awk="/usr/bin/awk"
declare -x cat="/bin/cat"
declare -x id="/usr/bin/id"
declare -xi Day=86400 Hour=3600 Min=60
declare -x TotalUsersLog="/Users/Shared/TotalUsers.log"
declare -x TotalMigratedLog="/Users/Shared/TotalMigrated.log"
declare -x DisabledUsersLog="/Users/Shared/DisabledUsers.log"
declare -x NotMigratedLog="/Users/Shared/NotMigratedLog.log"
declare -x ChangedUsersLog="/Users/Shared/ChangedUsers.log"
declare -i MyTime="$SECONDS" 
declare -x MyMessage="/private/tmp/$$$RANDOM-Email-Message.txt"
declare -x sendEmail="/usr/local/bin/sendEmail.pl"
# Remove Logs Each Run
[ -f "$TotalUsersLog" ] &&
		rm "$TotalUsersLog"
[ -f "$TotalMigratedLog" ] &&
		rm "$TotalMigratedLog"
[ -f "$DisabledUsersLog" ] &&
		rm "$DisabledUsersLog"
[ -f "$NotMigratedLog" ] && 
	rm "$NotMigratedLog"
[ -f "$ChangedUsersLog" ] &&
	rm "$ChangedUsersLog"

for USER_NAME in $(dscl /LDAPv3/od.example.com -list /Users | $awk '!/^root/' | $awk '!/^zsmith/' | $awk '!/^diradmin*/' | $awk '!/^untitled*/' | $awk '!/^vpn_*/') ; do
	declare PassTest="$(dscl /Active\ Directory/All\ Domains -authonly "$USER_NAME" "${USER_NAME}sharedsecret" 2>&1)"
	declare ExitValue="$?"
	let TotalUserCount++
	echo "$USER_NAME" >> "$TotalUsersLog"
	# eDSAuthFailed	
	if [ "$PassTest" != "${PassTest/-14090//}" ] ; then
		# LDAP is top of search path
		declare -xi UsersID="$($id -u $USER_NAME)"
		declare -x samAccountName="$(dscl /Active\ Directory/All\ Domains -search /Users UniqueID "$UsersID" | awk '{print $1;exit}')"
		declare -xi AliasUsersID="$(dscl /Active\ Directory/All\ Domains -read "/Users/$USER_NAME" UniqueID 2>/dev/null | awk '{print $NF}')"
		if [ "$AliasUsersID" -eq 0 ]; then
			:
		elif [ "$AliasUsersID" = "$UsersID" ] ; then
			if [ "$samAccountName" != "$USER_NAME" ] ; then
				echo "$USER_NAME" >>"$ChangedUsersLog"
				let ChangedUsers++
				continue
			fi
		fi	
		let TotalMigratedCount++
		echo "$USER_NAME" >> "$TotalMigratedLog"
	fi
	# eDSAuthAccountExpired
        if [ "$PassTest" != "${PassTest/-14168//}" ] ; then
		let DisabledUserCount++
		echo  "$USER_NAME" >> "$DisabledUsersLog" 
	fi
	if dscl /Active\ Directory/All\ Domains -authonly "$USER_NAME" "${USER_NAME}sharedsecret" &>/dev/null ; then
		let NotMigrated++
		echo "$USER_NAME" >> "$NotMigratedLog"
	fi
done

declare -i WebFailures="$(cat /Users/Shared/WebMigrator-error.log | awk -F ":" '/^U/{print $2}' | uniq | wc -l)"
declare -i WebMigrator="$(cat /Users/Shared/WebMigrator.log | awk '/^User/' | wc -l)" 
declare -i EnabledUsers="$((${TotalUserCount:=0} - ${DisabledUserCount:=0}))"
declare -i Percentage="$(echo "scale=0; $TotalMigratedCount*100/$EnabledUsers" | bc)"
declare -i DesktopsInAD="$(dscl /Active\ Directory/All\ Domains -list /Computers | awk '{seen++}END{print seen}')"
declare -i ToolRunTimes="$(ls -ld /Shared\ Items/MigrationLogs/* | wc -l)"
declare -i ToolRunToday="$(find /Shared\ Items/MigrationLogs/* -type d -mtime 0 | wc -l)"
declare -x Subject="Password Migration is ${Percentage}% Complete (${NotMigrated:="0"} Users remain)"
export Email="user@example.com"
export SMTPServer="mail.example.com"


printf "%s\t\t%s\n" "Total Users:" ${TotalUserCount:="0"} >>"$MyMessage"
printf "%s\n" " ----------------------------------------------------------- |" >>"$MyMessage"
printf "%s\t\t%s\n" "Disabled Users:" "-${DisabledUserCount:="0"}" >>"$MyMessage"
printf "%s\n" " ----------------------------------------------------------- |" >>"$MyMessage"
printf "%s\t\t%s\n" "Migrated Users:" ${TotalMigratedCount:="0"} >>"$MyMessage"
printf "%s\t\t\t%s\n" "Desktops:" "${DesktopsInAD:="0"}" >>"$MyMessage"
printf "%s\t\t\t%s\n" "Total Machines:" "$(($DesktopsInAD -9))" >>"$MyMessage"
printf "%s\n" " ----------------------------------------------------------- |" >>"$MyMessage"
printf "%s\t\t%s\n" "Renamed Users:" 3 >>"$MyMessage"
printf "%s\n" " ----------------------------------------------------------- |" >>"$MyMessage"
printf "%s\t%s\n" "Incomplete Users:" ${NotMigrated:-"0"} >>"$MyMessage"
printf "%s\n" " ----------------------------------------------------------- |" >>"$MyMessage"
printf "%s\t\t%s\n" "Web Users Migrated:" "$WebMigrator" >>"$MyMessage"
printf "%s\n" " ----------------------------------------------------------- |" >>"$MyMessage"
printf "%s\t\t%s\n" "Mac Migrator Runs:" "$ToolRunTimes" >>"$MyMessage"
printf "%s\t\t\t%s\n" "Tool Runs Today:" "$ToolRunToday" >>"$MyMessage"
printf "%s\n" " ----------------------------------------------------------- |" >>"$MyMessage"

/usr/local/bin/findstaleusers

declare -i RunTime="$(($SECONDS - $MyTime))"
if [ "${RunTime:-0}" -gt 0 ] ; then
	declare -i TimeHuman="$RunTime"
	if [ "${RunTime:-0}" -gt 1 ] ; then
		declare    TimeUnit="Seconds"
	else
		declare    TimeUnit="Second"
	fi
	if [ "${RunTime:-0}" -gt  "${Day:?}" ] ; then
		declare    TimeUnit="Days"
		declare -i TimeHuman="$(printf %.0f $((${RunTime:-0} / 86400 )))"

	elif [ "${RunTime:-0}" -gt "${Hour:?}" ] ; then
		declare    TimeUnit="Hours"
		declare -i TimeHuman="$(printf %.0f $((${RunTime:-0} / 3600 )))"

	elif [ "${RunTime:-0}" -gt "${Min:?}" ] ; then
		declare    TimeUnit="Minutes"
		declare -i TimeHuman="$(printf %.0f $((${RunTime:-0} / 60 )))"
	fi
fi
echo "Report took $TimeHuman $TimeUnit to generate" >>"$MyMessage"
printf "%s\n" " ----------------------------------------------------------- |" >>"$MyMessage"
echo "You can disable this report using the following command:"  >>"$MyMessage" 
echo "ssh root@`hostname` launchctl unload /Library/LaunchDaemons/com.github.winnebago.migrateReport.plist"  >>"$MyMessage"
echo "If you are a Domain Admin you can view the logs using the following URL:" >>"$MyMessage"
echo 'afp://thishost/MigrationLogs' >>"$MyMessage"
$sendEmail -f "$Email" -t "$Email" -s "$SMTPServer" -a /Users/Shared/*.csv /Users/Shared/*.log -u "$Subject" -m "$($cat "$MyMessage")" -l /Users/Shared/MigrateReport-Email.log 
