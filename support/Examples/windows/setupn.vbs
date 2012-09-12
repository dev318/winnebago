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
WScript.Echo "Processing: " & objUser.cn
objUser.Put "userPrincipalName", objUser.sAMAccountName & "@ad.yelpcorp.com"
objUser.SetInfo
End If
Next

WScript.Quit