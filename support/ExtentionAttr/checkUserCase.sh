#!/bin/bash
declare -x awk='/usr/bin/awk'
declare -x dscl='/usr/bin/dscl'
declare -x grep='/usr/bin/grep'

declare -xi UPPER_CASE="$($dscl . -list /Users |
	$awk '!/^_.*/' |
	$grep -cE '[A-Z]')"

printf "<result>%d</result>\n" $UPPER_CASE

