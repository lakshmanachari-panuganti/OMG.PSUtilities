<#
.SYNOPSIS
    Lists currently logged-in users and their sessions.

.DESCRIPTION
    Retrieves information about users currently logged into the system, including session ID, state, and logon time.

.EXAMPLE
    Get-PSUUserSession

.NOTES
    Author: Lakshmanachari Panuganti
    File Creation Date: 2025-07-03
#>
function Get-PSUUserSession {
    query user | Select-Object -Skip 1 | ForEach-Object {
        $parts = $_ -replace '\s{2,}', ',' -split ','
        [PSCustomObject]@{
            UserName    = $parts[0].Trim()
            SessionName = $parts[1].Trim()
            Id          = $parts[2].Trim()
            State       = $parts[3].Trim()
            IdleTime    = $parts[4].Trim()
            LogonTime   = $parts[5..($parts.Count-1)] -join ','
        }
    }
}