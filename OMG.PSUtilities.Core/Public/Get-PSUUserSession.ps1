function Get-PSUUserSession {
    <#
    .SYNOPSIS
        Lists currently logged-in users and their sessions.

    .DESCRIPTION
        Retrieves information about users currently logged into the system, including session ID, state, and logon time.

    .EXAMPLE
        Get-PSUUserSession

        Lists all currently logged-in users and their session information.

    .OUTPUTS
        [PSCustomObject]
        Properties include: UserName, SessionName, Id, State, IdleTime, LogonTime

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 3rd July 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>
    query user | Select-Object -Skip 1 | ForEach-Object {
        $parts = $_ -replace '\s{2,}', ',' -split ','
        [PSCustomObject]@{
            UserName    = $parts[0].Trim().Trim('>')
            SessionName = $parts[1].Trim()
            Id          = $parts[2].Trim()
            State       = $parts[3].Trim()
            IdleTime    = $parts[4].Trim()
            LogonTime   = $parts[5..($parts.Count-1)] -join ','
        }
    }
}