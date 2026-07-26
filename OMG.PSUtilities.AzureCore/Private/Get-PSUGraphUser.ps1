<#
.SYNOPSIS
    Retrieves a user object from Microsoft Graph by User Principal Name.

.DESCRIPTION
    Wraps Get-MgUser to fetch id, displayName, and userPrincipalName for a given UPN.
    Requires an active Connect-MgGraph session with User.Read.All or similar permissions.

.PARAMETER Upn
    The User Principal Name (UPN) of the user to retrieve.

.OUTPUTS
    [Microsoft.Graph.PowerShell.Models.MicrosoftGraphUser]

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 11th August 2025
    Last Modified: 7th March 2026
    Version: 1.0
#>
function Get-PSUGraphUser {
    param([string] $Upn)
    try {
        return Get-MgUser -UserId $Upn -Property id,displayName,userPrincipalName -ErrorAction Stop
    } catch {
        throw "Unable to find user '$Upn' via Microsoft Graph. Ensure Connect-MgGraph is active and you have permission to read users."
    }
}
