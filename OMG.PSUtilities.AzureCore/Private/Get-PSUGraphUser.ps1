function Get-PSUGraphUser {
    param([string] $Upn)
    try {
        return Get-MgUser -UserId $Upn -Property id,displayName,userPrincipalName -ErrorAction Stop
    } catch {
        throw "Unable to find user '$Upn' via Microsoft Graph. Ensure Connect-MgGraph is active and you have permission to read users."
    }
}
