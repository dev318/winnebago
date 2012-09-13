# Winnebago
### Downloading & Installing the tool
git clone the tool ( you can use the http://mac.github.com client ).
Copy the example configuration file https://github.com/dev318/winnebago/downloads
Rename the configuration file to .winnebago.conf in the main xcode project directory
Edit the dialog text in to com.github.winnebago.settings.plist & .winnebago.conf & html file.
sudo ./pkg_build.sh in the main directory


## A user migration suite
Winnebago is a tool that I have been working ( and have rewritten ) for a couple of years.
It basically a cocoa wrapper for a series of scripts that need to run in a specific order.
The initial installation of the Winnebago is done through the [Winnebago (install)] policy. This policy runs the latest version of the winnebago.pkg package. This installer creates the application and launchd item that invokes the application. The postinstall script loads the launchd item, triggered at a later date using the [Winnebago (trigger)] policy.

### winnebago.pkg
The exit status of this postinstall is the launchctl command. If the command is successful loading the launchd item then installation will be successful in Casper. If the command is unsuccessful the installation should show in red. This can be replicated with the following command as a failure measure or to ensure the file is loaded properly, as needed.
`/bin/launchctl load -w /Library/LaunchDaemons/com.github.winnebago.plist`

### Trigger Policy
The secondary policy [Winnebago (trigger)] creates the trigger file. This file is keyed to launch (and relaunch) the main application. Until this file is created the launchd item will be loaded but will not launch the application. This file is also referenced by the application itself, it uses the initial creation date to determine how many days (rounded) the user can postPone (defer) the launch of the process. At the end of this process the “postPone” buttons are greyed out. The days interval is calculated using the modification date of “/Library/Caches/.runADUtility” and compared to the requiredDays key in  “/Library/Application Support/Winnebago/Winnebago.app/Contents/Resources/com.github.winnebago.settings.plist”

### Launchd Item
The launchd item is currently stored 
as /Library/LaunchDaemons/com.github.winnebago.plist
`{
    KeepAlive =     {
        PathState =         {
            "/Library/Caches/.runADUtility" = 1;
        };
    };
    Label = "com.github.winnebago";
    ProgramArguments =     (
        "/Library/Application Support/Winnebago/Winnebago.app/Contents/MacOS/Winnebago"
    );
    StandardErrorPath = "/Library/Logs/Winnebago/Winnebago.log";
    StandardOutPath = "/Library/Logs/Winnebago/Winnebago.log";
    ThrottleInterval = 10800;
}`
The 3 hour time relaunch is handled by the ThrottleInterval key , this is due to the fact that the StartCalendarInterval is not viable in the way we needed it to be to launch the tool. The only byproduct of this issue is that the script will load immediately when triggered, then 3 hours after that if deferred. On a subsequent reboot, the script will load 3 hours into the login session (because it can’t load on reboot due to the window server issue). The LimitLoad ToSessionType was not used because it produced inconsistent results. A LaunchAgent was also initially created but was shown to be less consistent about reloading correctly on reboot with out timing schedule than the solution used.

### Manually running the tool
This launch deamon, when triggered, will directly run the executable inside the .app bundle. This is the only valid run method for this tool, launching manually via double clicking as the user will cause all scripts to exit 1 as they do not have sufficient privileges to run. if you would like to run the tool manually you can do so by using the following command (as an administrator):
`sudo "/Library/Application Support/Winnebago/Winnebago.app/Contents/MacOS/Winnebago"`

These two policies must be scoped to the correct machines, and must be run consecutively; however the “trigger” policy should only be deployed to machines on which you wish to “trigger” or run the software AFTER it had been installed. The count down  for the users ability to postpone is (5) days from when that policy runs.

The tool is the highest window level on the system and will show above all open applications. 
_Note: Users at the screen saver must authenticate before the tool will take keyboard input (standard Mac OS X policy)._
The launchd item is erased on reboot when the script reaches the postFlight.sh phase referenced later in this document.

## Sanity Checks

A number of sanity checks are built into the solution, outlined below.
### Network Check

The tool runs the netCheck.sh script to determine if systems are connected to the company network. Whether systems are connected is determined by the exit status of this script 0 == connected. There is an initial test of ldap access to ad.example.com, and if that is unsuccessful there are three pings sent to the following host variables in “/Library/Application Support/Winnebago/Winnebago.app/Contents/Resources/.winnebago.conf”

`export DomainController0="ad.example.com"
export DomainController1="dc01.example.com"
export DomainController2="dc02.example.com"
export DomainController3="dc03.example.com"`

The “Try Again” button will re-run this script until the exit status is 0. The “Postpone” button here is also keyed off of the creation date of the /Library/Caches/.runADUtility file and will grey out if past the requiredDays value (i.e. 5 days).

The Open VPN button will launch the VPN tool, which per onsite interviews and consultations should cause an automatic connection to the network. This action is controlled using the main graphical configuration file “/Library/Application Support/Winnebago/Winnebago.app/Contents/Resources/com.github.winnebago.settings.plist”

This button initially tries to launch the tool referenced in the key vpnToolPath, if that launch is unsuccessful it will attempt to load the tool using the bundle id. If it has been moved to another location , the bundle launch should locate and launch the correct application.

The postFlight.sh script attempts to disconnect the VPN if the VPN is connected prior to reboot. This assists with DirectoryService/opendirectoryd timeouts. The vpn is then disconnected and the DirectoryService process is restarted without the network connection present. The cisco command line tools seem to hang if this is done when the vpn is not connected so the tool is looking for the utun0 interface in the output of ifconfig.

### Battery Power Check
The tool then runs the checkBatt.sh script and determines if the system is on AC power. On desktop clients this will always return 0; on laptops, the return code is based on the output of the ‘pmset -g batt’ command. Clicking OK will rerun the Test until the command exits 0.

### Username input
The user is then asked to type in their Active Directory username. This is validated later int the script, but the correct value is the sAMAccountName or “shortname” of the user. 

At the time of this writing there is no automatic username lookup, but that could be added to the tool with more development time and could be looked up from the wireless certificate name if needed. A feature request was added in but not completed and can be reference here:

https://github.com/dev318/winnebago/issues/2

The window will then expand to reveal the password field and shift the keyboard focus to that field (and a hidden cleartext field that can be displayed using the “Show Password” checkbox ).


### Local Password Sync Check
Once a user enters their password, the tool attempts to validate the password against the local machine _before_ it attempts to validate on the network. If the passwords are out of sync, no matter the local username, the user will be presented with an additional panel to enter in their local password. This dialog is suppressed in the instance where the user’s password is the same as the network password, no matter the local username. These two credentials are then used together in order to update the user’s keychain password. In the case of a revert, they are used to validate if the reverting of the account was successful. This process is handled using the checkLocalBind.sh script.

### Network Password Check

The password is then validated against Active Directory using LDAP via the checkBind.sh script. This will be the last user interaction before the process complete panel of the script. This script loops until it exits 0, allowing the user to re-enter the password if mistyped.

### Main Run Loop
Once the credentials have been validated by the sanity checking scripts the main run loop will commence. This loop is defined in the “/Library/Application Support/Winnebago/Winnebago.app/Contents/Resources/com.github.winnebago.settings.plist” and runs a series of scripts in consecutive order. The scriptPlugins: mainRunLoopScripts: com.githube.winnebago: itemScripts key in the preference is an array that controls what script runs, its order in the array is its run order and its sub keys are the text displayed based on its exit status. 

### Exit Status
At the time of this writing there were 10 scripts being run in the main loop, explored later in this document. To be clear, these are separate from the checkNetwork style scripts and revertChanges, which run before or conditionally after these scripts in the main loop.

At the time of this writing all items are contained in the Resources directory of the .app bundle. The absolute path is “/Library/Application Support/Winnebago/Winnebago.app/Contents/Resources” at time of initial installation.

To add additional scripts, add items to this array and the associated script and image files to the Resources directory of the application. Alternatively, modify the preflight.sh and postFlight.sh files, meant to run before and after the process is complete.

The level indicator shows you at which script in the array you are running, i.e. the first tick mark is the preflight script and the last tick mark is the postflight script.

### Current script execution order
At the time of this writing, this was the following order of the scripts
These scripts all reference (source) common.sh and the hidden configuration file “/Library/Application Support/Winnebago/Winnebago.app/Contents/Resources/.winnebago.conf” which stores values like email address used for notifications, and the bind username and password. This file is not automatically deleted, once the migration is complete, you should consider, removing this file, or the entire .app bundle for security. 
Debug for all scripts can be enabled by uncommenting the DebugScript line in this file, however passwords will be displayed in clear text in logs so use with caution.

### Modifying the Runtime Script Text
`StatusMSG $ScriptName "Migrating Account..." uiphase`
`StatusMSG $ScriptName "Step Complete" uistatus`

The shell scripts use a function named "StatusMSG" which is declared in the common.sh ( sourced by all children scripts ) . This function allows for multiple positional parameters. The typical usage is as follows:
When called in the main body of the script (Note: $ScriptName is declared in all scripts)
`	StatusMSG "$ScriptName" "<my message>" "<my ui type>" "<custom delay>"`
When called within a function of the script (Note: $FUNCNAME is set by the shell)
`	StatusMSG "$FUNCNAME" "<my message>" "<my ui type>" "<custom delay>"`

Use of the above FUNCNAME in the main body of the script will cause the message not to be displayed as the empty variable will not be defined and the positional parameters will be shifted. You can see this symptom by searching for "uistatus" or "uiphase" in the Scripts log file, as this data ( Parameter $1) is logged and not shown to the user.
The "Custom Delay" (Parameter $4) is not defined for all statements, it allows for a custom value to be set for the artificial delay used. This value will iterate to one ( sleep 1) when this value is not set. You can set it to values such as 0.5 to decrease the time the file is left on the file system. If greater responsiveness is required , the use of FIFO pipes could be used in a version 2.0 of the cocoa application to allow for more real time updates.

The progress bar is set using the setInstallPercemtage function, and when not set will display and indeterminate progress bar. The begin and die function deletes the previous bridge files each script run.

### Warnings and Critical Failures (revert account)
If any script has an exit status greater than 1 (e.g. 200, the standard in the scripts calling the FatalError function) the script will stop execution of the main run loop and run the revertChanges.sh script.

### Critical Failures
The revert changes script uses the files in /Library/Caches to reimport the previous account, this will restore the previous account, rename the home folder if necessary and  restore the users password file. The revert script attempts to validate that the restored account can authenticate to the system. This final test determines if the error is a warning or critical. In other words if the previous local account is able to authenticate then the warning message (yellow icon) is displayed. If the local account was not able to be imported successfully the critical error message (red icon) is displayed.  Normally critical errors are major script logic errors and are rare.and  restore the users password file. The revert script attempts to validate that the restored account can authenticate to the system. This final test determines if the error is a warning or critical. In other words if the previous local account is able to authenticate then the warning message (yellow icon) is displayed. If the local account was not able to be imported successfully the critical error message (red icon) is displayed.  Normally critical errors are major script logic errors and are rare.

In the rare event of a critical error, the user may not be able to login as the previous account and their system should be restored manually.

### Manually Running the Revert Script
In advanced failures (system crash, unexpected reboot) this script can be ran manually with the following parameters 
`/Library/Application\ Support/Winnebago/Winnebago.app/Contents/Resources/revertChanges.sh -l luser -L lpass -n zsmit3 -N f00b4r`
### Modifying UI elements
The following section outlines how to manage the various User Interface (or UI for short) elements in the solution.
#### Proceed Panel
Due to the request of clickable links on the main panel, The initial proceedPanel is webkit displaying an html file located at “/Library/Application Support/Winnebago/Winnebago.app/Contents/Resources/proceedPanel.html”
side from the StatusMSG functions referenced in the scripts themselves, the main ui configuration information is in the  “/Library/Application Support/Winnebago/Winnebago.app/Contents/Resources/com.github.winnebago.settings.plist” file.

#### Warning Panel
The revertText key in “/Library/Application Support/Winnebago/Winnebago.app/Contents/Resources/com.github.winnebago.settings.plist” configures the Warning error message that is displayed to the end user
#### Critical Panel
The failureText key in “/Library/Application Support/Winnebago/Winnebago.app/Contents/Resources/com.github.winnebago.settings.plist” configures the Critical error message that is displayed to the end user
#### Process Complete Panel
The processCompleteText key in “/Library/Application Support/Winnebago/Winnebago.app/Contents/Resources/com.github.winnebago.settings.plist” configures the Process Complete message displayed to end users.

### Individual Script End Statuses
The following keys shown above can be modified to change the script feedback to the end user. While other keys exist they are for more advanced runs of the tool are not documented here. If you need more flexibility in the scripts exit status, additional development can be provided to do so.


### Security concerns
Please note for security the .winnebago.conf should not be not included in the xcode build folder (checkout .gitignore) if you merge changes in this repo.

More to come later, will post links to MacSysAdmin preso

#To Do:
1. Move all dialogs to WebKit rather then plist text keys.
2. Consolidate configuration files (source file & plist)
3. Convert all NSTasks/Scripts to use Environmental variables rather then passed parameters.
4. Allow custom images to be passed from shell functions.
5. Change uibridge to NSConnections
6. Convert BASH binding script to python, ruby...
