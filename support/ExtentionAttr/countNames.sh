#!/bin/bash
declare -rx scutil='/usr/sbin/scutil'

# Default value for AD joining
declare -rx LOCAL_HOST_NAME="$($scutil --get LocalHostName)"

# Count the number of Characters
declare -rix NUMBER_OF_CHAR=${#LOCAL_HOST_NAME}

# Return results
printf "<result>%d</result>\n" ${NUMBER_OF_CHAR}
