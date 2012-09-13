On Error Resume Next
'Created by Zack Smith zsmith@318.com

Dim strADDomain		' AD Domain i.e. example.com or EXAMPLE
Dim strADBindUPN	' AD Bind UPN i.e. delegate@domain.com (>XP)
Dim strADBindPass	' AD Bind Password for the UPN Specified
Dim strLocalAdmin	' The Local Administrator Username for RPC
Dim strLocalPass	' The Local Administrator Password for RPC
Dim strNameFormat	' The name format in-use elp is %s%d%c%d%a
Dim strDelimiter	' This is the delimiter used for %d i.e. "-"
Dim strScriptName	' This is the name of the script minus (.vbs)


'****************************************************************
' Script Configuration
'****************************************************************
strADDomain = "ad.example.com"
strADBaseDN = "DC=ad,DC=yelpcorp,DC=com"

'	Active Directory Domain Credentials
strADBindUPN = "adjoin@ad.example.com"
strADBindPass = "hsjdfkahfhjksdf"

'	Local sysprep credentials
strLocalAdmin = "administrator"
strLocalPass = ""

'	Auto Reboot
boolReboot = True

strDefaultADOU = "CN=Computers, " & strADBaseDN
strADOUformat = "OU=Computers,OU=Example," & strADBaseDN
'	String Representation of Distinguished Name (RFC 1779)
'	%s Site Name based on IP block
'	%t Site type based on IP block

intWaitForOveride = 10
' Time to wait for overide

'strADOUformat	= "CN=Computers, " & strADBaseDN
' You can also redirect CN=Computers using redircmp:
'http://support.microsoft.com/default.aspx/kb/324949



strNameFormat = "%s%d%c%d%a"
strDelimiter = "-"
intMaxLogSize = 5 ' Megabytes(Default should be more then needed)
'****************************************************************
' Run Time Varibles
'****************************************************************


strScriptName = Replace(WScript.ScriptName,".vbs","")

pathScriptLog = "C:\" & strScriptName & ".txt"
'****************************************************************
' OpenTextFile Constants
'****************************************************************
Const ForReading   =		0
Const ForWriting   =		1
Const ForAppending = 		8


Set objStatusFSO = CreateObject("Scripting.FileSystemObject")
Set objLogFile = objStatusFSO.OpenTextFile(_
					pathScriptLog,ForAppending,True)
Set objCheckSze = objStatusFSO.GetFile(pathScriptLog)

' Delete the Log file if over the MAX Log Size Value.
'If objCheckSze.Size < (intMaxLogSize * 1024 * 1024 ) Then
	'objStatusFSO.DeleteFile(pathScriptLog)
'End If
objLogFile.WriteBlankLines(1)
objLogFile.WriteLine "STARTED:  " & strScriptName & " :" & Now




'# Status message subroutine
Sub subStatusMessage(strStatusType,strStatusMessage)
	Select Case strStatusType
		Case "progress"
			WScript.Echo "PROGRESS: " & strStatusMessage
			objLogFile.WriteLine "PROGRESS: " & strStatusMessage
		Case "notice"
			WScript.Echo "NOTICE:   " & strStatusMessage
			objLogFile.WriteLine "NOTICE:   " & strStatusMessage
		Case "error"
			WScript.Echo "ERROR:    " & strStatusMessage
			objLogFile.WriteLine "ERROR:    " & strStatusMessage
		Case "verbose"
			If strLogLevel = "Verbose" Then
				WScript.Echo "VERBOSE:  " & strStatusMessage
			End If
			objLogFile.WriteLine "VERBOSE:  " & strStatusMessage
		Case "header"
			WScript.Echo "HEADER: " & strStatusMessage
			objLogFile.WriteLine "HEADER: " & strStatusMessage
		Case "passed"
			WScript.Echo "PASSED: " & strStatusMessage
			objLogFile.WriteLine "PASSED:   " & strStatusMessage
		Case "graphical"
			MsgBox strStatusMessage
	End Select
End Sub


'ArgHandler

	set Arguments = WScript.arguments

	For Switch = 0 to (Arguments.count -1)

		Select Case Arguments.item(Switch)

			Case "/v" : strLogLevel = "Verbose"
			Case "/r" : boolReboot = True
			Case "/s" : bolWriteSysPrep = True
			Case "/i" : strOverRideIP = Arguments.Item(Switch + 1)
			Case "/u" : Call subUnJoin
		end Select
	Next
	
If strLogLevel = "Verbose" Then
	'show / use input :

	Call subStatusMessage("verbose","the input was :")

		Call subStatusMessage("verbose","i: " & strOverRideIP)

End If

'****************************************************************
Set objWMIService = GetObject("winmgmts:{impersonationLevel=" & _
								"Impersonate}!\\.\root\cimv2")
Set colItems = objWMIService.ExecQuery _
("Select * From Win32_NetworkAdapterConfiguration" & _
							" Where IPEnabled = True")
For Each objItem in colItems
' Example overide code for adapter specific models like Macs
' Where bluetooth shows up as the first MAC address
'	If Instr(AdapterDesc, "Gigabit Ethernet") Then
'	MacAddress =  Replace(objItem.MACAddress,":","")
'	MacAddress =  Left(MacAddress,7)
'	End If
	MacAddress =  Replace(objItem.MACAddress,":","")
	MacAddress =  Right(MacAddress,6)
	

exit For
' Stop on Primary Ethernet MAC Address
Next
' IP Address check
For Each objItem in colItems
	' Check for Invalid IP, and Skip (Wireless)
	If Not objItem.IPAddress(0)= "0.0.0.0" Then
		IPAddress = objItem.IPAddress(0)
		Exit For
	End IF
' Stop on Found IP Address
Next
Set colItems = objWMIService.ExecQuery _
("Select * from Win32_OperatingSystem")
	For Each objItem in colItems
		SystemVersionNumbers = objItem.Version
		SystemVersionNumber = Split(SystemVersionNumbers,".")
		If SystemVersionNumber(0) = "5" Then
			SystemVersion = "X"
		end if
		If SystemVersionNumber(0) = "6" Then
			SystemVersion = "X"
		end If
	exit for
Next

Set colChassis = objWMIService.ExecQuery _
   ("Select * from Win32_SystemEnclosure")
For Each objChassis in colChassis
	For  Each strChassisType in objChassis.ChassisTypes
		Select Case strChassisType
			Case 1 ' Other i.e. VM
				HardwareType = "V"
			Case 2 ' Unknown
				HardwareType = "D"
			Case 3 ' Desktop
				HardwareType = "D"
			Case 4 ' Low Profile Desktop
				HardwareType = "D"
			Case 5 ' Pizza Box
				HardwareType = "D"
			Case 6 ' Mini Tower
				HardwareType = "D"
			Case 7 ' Tower
				HardwareType = "D"
			Case 8 ' Portable
				HardwareType = "L"
			Case 9 ' Laptop
				HardwareType = "L"
			Case 10 ' Notebook
				HardwareType = "L"
			Case 11 ' Hand Held
				HardwareType = "L"
			Case 12 ' Docking Station
				HardwareType = "L"
			Case 13 ' All in One
				HardwareType = "D"
			Case 14 ' Sub Notebook
				HardwareType = "L"
			Case 15 ' Space-Saving
				HardwareType = "D"
			Case 16 ' Lunch Box
				HardwareType = "D"
			Case 17 ' Main System Chassis
				HardwareType = "D"
			Case 18 ' Expansion Chassis
				HardwareType = "D"
			Case 19 ' SubChassis
				HardwareType = "D"
			Case 20 ' Bus Expansion Chassis
				HardwareType = "D"
			Case 21 ' Peripheral Chassis
				HardwareType = "D"
			Case 22 ' Storage Chassis
				HardwareType = "D"
			Case 23 ' Rack Mount Chassis
				HardwareType = "D"
			Case 24 ' Sealed-Case PC
				HardwareType = "D"
			Case Else ' Default to Desktop
				HardwareType = "D"
		End Select
	next
Next
' For more information on this API see:
'http://msdn.microsoft.com/en-us/library/aa394474.aspx
Const wshYes = 6
Const wshNo = 7
Const wshYesNoDialog = 4
Const wshQuestionMark = 32

Set objShell = CreateObject("Wscript.Shell")

intReturn = objShell.Popup("Use current ip : " & IPAddress & "?" &_
vbCr & vbCr & "Press Yes to use this IP, or No to input an overide" & vbCr & _
 "This Box will be dismissed in 10 seconds",_
    intWaitForOveride, "Overide IP:", wshYesNoDialog + wshQuestionMark)

If intReturn = wshYes Then
    Call subStatusMessage("verbose",_
    			"User clicked yes to continue")
ElseIf intReturn = wshNo Then
	Call subStatusMessage("verbose",_
		"User clicked NO, prompted for overide")
		strOverRideIP = InputBox("Enter in Overide IP" & vbCr & _
		"Use format 1.2.3.4 for site resolution","Overide IP",IPAddress)
Else
    Call subStatusMessage("verbose",_
    	"Overide IP prompt timed out, continuing...")
End If
'****************************************************************
' Asset Tag
'****************************************************************
'HKEY_CURRENT_USER = HKCU
'HKEY_LOCAL_MACHINE = HKLM
'HKEY_CLASSES_ROOT = HKCR
'HKEY_USERS = HKEY_USERS
'HKEY_CURRENT_CONFIG = HKEY_CURRENT_CONFIG

RegAssetTag = ReadReg("HKCU\Example\AssetTag")
If Len(RegAssetTag)>0 Then 
	AssetTag = ReadReg("HKCU\Example\AssetTag")
Else
	AssetTag = InputBox("Enter Asset Tag","Tag:")
	RegAssetTag = WriteReg("HKCU\Example\AssetTag",AssetTag,"REG_SZ")
End If

Function WriteReg(RegPath, Value, RegType)
      'Regtype should be "REG_SZ" for string, "REG_DWORD" for a integer,…
      '"REG_BINARY" for a binary or boolean, and "REG_EXPAND_SZ" for an expandable string
      Dim objRegistry, Key
      Set objRegistry = CreateObject("Wscript.shell")

      Key = objRegistry.RegWrite(RegPath, Value, RegType)
      WriteReg = Key
End Function
Function ReadReg(RegPath)
      Dim objRegistry, Key
      Set objRegistry = CreateObject("Wscript.shell")
      Key = objRegistry.RegRead(RegPath)
      ReadReg = Key
End Function

'If Result=1 Then
'	call Restart
'Else if Result=2 Then
'	wscript.echo "reboot Cancelled"
'End if 
' Check if OverRide IP has been Set
If IsEmpty(strOverRideIP) Then
	' If none given use detected
	SubNet = Split(IPAddress,".")
Else
	Call subStatusMessage("notice", "Using IP Overide : " & strOverRideIP)
	' If overide specfied use that
	SubNet = Split(strOverRideIP,".")
End If

SubNetRange = SubNet(0) & "." & SubNet(1) & "." & Subnet(2)
' Split the IP along its octets and use a Case statment on 3/4
Select Case SubNetRange
'****************************************************************
' SFO Campus
'****************************************************************
' IT Dept
	Case "192.168.30"
   		strSiteName = "IT" : strSiteType = "Example"
	Case Else ' Default to below if an IP is missing
		strSiteName = "YELP" : strSiteType = "NA"
   		Call subStatusMessage("notice",_
   				"Unknown IP: " & IPAddress )
end Select

'****************************************************************
' Assemble computer name using format specified
'****************************************************************
strAssembledName = strNameFormat
strAssembledName = Replace(strAssembledName,"%s",strSiteName)
strAssembledName = Replace(strAssembledName,"%d",strDelimiter)
strAssembledName = Replace(strAssembledName,"%o",SystemVersion)
strAssembledName = Replace(strAssembledName,"%c",HardwareType)
strAssembledName = Replace(strAssembledName,"%m",MacAddress)
strAssembledName = Replace(strAssembledName,"%a",AssetTag)


'****************************************************************
' Replace the custom OU format varibles
'****************************************************************
strADOU = strADOUformat
strADOU = Replace(strADOU,"%s",strSiteName)
strADOU = Replace(strADOU,"%t",strSiteType)
Call subStatusMessage("verbose", "Assembled OU: " & strADOU)

Sub subRenameComputer(strRenameAdmin,strRenamePass)

' Look up current computer name in registry
regActiveComputerName = "HKLM\SYSTEM\CurrentControlSet\" & _
	"Control\ComputerName\ActiveComputerName\ComputerName"
Set objRegShell = CreateObject("WScript.Shell")
strActiveComputerName = objRegShell.RegRead(regActiveComputerName)
Call subStatusMessage("progress","Current Name: " & strActiveComputerName)
If strActiveComputerName = strAssembledName Then
	Call subStatusMessage("notice",_
		"The Machine is already named correctly : " &  strAssembledName)
		Exit Sub
End If	'END strActiveComputerName = strAssembledName

Set objWMIService = GetObject("Winmgmts:{impersonationLevel=" & _
									"Impersonate}!\\.\root\cimv2")
strTry = 1
For Each objComputer in _
   objWMIService.InstancesOf("Win32_ComputerSystem")

       intReturn = objComputer.Rename(strAssembledName, _
       								strRenamePass, _
       								strRenameAdmin)
       If intReturn = 1326 Then
       		strTry = strTry + 1
       		Call subStatusMessage("verbose",_
       				"Renaming computer in domain")
       		Call subRenameComputer(strADBindUPN,strADBindPass)
       End if
       If intReturn <> 0 Then
       		If intReturn = 1326 And strTry > 1 Then
       			Call subStatusMessage("error",_
       			 	"Unable to contact DC for Rename")
       			 Call subStatusMessage("Notice",_
       			 	"Was Machine rebooted after joining?")
       		Else
       			 Call subStatusMessage("error",_
       			 	"Rename failed. Error = " & intReturn)
       		End if
       Else
       		Call subStatusMessage("passed",_
          					"Rename succeeded. New Name:" &_
          					 strAssembledName)
          	Call subStatusMessage("notice",_
          		"Reboot for new name to go into effect")
       End If
		Call subReboot
Next	'END: For Each objComputer in
End Sub

Sub subReboot()
		If boolReboot Then ' Check is Reboot Flag is enabled (/r)
		    Call subStatusMessage("notice",_
       						 "Rebooting . . . ")
			Set OpSysSet =GetObject("Winmgmts:{(Shutdown)}//" & _
				"./root/cimv2").ExecQuery("select * from " & _
					"Win32_OperatingSystem where Primary=true")
				For each OpSys in OpSysSet
			    	If OpSys.Reboot()= 0 Then
			    		Call subStatusMessage("passed",_
			    					"Computer Rebooted" )
			    	Else
			    		Call subStatusMessage("error",_
			    					" Reboot Failed")
			    	End If
				Next
			End If
End Sub 'subReboot()

'****************************************************************
' Main Routine
'****************************************************************
If bolWriteSysPrep Then
	Call subStatusMessage("verbose","Writing sysprep file C:\sysprep\sysprep.inf ")
	WriteINIString "UserData", "ComputerName", strAssembledName, "C:\sysprep\sysprep.inf"
	WScript.Quit
End If

Call subRenameComputer(strLocalAdmin,strLocalPass)
If boolRenameOnly Then WScript.Quit
'****************************************************************
' Join Computer to Domain
'****************************************************************
' Constants
Const JOIN_DOMAIN				= 1
Const ACCT_CREATE				= 2
Const ACCT_DELETE				= 4
Const DOMAIN_JOIN_IF_JOINED		= 32
Const JOIN_UNSECURE				= 64
Const INSTALL_INVOCATION		= 262144
' http://msdn.microsoft.com/en-us/library/aa392154(VS.85).aspx

Set objNetwork = CreateObject("WScript.Network")
strCurrentName = objNetwork.ComputerName
Set objNetwork = Nothing ' Release Network Object

Set objWMIComputer = GetObject( _
"Winmgmts:{impersonationLevel=Impersonate}!\\.\root\cimv2")
For Each objComputerSystem in _
			objWMIComputer.InstancesOf("Win32_ComputerSystem")
Call subStatusMessage("progress",_
	"Attempting to join Domain: " & strADDomain)
 intJoinReturnValue = objComputerSystem.JoinDomainOrWorkGroup(_
 												strADDomain, _
                                             strADBindPass, _
                                             strADBindUPN, _
                                             strADOU, _
									JOIN_DOMAIN + ACCT_CREATE)
Call subStatusMessage("progress",_
	"Intial join process has completed : Status = " & intJoinReturnValue)
' Check if join failed due to exisiting Account
If intJoinReturnValue = 2 Then
Call subStatusMessage("notice","Trying secondary bind...")
Call subStatusMessage("notice","Reset OU to : " & strDefaultADOU )
	intJoinReturnValue = objComputerSystem.JoinDomainOrWorkGroup(_
											strADDomain, _
                                            strADBindPass, _
                                            strADBindUPN, _
                                            strDefaultADOU, _
                                            JOIN_DOMAIN + ACCT_CREATE)
End If
 If intJoinReturnValue = 2224 Then
 Call subStatusMessage("progress",_
 	"Joining computer with existing account:")  
 	intJoinReturnValue = objComputerSystem.JoinDomainOrWorkGroup(_
											strADDomain, _
                                            strADBindPass, _
                                            strADBindUPN, _
                                            strADOU, _
                                            JOIN_DOMAIN)                           

End If
' JoinDomainOrWorkGroup Minimum supported client Windows XP / 03
'****************************************************************
fncADJoinMessage(intJoinReturnValue) ' Display Join Message
Call subReboot
Next



Function fncADJoinMessage(intExitNumber)
Select Case intExitNumber
	Case 2 Call subStatusMessage("error",_
		"An error occured joining the domain" )
	Case 0 Call subStatusMessage("passed",_
		"Welcome to the " & strADDomain & " Domain") : Call subReboot
	Case 5 Call subStatusMessage("error",_
		"Access is denied, Check Access Control")
	Case 87 Call subStatusMessage("error",_
		"A parameter is incorrect by review")
	Case 110 Call subStatusMessage("error",_
		"Unable to open specified Object")
	Case 1323 Call subStatusMessage("error",_
		"Unable to update computer password")
	Case 1326 Call subStatusMessage("error",_
		"Bad Login: Domain credentials invalid")
	Case 1355 Call subStatusMessage("error",_
		"Invalid Domain,or unable to contact DC")
	Case 2224 Call subStatusMessage("notice",_
		"The computer account already exists")
	Case 2691 Call subStatusMessage("error",_
		"Computer is already joined to the domain, use /u to unjoin")
		WScript.Quit
	Case 2692 Call subStatusMessage("notice",_
	"Machine is not currently joined to a domain")
	End Select
End Function

Sub subUnJoin()
Call subStatusMessage("progress","Unjoining from domain..")
Const NETSETUP_ACCT_DELETE = 2 
Set objNetwork = CreateObject("WScript.Network")
strComputer = objNetwork.ComputerName
 Set objComputer = GetObject("winmgmts:{impersonationLevel=Impersonate}!\\" & _
 strComputer & "\root\cimv2:Win32_ComputerSystem.Name='" & strComputer & "'")
intReturn = objComputer.UnjoinDomainOrWorkgroup _
 (strADBindPass, strADBindUPN, NETSETUP_ACCT_DELETE)
 ' JoinDomainOrWorkGroup Minimum supported client Windows XP / 03
 If intReturn = 0 Then
 	Call subStatusMessage("progress","Unjoin sucessful, reboot needed")
 	Call subReboot
 Else
 	Call subStatusMessage("error","Unjoin failed with Error = " & intReturn )
 	Call fncADJoinMessage(intReturn)
 End if
 WScript.Quit
End Sub

'Work with INI files In VBS (ASP/WSH)
'v1.00
'2003 Antonin Foller, PSTRUH Software, http://www.motobit.com
'Function GetINIString(Section, KeyName, Default, FileName)
'Sub WriteINIString(Section, KeyName, Value, FileName)

Sub WriteINIString(Section, KeyName, Value, FileName)
  Dim INIContents, PosSection, PosEndSection
  
  'Get contents of the INI file As a string
  INIContents = GetFile(FileName)

  'Find section
  PosSection = InStr(1, INIContents, "[" & Section & "]", vbTextCompare)
  If PosSection>0 Then
    'Section exists. Find end of section
    PosEndSection = InStr(PosSection, INIContents, vbCrLf & "[")
    '?Is this last section?
    If PosEndSection = 0 Then PosEndSection = Len(INIContents)+1
    
    'Separate section contents
    Dim OldsContents, NewsContents, Line
    Dim sKeyName, Found
    OldsContents = Mid(INIContents, PosSection, PosEndSection - PosSection)
    OldsContents = split(OldsContents, vbCrLf)

    'Temp variable To find a Key
    sKeyName = LCase(KeyName & "=")

    'Enumerate section lines
    For Each Line In OldsContents
      If LCase(Left(Line, Len(sKeyName))) = sKeyName Then
        Line = KeyName & "=" & Value
        Found = True
      End If
      NewsContents = NewsContents & Line & vbCrLf
    Next

    If isempty(Found) Then
      'key Not found - add it at the end of section
      NewsContents = NewsContents & KeyName & "=" & Value
    Else
      'remove last vbCrLf - the vbCrLf is at PosEndSection
      NewsContents = Left(NewsContents, Len(NewsContents) - 2)
    End If

    'Combine pre-section, new section And post-section data.
    INIContents = Left(INIContents, PosSection-1) & _
      NewsContents & Mid(INIContents, PosEndSection)
  else'if PosSection>0 Then
    'Section Not found. Add section data at the end of file contents.
    If Right(INIContents, 2) <> vbCrLf And Len(INIContents)>0 Then 
      INIContents = INIContents & vbCrLf 
    End If
    INIContents = INIContents & "[" & Section & "]" & vbCrLf & _
      KeyName & "=" & Value
  end if'if PosSection>0 Then
  WriteFile FileName, INIContents
End Sub

Function GetINIString(Section, KeyName, Default, FileName)
  Dim INIContents, PosSection, PosEndSection, sContents, Value, Found
  
  'Get contents of the INI file As a string
  INIContents = GetFile(FileName)

  'Find section
  PosSection = InStr(1, INIContents, "[" & Section & "]", vbTextCompare)
  If PosSection>0 Then
    'Section exists. Find end of section
    PosEndSection = InStr(PosSection, INIContents, vbCrLf & "[")
    '?Is this last section?
    If PosEndSection = 0 Then PosEndSection = Len(INIContents)+1
    
    'Separate section contents
    sContents = Mid(INIContents, PosSection, PosEndSection - PosSection)

    If InStr(1, sContents, vbCrLf & KeyName & "=", vbTextCompare)>0 Then
      Found = True
      'Separate value of a key.
      Value = SeparateField(sContents, vbCrLf & KeyName & "=", vbCrLf)
    End If
  End If
  If isempty(Found) Then Value = Default
  GetINIString = Value
End Function

'Separates one field between sStart And sEnd
Function SeparateField(ByVal sFrom, ByVal sStart, ByVal sEnd)
  Dim PosB: PosB = InStr(1, sFrom, sStart, 1)
  If PosB > 0 Then
    PosB = PosB + Len(sStart)
    Dim PosE: PosE = InStr(PosB, sFrom, sEnd, 1)
    If PosE = 0 Then PosE = InStr(PosB, sFrom, vbCrLf, 1)
    If PosE = 0 Then PosE = Len(sFrom) + 1
    SeparateField = Mid(sFrom, PosB, PosE - PosB)
  End If
End Function

'File functions
Function GetFile(ByVal FileName)
  Dim FS: Set FS = CreateObject("Scripting.FileSystemObject")
  'Go To windows folder If full path Not specified.
  If InStr(FileName, ":\") = 0 And Left (FileName,2)<>"\\" Then 
    FileName = FS.GetSpecialFolder(0) & "\" & FileName
  End If
  On Error Resume Next

  GetFile = FS.OpenTextFile(FileName).ReadAll
End Function

Function WriteFile(ByVal FileName, ByVal Contents)
  
  Dim FS: Set FS = CreateObject("Scripting.FileSystemObject")
  'On Error Resume Next

  'Go To windows folder If full path Not specified.
  If InStr(FileName, ":\") = 0 And Left (FileName,2)<>"\\" Then 
    FileName = FS.GetSpecialFolder(0) & "\" & FileName
  End If

  Dim OutStream: Set OutStream = FS.OpenTextFile(FileName, 2, True)
  OutStream.Write Contents
End Function

WScript.Quit
