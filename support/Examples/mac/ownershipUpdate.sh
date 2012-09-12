#!/bin/bash
#
# permissionsMigration.sh
#
# Designed to recursively descend into a directory structure and create
# ACLs on all files and folders based on current POSIX permissions.
# User must provide text files to map existing users (on which the POSIX
# permissions are based) to the users on which the ACLs will be based.
# 
# 2/28/2011 1.0
# Gene Sullivan
# First production version
#
# 3/1/2011 1.1
# Gene Sullivan
# Updated logging. It now creates a folder in /var/log called permissionsMigration
# Two logs are created:
#		operations.TIMESTAMP.log
#		groups.TIMESTAMP.log
# Operations log contains an entry for every file or folder processed, and will contain
# any errors due to user or group lookups. This will also be echoed to STDOUT.
# Groups log contains one line for every file or folder, tab-separated, with the first
# field being the group that owns the file or folder, and the second field being the path
# Processing of the groups file will happen in a separate script.
#
# 3/10/2011 1.1.1
# Gene Sullivan
# Added "--" option to the "ls" commands to ignore any further options. It now works for
# files whose names begin with a "-". Also quoted the $USERFILE and $GROUPFILE variables
# to keep it from choking on paths with spaces.
# Updated usage, incorporated the logging changes that Mike at HMH added
#
# 3/22/2011 v1.2
# Gene sullivan
# Broke the Owner ACL out into its own subroutine so that owner ACL won't be inherited.
# Per discussion with Matt
#
# 3/24/2011 v1.2.1
# Changed cd commands so that they won't fail on folders whose names begin with "-"
#
# 3/30/2011 v1.3
# Added new logic to permissions parsing for folders and files. It now looks for existing
# user and group-based ACEs. If a user-based ACE is found, no new user ACE is created. If
# a group ACE is found, that group name is looked up in the group list. If it's an OD group,
# a new ACE is created. If it's an AD group, no new ACE is created.
#
# 4/4/2011 v 1.4
# Changed the lookup of groups for existing ACEs so more strictly match the group name
# if [ -n `awk 'BEGIN { FS = "\t" }; {print $2}' "$GROUPFILE" | $egrep "^$existingaclgroup$"` ]; then
#
# 4/8/2011 v 1.5
# Quoted the lookup string to make the null test return the correct result
# Also merged in the changes Matt had made
#
# 4/11/2011 v 1.5.1
# Matt Ryan
# Modified the script so that the logic for when to skip creating a user ACL matches the
# logic for when to skip creating a group ACL (ie, only when an AD-based ACL is present). 
# More changes for logging clarity.
#
# 4/13/2011 v 1.5.2
# Matt Ryan
# Speed enhancement: if the POSIX owner/group is not found in the correlation file, do not
# try to set an owner/group ACL.
# Logic correction: added  | sed -e 's/.*\\\\//'  to the evaluation of currentaclgroup, so 
# that "PUBEDU\" is not part of the string that's searched in the group correlation file.

# ***
# This is the slower, "re-run" version of the script, which uses extra logic to avoid 
# re-creating AD-based ACLs on objects that were processed by a prior run of the script.
# ***
#
# 4/29/2011 v2.0
# Gene Sullivan
# Unified the Tiger dev and Snow Leopard production versions - there's now two sets of ACL 
# creation and permissions parsing routines, and a check of OSTYPE that decides which to run
# Added internal field separator logic to for loops to fix issue with ._ files
# AD Domain is now hardcoded to PUBEDU - the dscl command should be valid on Tiger
# but in testing returned an empty value.
# 

# Set options
# Default is recursive
declare -x RECURSIVE=1
declare -x ADDOMAIN="PUBEDU"

declare -x TIMESTAMP=`/bin/date "+%m%d%H%M"`
declare -x LOGFOLDER="/Library/Logs/permissionsMigration"
declare -x GROUPLOG="$LOGFOLDER/groups.$TIMESTAMP.log"
declare -x OPERATIONSLOG="$LOGFOLDER/operations.$TIMESTAMP.log"

declare -x chmod="/bin/chmod"
declare -x grep="/usr/bin/grep"
declare -x egrep="/usr/bin/egrep"

# Create ACL on a file on Tiger
createtigerfileacl ()
{
	case "$1" in 
		r--)
			$("$chmod" +a "$2 allow read,readattr,readextattr,readsecurity" "$filename")
			;;
		rw-)
			$("$chmod" +a "$2 allow read,readattr,readextattr,readsecurity,write,append,writeattr,writeextattr,writesecurity,chown,delete" "$filename")
			;;
		rwx)
			$("$chmod" +a "$2 allow read,readattr,readextattr,readsecurity,write,append,writeattr,writeextattr,writesecurity,chown,delete,execute" "$filename")
			;;
		-w-)
			$("$chmod" +a "$2 allow write,append,delete,writeattr,writeextattr" "$filename")
			;;
		-wx)
			$("chmod" +a "$2 allow write,append,writeattr,writeextattr,delete,execute" "$filename")
			;;
		r-x)
			$("chmod" +a "$2 allow read,readattr,readextattr,readsecurity,execute" "$filename")
			;;
		--x)
			$("chmod" +a "$2 allow execute" "$filename")
			;;
		---)
			;;
	esac
}

# Create Group ACL on a folder on Tiger
createtigergroupfolderacl ()
{
	case "$1" in 
		r--)
			$("chmod" +a "$2 allow list,search,readattr,readextattr,readsecurity,file_inherit,directory_inherit" "$foldername")
			;;
		rw-)
			$("chmod" +a "$2 allow list,search,readattr,readextattr,readsecurity,add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown,file_inherit,directory_inherit" "$foldername")
			;;
		rwx)
			$("chmod" +a "$2 allow list,search,readattr,readextattr,readsecurity,add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown,file_inherit,directory_inherit" "$foldername")
			;;
		-w-)
			$("chmod" +a "$2 allow add_file,add_subdirectory,file_inherit,directory_inherit" "$foldername")
			;;
		-wx)
			$("chmod" +a "$2 allow add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown,file_inherit,directory_inherit" "$foldername")
			;;
		r-x)
			$("chmod" +a "$2 allow list,search,readattr,readextattr,readsecurity,file_inherit,directory_inherit" "$foldername")
			;;
		--x)
			$("chmod" +a "$2 allow list,search,readattr,readextattr,readsecurity,file_inherit,directory_inherit" "$foldername")
			;;
		---)
			;;
	esac
}

# Create Owner ACL on a folder on Tiger
createtigerownerfolderacl ()
{
	case "$1" in 
		r--)
			$("chmod" +a "$2 allow list,search,readattr,readextattr,readsecurity" "$foldername")
			;;
		rw-)
			$("chmod" +a "$2 allow list,search,readattr,readextattr,readsecurity,add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown" "$foldername")
			;;
		rwx)
			$("chmod" +a "$2 allow list,search,readattr,readextattr,readsecurity,add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown" "$foldername")
			;;
		-w-)
			$("chmod" +a "$2 allow add_file,add_subdirectory" "$foldername")
			;;
		-wx)
			$("chmod" +a "$2 allow add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown" "$foldername")
			;;
		r-x)
			$("chmod" +a "$2 allow list,search,readattr,readextattr,readsecurity,file_inherit" "$foldername")
			;;
		--x)
			$("chmod" +a "$2 allow list,search,readattr,readextattr,readsecurity,file_inherit" "$foldername")
			;;
		---)
			;;
	esac
}

# Parse permissions on a file on Tiger

parsetigerfilepermissions ()
{
	echo "Processing tiger permissions for file $1"  | tee -a ${OPERATIONSLOG}
	filename="$1"
	# Pull permissions, owner, and group, assign to array
	OLDIFS="$IFS"
	IFS=$' '
    permissions=(`ls -l -- "$filename" | awk '{print $1, $2, $3, $4, $5}'`)
	IFS="$OLDIFS"
    # Strip owner, group, and all permissions from mode string
    if [ ${permissions[1]} = "+" ]; then
            rawmode=${permissions[0]}
            ownermode=${rawmode:1:3}
            groupmode=${rawmode:4:3}
            allmode=${rawmode:7:3}
            owner=${permissions[3]}
            group=${permissions[4]}
    else
            rawmode=${permissions[0]}
            ownermode=${rawmode:1:3}
            groupmode=${rawmode:4:3}
            allmode=${rawmode:7:3}
            owner=${permissions[2]}
            group=${permissions[3]}
    fi
	
	echo "$group	$PWD/$1" >> ${GROUPLOG}
	
	# Look up owner in tab-separated text file
	dirowner=`$grep $owner "$USERFILE" | awk 'BEGIN { FS = "\t" } ; {print $2;exit}'`
	#Look up group
	dirgroup=`$grep $group "$GROUPFILE" | awk 'BEGIN { FS = "\t" } ; {print $2;exit}'`
	# Check for null lookups, meaning the OD user or group isn't in the CSV
	if [ -z "$dirowner" ]; then
		echo "Owner $owner of file $filename not found in user list"  | tee -a ${OPERATIONSLOG}
	else
		dirowner="$ADDOMAIN\\$dirowner"
	fi
	
	if [ -z "$dirgroup" ]; then
		echo "Group $group for file $filename not found in group list"  | tee -a ${OPERATIONSLOG}
	else
		dirgroup="$ADDOMAIN\\$dirgroup"
	fi
	
	# Do all permissions first, then group, then owner
	# This should give us the ACLs in the correct order

        if [ ! -z "$dirgroup" ]; then
		# Check for existence of group-based ACE, grab group name
		existingaclgroup=`ls -le -- "$filename" | $grep group | awk 'BEGIN { FS = ":" }; {print $3;exit}' | awk '{print $1}' | sed -e 's/.*\\\\//'`
		# If this didn't return anything (there's no group ACE), create one
		if [ -z "$existingaclgroup" ]; then
			echo "Creating group ACL for file $filename"  | tee -a ${OPERATIONSLOG}
			createtigerfileacl "$groupmode" "$dirgroup" "$filename"
		else
			# Check for the group in the AD group list
			if [ -n "`awk 'BEGIN { FS = "\t" }; {print $2}' "$GROUPFILE" | $egrep "^$existingaclgroup$"`" ]; then
				# If it's there, skip ACL creation
				echo "AD-based ACL already exists on file $filename for group $existingaclgroup"  | tee -a ${OPERATIONSLOG}
				echo "Not creating new group ACL"  | tee -a ${OPERATIONSLOG}
			else
				# Otherwise, create the ACL
				echo "Creating group ACL for file $filename (non-AD ACL present)"  | tee -a ${OPERATIONSLOG}
				createtigerfileacl "$groupmode" "$dirgroup" "$filename"
			fi
		fi
	fi

        if [ ! -z "$dirowner" ]; then
		# Check for existence of user-based ACE, grab username
		existingacluser=`ls -le -- "$filename" | $grep user | awk 'BEGIN { FS = ":" }; {print $3;exit}' | awk '{print $1}'`
		# If this didn't return anything (there's no user ACE), create one
		if [ -z "$existingacluser" ]; then
			echo "Creating owner ACL for file $filename" | tee -a ${OPERATIONSLOG}
			createtigerfileacl "$ownermode" "$dirowner" "$filename"
		else
	        	# Check for the user in the AD user list
                	if [ -n "`awk 'BEGIN { FS = "\t" }; {print $2}' "$USERFILE" | $egrep "^$existingacluser$"`" ]; then
                		# If it's there, skip ACL creation
				echo "AD-based ACL already exists on file $filename for user $existingacluser"  | tee -a ${OPERATIONSLOG}
				echo "Not creating new owner ACL"  | tee -a ${OPERATIONSLOG}
			else	
				# Otherwise, create the ACL
                        	echo "Creating owner ACL for file $filename (non-AD ACL present)"  | tee -a ${OPERATIONSLOG}
                        	createtigerfileacl "$ownermode" "$dirowner" "$filename"
			fi
		fi
	fi
}

# Parse permissions on a folder on Tiger

parsetigerfolderpermissions ()
{
	echo "Processing tiger permissions for folder $1"  | tee -a ${OPERATIONSLOG} 
	foldername="$1"
	# Pull permissions, owner, and group, assign to array
	OLDIFS="$IFS"
	IFS=$' '
    permissions=(`ls -ld -- "$foldername" | awk '{print $1, $2, $3, $4, $5}'`)
	IFS="$OLDIFS"
    # Strip owner, group, and all permissions from mode string
    if [ ${permissions[1]} = "+" ]; then
            rawmode=${permissions[0]}
            ownermode=${rawmode:1:3}
            groupmode=${rawmode:4:3}
            allmode=${rawmode:7:3}
            owner=${permissions[3]}
            group=${permissions[4]}
    else
            rawmode=${permissions[0]}
            ownermode=${rawmode:1:3}
            groupmode=${rawmode:4:3}
            allmode=${rawmode:7:3}
            owner=${permissions[2]}
            group=${permissions[3]}
    fi
	
	echo "$group	$PWD/$1" >> ${GROUPLOG}
	
	# Look up owner in tab-separated text file
	dirowner=`$grep $owner "$USERFILE" | awk 'BEGIN { FS = "\t" } ; {print $2;exit}'`
	#Look up group
	dirgroup=`$grep $group "$GROUPFILE" | awk 'BEGIN { FS = "\t" } ; {print $2;exit}'`
	# Check for null lookups, meaning the OD user or group isn't in the CSV
	if [ -z "$dirowner" ]; then
		echo "Owner $owner of folder $foldername not found in user list"  | tee -a ${OPERATIONSLOG}
	else
		dirowner="$ADDOMAIN\\$dirowner"
	fi
	
	if [ -z "$dirgroup" ]; then
		echo "Group $group for folder $foldername not found in group list"  | tee -a ${OPERATIONSLOG}
		dirgroup="$group"
	else
		dirgroup="$ADDOMAIN\\$dirgroup"
	fi

	# Do all permissions first, then group, then owner
	# This should give us the ACLs in the correct hierarchy
	
        if [ ! -z "$dirgroup" ]; then
		# Check for existence of group-based ACE, grab group name
		existingaclgroup=`ls -led -- "$foldername" | $grep group | awk 'BEGIN { FS = ":" }; {print $3;exit}' | awk '{print $1}' | sed -e 's/.*\\\\//'`
		# If this didn't return anything (there's no group ACE), create one
		if [ -z "$existingaclgroup" ]; then
			echo "Creating group ACL for folder $foldername"  | tee -a ${OPERATIONSLOG}
			createtigergroupfolderacl "$groupmode" "$dirgroup" "$foldername"
		else
			# Check for the group in the AD group list
			if [ -n "`awk 'BEGIN { FS = "\t" }; {print $2}' "$GROUPFILE" | $egrep "^$existingaclgroup$"`" ]; then
				# If it's there, skip ACL creation
				echo "AD-based ACL already exists on folder $foldername for group $existingaclgroup"  | tee -a ${OPERATIONSLOG}
				echo "Not creating new group ACL"  | tee -a ${OPERATIONSLOG}
			else
				# Otherwise, create the ACL
				echo "Creating group ACL for folder $foldername (non-AD ACL present)"  | tee -a ${OPERATIONSLOG}
				createtigergroupfolderacl "$groupmode" "$dirgroup" "$foldername"
			fi
		fi
	fi

        if [ ! -z "$dirowner" ]; then
		# Check for existence of user-based ACE, grab username
		existingacluser=`ls -led -- "$foldername" | $grep user | awk 'BEGIN { FS = ":" }; {print $3;exit}' | awk '{print $1}'`
        	# If this didn't return anything (there's no user ACE), create one
		if [ -z "$existingacluser" ]; then
			echo "Creating owner ACL for folder $foldername"  | tee -a ${OPERATIONSLOG}
			createtigerownerfolderacl "$ownermode" "$dirowner" "$foldername"
		else
                	# Check for the user in the AD user list
                	if [ -n "`awk 'BEGIN { FS = "\t" }; {print $2}' "$USERFILE" | $egrep "^$existingacluser$"`" ]; then
                        	# If it's there, skip ACL creation
                        	echo "AD-based ACL already exists on folder $foldername for user $existingacluser"  | tee -a ${OPERATIONSLOG}
                        	echo "Not creating new owner ACL"  | tee -a ${OPERATIONSLOG}
                	else   
                        	# Otherwise, create the ACL
                        	echo "Creating owner ACL for folder $foldername (non-AD ACL present)"  | tee -a ${OPERATIONSLOG}
                        	createtigerownerfolderacl "$ownermode" "$dirowner" "$foldername"
                	fi
		fi
	fi

}

# Create ACL on a file on Leopard or Snow Leopard
createleopardfileacl ()
{
	case "$1" in 
		r--)
			$("$chmod" +a "$2:allow:read,readattr,readextattr,readsecurity" "$filename")
			;;
		rw-)
			$("$chmod" +a "$2:allow:read,readattr,readextattr,readsecurity,write,append,writeattr,writeextattr,writesecurity,chown,delete" "$filename")
			;;
		rwx)
			$("$chmod" +a "$2:allow:read,readattr,readextattr,readsecurity,write,append,writeattr,writeextattr,writesecurity,chown,delete,execute" "$filename")
			;;
		-w-)
			$("$chmod" +a "$2:allow:write,append,delete,writeattr,writeextattr" "$filename")
			;;
		-wx)
			$("chmod" +a "$2:allow:write,append,writeattr,writeextattr,delete,execute" "$filename")
			;;
		r-x)
			$("chmod" +a "$2:allow:read,readattr,readextattr,readsecurity,execute" "$filename")
			;;
		--x)
			$("chmod" +a "$2:allow:execute" "$filename")
			;;
		---)
			;;
	esac
}

# Create Group ACL on a folder on Leopard or Snow Leopard
createleopardgroupfolderacl ()
{
	case "$1" in 
		r--)
			$("chmod" +a "$2:allow:list,search,readattr,readextattr,readsecurity,file_inherit,directory_inherit" "$foldername")
			;;
		rw-)
			$("chmod" +a "$2:allow:list,search,readattr,readextattr,readsecurity,add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown,file_inherit,directory_inherit" "$foldername")
			;;
		rwx)
			$("chmod" +a "$2:allow:list,search,readattr,readextattr,readsecurity,add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown,file_inherit,directory_inherit" "$foldername")
			;;
		-w-)
			$("chmod" +a "$2:allow:add_file,add_subdirectory,file_inherit,directory_inherit" "$foldername")
			;;
		-wx)
			$("chmod" +a "$2:allow:add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown,file_inherit,directory_inherit" "$foldername")
			;;
		r-x)
			$("chmod" +a "$2:allow:list,search,readattr,readextattr,readsecurity,file_inherit,directory_inherit" "$foldername")
			;;
		--x)
			$("chmod" +a "$2:allow:list,search,readattr,readextattr,readsecurity,file_inherit,directory_inherit" "$foldername")
			;;
		---)
			;;
	esac
}

# Create Owner ACL on a folder for Leopard or Snow Leopard
createleopardownerfolderacl ()
{
	case "$1" in 
		r--)
			$("chmod" +a "$2:allow:list,search,readattr,readextattr,readsecurity" "$foldername")
			;;
		rw-)
			$("chmod" +a "$2:allow:list,search,readattr,readextattr,readsecurity,add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown" "$foldername")
			;;
		rwx)
			$("chmod" +a "$2:allow:list,search,readattr,readextattr,readsecurity,add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown" "$foldername")
			;;
		-w-)
			$("chmod" +a "$2:allow:add_file,add_subdirectory" "$foldername")
			;;
		-wx)
			$("chmod" +a "$2:allow:add_file,add_subdirectory,delete,delete_child,writeattr,writeextattr,writesecurity,chown" "$foldername")
			;;
		r-x)
			$("chmod" +a "$2:allow:list,search,readattr,readextattr,readsecurity,file_inherit" "$foldername")
			;;
		--x)
			$("chmod" +a "$2:allow:list,search,readattr,readextattr,readsecurity,file_inherit" "$foldername")
			;;
		---)
			;;
	esac
}

# Parse permissions on a file on Leopard or Snow Leopard

parseleopardfilepermissions ()
{
	echo "Processing leopard permissions for file $1"  | tee -a ${OPERATIONSLOG}
	filename="$1"
	# Pull permissions, owner, and group, assign to array
	OLDIFS="$IFS"
	IFS=$' '
	echo "Grabbing permissions"
	permissions=(`ls -l -- "$filename" | awk '{print $1, $3, $4}'`)
	IFS="$OLDIFS"
	# Strip owner, group, and all permissions from mode string
	rawmode=${permissions[0]}
	ownermode=${rawmode:1:3}
	groupmode=${rawmode:4:3}
	allmode=${rawmode:7:3}
	owner=${permissions[1]}
	group=${permissions[2]}

	echo "$group	$PWD/$1" >> ${GROUPLOG}
	
	# Look up owner in tab-separated text file
	dirowner=`$grep $owner "$USERFILE" | awk 'BEGIN { FS = "\t" } ; {print $2;exit}'`
	#Look up group
	dirgroup=`$grep $group "$GROUPFILE" | awk 'BEGIN { FS = "\t" } ; {print $2;exit}'`
	# Check for null lookups, meaning the OD user or group isn't in the CSV
	if [ -z "$dirowner" ]; then
		echo "Owner $owner of file $filename not found in user list"  | tee -a ${OPERATIONSLOG}
	else
		dirowner="$ADDOMAIN\\$dirowner"
	fi
	
	if [ -z "$dirgroup" ]; then
		echo "Group $group for file $filename not found in group list"  | tee -a ${OPERATIONSLOG}
	else
		dirgroup="$ADDOMAIN\\$dirgroup"
	fi
	
	# Do all permissions first, then group, then owner
	# This should give us the ACLs in the correct order

        if [ ! -z "$dirgroup" ]; then
		# Check for existence of group-based ACE, grab group name
		existingaclgroup=`ls -le -- "$filename" | $grep group | awk 'BEGIN { FS = ":" }; {print $3;exit}' | awk '{print $1}' | sed -e 's/.*\\\\//'`
		# If this didn't return anything (there's no group ACE), create one
		if [ -z "$existingaclgroup" ]; then
			echo "Creating group ACL for file $filename"  | tee -a ${OPERATIONSLOG}
			createfileacl "$groupmode" "$dirgroup" "$filename"
		else
			# Check for the group in the AD group list
			if [ -n "`awk 'BEGIN { FS = "\t" }; {print $2}' "$GROUPFILE" | $egrep "^$existingaclgroup$"`" ]; then
				# If it's there, skip ACL creation
				echo "AD-based ACL already exists on file $filename for group $existingaclgroup"  | tee -a ${OPERATIONSLOG}
				echo "Not creating new group ACL"  | tee -a ${OPERATIONSLOG}
			else
				# Otherwise, create the ACL
				echo "Creating group ACL for file $filename (non-AD ACL present)"  | tee -a ${OPERATIONSLOG}
				createleopardfileacl "$groupmode" "$dirgroup" "$filename"
			fi
		fi
	fi

        if [ ! -z "$dirowner" ]; then
		# Check for existence of user-based ACE, grab username
		existingacluser=`ls -le -- "$filename" | $grep user | awk 'BEGIN { FS = ":" }; {print $3;exit}' | awk '{print $1}'`
		# If this didn't return anything (there's no user ACE), create one
		if [ -z "$existingacluser" ]; then
			echo "Creating owner ACL for file $filename" | tee -a ${OPERATIONSLOG}
			createleopardfileacl "$ownermode" "$dirowner" "$filename"
		else
	        	# Check for the user in the AD user list
                	if [ -n "`awk 'BEGIN { FS = "\t" }; {print $2}' "$USERFILE" | $egrep "^$existingacluser$"`" ]; then
                		# If it's there, skip ACL creation
				echo "AD-based ACL already exists on file $filename for user $existingacluser"  | tee -a ${OPERATIONSLOG}
				echo "Not creating new owner ACL"  | tee -a ${OPERATIONSLOG}
			else	
				# Otherwise, create the ACL
                        	echo "Creating owner ACL for file $filename (non-AD ACL present)"  | tee -a ${OPERATIONSLOG}
                        	createleopardfileacl "$ownermode" "$dirowner" "$filename"
			fi
		fi
	fi
}

# Parse permissions on a folder

parseleopardfolderpermissions ()
{
	echo "Processing leopard permissions for folder $1"  | tee -a ${OPERATIONSLOG} 
	foldername="$1"
	# Pull permissions, owner, and group, assign to array
	OLDIFS="$IFS"
	IFS=$' '
	permissions=(`ls -ld -- "$foldername" | awk '{print $1, $3, $4}'`)
	IFS="$OLDIFS"
	# Strip owner, group, and all permissions from mode string
	rawmode=${permissions[0]}
	ownermode=${rawmode:1:3}
	groupmode=${rawmode:4:3}
	allmode=${rawmode:7:3}
	owner=${permissions[1]}
	group=${permissions[2]}
	
	echo "$group	$PWD/$1" >> ${GROUPLOG}
	
	# Look up owner in tab-separated text file
	dirowner=`$grep $owner "$USERFILE" | awk 'BEGIN { FS = "\t" } ; {print $2;exit}'`
	#Look up group
	dirgroup=`$grep $group "$GROUPFILE" | awk 'BEGIN { FS = "\t" } ; {print $2;exit}'`
	# Check for null lookups, meaning the OD user or group isn't in the CSV
	if [ -z "$dirowner" ]; then
		echo "Owner $owner of folder $foldername not found in user list"  | tee -a ${OPERATIONSLOG}
	else
		dirowner="$ADDOMAIN\\$dirowner"
	fi
	
	if [ -z "$dirgroup" ]; then
		echo "Group $group for folder $foldername not found in group list"  | tee -a ${OPERATIONSLOG}
		dirgroup="$group"
	else
		dirgroup="$ADDOMAIN\\$dirgroup"
	fi

	# Do all permissions first, then group, then owner
	# This should give us the ACLs in the correct hierarchy
	
        if [ ! -z "$dirgroup" ]; then
		# Check for existence of group-based ACE, grab group name
		existingaclgroup=`ls -led -- "$foldername" | $grep group | awk 'BEGIN { FS = ":" }; {print $3;exit}' | awk '{print $1}' | sed -e 's/.*\\\\//'`
		# If this didn't return anything (there's no group ACE), create one
		if [ -z "$existingaclgroup" ]; then
			echo "Creating group ACL for folder $foldername"  | tee -a ${OPERATIONSLOG}
			createleopardgroupfolderacl "$groupmode" "$dirgroup" "$foldername"
		else
			# Check for the group in the AD group list
			if [ -n "`awk 'BEGIN { FS = "\t" }; {print $2}' "$GROUPFILE" | $egrep "^$existingaclgroup$"`" ]; then
				# If it's there, skip ACL creation
				echo "AD-based ACL already exists on folder $foldername for group $existingaclgroup"  | tee -a ${OPERATIONSLOG}
				echo "Not creating new group ACL"  | tee -a ${OPERATIONSLOG}
			else
				# Otherwise, create the ACL
				echo "Creating group ACL for folder $foldername (non-AD ACL present)"  | tee -a ${OPERATIONSLOG}
				createleopardgroupfolderacl "$groupmode" "$dirgroup" "$foldername"
			fi
		fi
	fi

        if [ ! -z "$dirowner" ]; then
		# Check for existence of user-based ACE, grab username
		existingacluser=`ls -led -- "$foldername" | $grep user | awk 'BEGIN { FS = ":" }; {print $3;exit}' | awk '{print $1}'`
        	# If this didn't return anything (there's no user ACE), create one
		if [ -z "$existingacluser" ]; then
			echo "Creating owner ACL for folder $foldername"  | tee -a ${OPERATIONSLOG}
			createleopardownerfolderacl "$ownermode" "$dirowner" "$foldername"
		else
                	# Check for the user in the AD user list
                	if [ -n "`awk 'BEGIN { FS = "\t" }; {print $2}' "$USERFILE" | $egrep "^$existingacluser$"`" ]; then
                        	# If it's there, skip ACL creation
                        	echo "AD-based ACL already exists on folder $foldername for user $existingacluser"  | tee -a ${OPERATIONSLOG}
                        	echo "Not creating new owner ACL"  | tee -a ${OPERATIONSLOG}
                	else   
                        	# Otherwise, create the ACL
                        	echo "Creating owner ACL for folder $foldername (non-AD ACL present)"  | tee -a ${OPERATIONSLOG}
                        	createleopardownerfolderacl "$ownermode" "$dirowner" "$foldername"
                	fi
		fi
	fi

}

# Recursively descend into the directory tree on Snow Leopard or Leopard

descendleopard ()
{
	echo "Descending into directory $1"  | tee -a ${OPERATIONSLOG}
	cd -- "$1"
	OLDIFS="$IFS"
	IFS=$'\n'
	for dotfile in $(find . -depth 1 -prune -name "._*")
	do
		if [ -e "$dotfile" ]; then
			parseleopardfilepermissions "$dotfile"
		fi
	done
	for item in *
	do
		if [ -d "$item" ]; then
			( descendleopard "$item" )
			parseleopardfolderpermissions "$item"
		else 
			if [ -e "$item" ]; then
				parseleopardfilepermissions "$item"
			fi
		fi
	done
	IFS="$OLDIFS"
}

# Process a folder non-recursively on Snow Leopard or Leopard

processleopardfolder ()
{
 	echo "Processing directory $1"  | tee -a ${OPERATIONSLOG}
	cd -- "$1"
	OLDIFS="$IFS"
	IFS=$'\n'
	for item in *
	do
		if [ -d "$item" ]; then
			parseleopardfolderpermissions "$item"
		else
			if [ -e "$item" ]; then
				parseleopardfilepermissions "$item"
			fi
		fi
	done
	IFS="$OLDIFS"
}
# Recursively descend into the directory tree

descendtiger ()
{
	echo "Descending into directory $1"  | tee -a ${OPERATIONSLOG}
	cd -- "$1"
	OLDIFS="$IFS"
	IFS=$'\n'
	for dotfile in $(find . -depth 1 -prune -name "._*")
	do
		if [ -e "$dotfile" ]; then
			parsetigerfilepermissions "$dotfile"
		fi
	done
	for item in *
	do
		if [ -d "$item" ]; then
			( descendtiger "$item" )
			parsetigerfolderpermissions "$item"
		else 
			if [ -e "$item" ]; then
				parsetigerfilepermissions "$item"
			fi
		fi
	done
	IFS="$OLDIFS"
}

# Process a folder non-recursively

processtigerfolder ()
{
 	echo "Processing directory $1"  | tee -a ${OPERATIONSLOG}
	cd -- "$1"
	OLDIFS="$IFS"
	IFS=$'\n'
	for item in *
	do
		if [ -d "$item" ]; then
			parsetigerfolderpermissions "$item"
		else
			if [ -e "$item" ]; then
				parsetigerfilepermissions "$item"
			fi
		fi
	done
	IFS="$OLDIFS"
}

# Usage message
usage(){
	cat <<EOF
usage: $0 options

This script recursively creates Access Control Entries based on the POSIX
permission on a folder hierarchy. If a user mapping file is specified with 
the -u flag, it will look up the local user and group and assign ACEs based
on the mapped user.

The primary Active Directory domain will be looked up using dscl. If another
AD domain is to be used, please use the -d flag and specify the AD domain.

If the -n flag is used, directory will not be processed recursively. Only 
items in the directory itself will be processed.

The user file should be tab-separated in this format: posixuser	directoryUID
Please specify the full path to the user file.

Logs will be ouput to /var/log/permissionsMigration - this folder will be
created if it doesn't exist. Each run of the script will create two log files,
called operation.MMDDHHMM.log and groups.MMDDHHMM.log. The operations log will
contain an entry for every file and folder processed. Operations will also be
echoed to STDOUT. The groups log will contain one line for every file and
folder, with the group ownership of the item and its full path.

OPTIONS:
  	-h	Show this message
	-u	User file
	-g	Group file
	-f	Folder name
	-d	Active Directory Domain
	-n	Process folder non-recursively

EOF
}

while getopts “hu:g:f:d:n” OPTION
	do
    	case $OPTION in
        	h)
            	usage
            	exit 1
            	;;
			u)
			 	USERFILE=$OPTARG
				;;
			g)
				GROUPFILE=$OPTARG
				;;
        	f)
            	FOLDERNAME=$OPTARG
            	;;
			d)
				ADDOMAIN=$OPTARG
				;;
			n)
				RECURSIVE=0
				;;
        	?)
            	usage
            	exit
            	;;
		esac
done

# Should be run as root to work properly
if [ "$EUID" -ne 0 ]; then
   echo "This script must be run as root"
   exit 1
fi

# Test for log folder, create it if it doesn't exist
if [ ! -e "$LOGFOLDER" ]; then
	mkdir "$LOGFOLDER"
	
	if [ ! -e "$GROUPLOG" ]; then
		touch "$GROUPLOG"
	fi

	if [ ! -e "$OPERATIONSLOG" ]; then
		touch "$OPERATIONSLOG"
	fi
fi

# Output STDERR to operations logs
exec 2>>"$OPERATIONSLOG"

# Test for existence of the user and group files before proceeding
if [ -e "$USERFILE" ]; then
	if [ -e "$GROUPFILE" ]; then
		if [ -e "$FOLDERNAME" ]; then
			case $OSTYPE in
				"darwin8.0" )
					if [ "$RECURSIVE" -eq 1 ];then
						descendtiger "$FOLDERNAME"
					else
						processtigerfolder "$FOLDERNAME"
					fi
					;;
				"darwin9.0" | "darwin10.0" )
					if [ "$RECURSIVE" -eq 1 ];then
						descendleopard "$FOLDERNAME"
					else
						processleopardfolder "$FOLDERNAME"
					fi
					;;
				* )
					echo "Operating System is not Tiger, Leoapard or Snow Leopard"
					echo "Exiting"
					exit 1
			esac
		else
			echo "Folder doesn't exist or was not specified"
			exit 1
		fi
	else
		echo "Group file doesn't exist or was not specified"
		exit 1
	fi
else
	echo "User file doesn't exist or was not specified"
	exit 1
fi
