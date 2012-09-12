#!/bin/bash
declare -rx defaults="/usr/bin/defaults"
declare -rx PLIST="/Library/Preferences/com.apple.TimeMachine.plist"
if [ -f "$PLIST" ] ; then
	declare -rix TIME_MACHINE_ENABLED="$(defaults read "${PLIST%%.plist}" AutoBackup &2>/dev/null)"
else
	declare -rix TIME_MACHINE_ENABLED=0
fi
printf "<result>%d</result>\n" $TIME_MACHINE_ENABLED
