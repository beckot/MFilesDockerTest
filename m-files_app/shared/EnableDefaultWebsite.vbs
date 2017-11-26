Option Explicit
Dim oServerApp : Set oServerApp = CreateObject("MFilesAPI.MFilesServerApplication")
Call oServerApp.ConnectAdministrativeEx()
Call oServerApp.ServerManagementOperations.ConfigureWebAccessToDefaultWebSite()

