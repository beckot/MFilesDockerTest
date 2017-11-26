Option Explicit

' Arguments:
Dim saUserName : saUserName = Wscript.Arguments(0)
Dim saPassword : saPassword = Wscript.Arguments(1)

' Connect to server:
Dim oServerApp : Set oServerApp = CreateObject("MFilesAPI.MFilesServerApplication")
Call oServerApp.ConnectAdministrativeEx()

' Create the login and set it on the server:
Dim oSaLogin : Set oSaLogin = CreateObject("MFilesAPI.LoginAccount")
oSaLogin.UserName = saUserName
oSaLogin.AccountType = 1 ' Specifies the login with M-Files credentials.
oSaLogin.LicenseType = 1 ' MFLicenseTypeNamedUserLicense
oSaLogin.ServerRoles = 1 ' 1 = System administrator.
Call oServerApp.LoginAccountOperations.AddLoginAccount( oSaLogin, saPassword )

' Due to API restrictions, we need to enable the login in a separate transaction:
Set oSaLogin = oServerApp.LoginAccountOperations.GetLoginAccount( saUserName )
oSaLogin.Enabled = true
Call oServerApp.LoginAccountOperations.ModifyLoginAccount( oSaLogin )
