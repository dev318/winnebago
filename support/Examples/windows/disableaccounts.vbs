Option Explicit
Const ADS_UF_ACCOUNTDISABLE = 2
Const ADS_SCOPE_SUBTREE = 2

Dim oFSO, sFile, oFile, sText
Dim objOU, objUser, objRootDSE
Dim strContainer, strDNSDomain, strPassword,strDN
Dim objConnection,objCommand,objRecordSet,intUAC

Set oFSO = CreateObject("Scripting.FileSystemObject")
sFile = "disabledusers.txt"
If oFSO.FileExists(sFile) Then
 Set oFile = oFSO.OpenTextFile(sFile, 1)
  Do While Not oFile.AtEndOfStream
   sText = oFile.ReadLine
    If Trim(sText) <> "" Then
	Set objConnection = CreateObject("ADODB.Connection")
	Set objCommand =   CreateObject("ADODB.Command")
	objConnection.Provider = "ADsDSOObject"
	objConnection.Open "Active Directory Provider"
	Set objCommand.ActiveConnection = objConnection
	objCommand.Properties("Page Size") = 1000
	objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE 

	objCommand.CommandText = _
	    "SELECT distinguishedName FROM 'LDAP://dc=ad,dc=yelpcorp,dc=com'WHERE objectCategory='user'AND sAMAccountName='" & sText & "'"
	Set objRecordSet = objCommand.Execute

	objRecordSet.MoveFirst
	Do Until objRecordSet.EOF
	    strDN = objRecordSet.Fields("distinguishedName").Value
	    Wscript.Echo "Processing :" & strDN
		Set objUser = GetObject _
		("LDAP://" & strDN)
		intUAC = objUser.Get("userAccountControl")
		objUser.Put "userAccountControl", intUAC OR ADS_UF_ACCOUNTDISABLE
		objUser.SetInfo
	    objRecordSet.MoveNext
	Loop
    End If
  Loop
 oFile.Close
Else
 WScript.Echo "File Not Found"
End If