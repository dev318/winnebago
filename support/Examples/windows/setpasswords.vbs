Option Explicit
Dim objOU, objUser, objRootDSE
Dim strContainer, strDNSDomain, strPassword

Set objRootDSE = GetObject("LDAP://RootDSE")
strDNSDomain = objRootDSE.Get("DefaultNamingContext") 
strContainer = "OU=ImportedUsers, "
strContainer = strContainer & strDNSDomain

set objOU = GetObject("LDAP://" & strContainer )
For each objUser in objOU
If objUser.class="user" then
WScript.Echo "Processing: " & objUser.name
objUser.SetPassword objUser.name & "sharedsecret"
objUser.SetInfo
End If
Next

WScript.Quit
