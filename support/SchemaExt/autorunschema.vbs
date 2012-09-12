' this file determines the Domain name and then runs the
' load_all or load.bat file depending on  a single parameter
' that is passed. 

'set objArgs = Wscript.Arguments
Set rootDSE = GetObject("LDAP://RootDSE")
'wscript.Echo(rootDSE.Get("rootDomainNamingContext"))

'automated
domain = rootDSE.Get("rootDomainNamingContext")

RunLine = "load_apple " & " " & """" & domain & """"

CreateObject("Wscript.Shell").Run RunLine, 1, True


wscript.echo "Done"