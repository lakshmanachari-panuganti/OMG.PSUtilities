function Remove-PSUUserSession {
    <#
    .SYNOPSIS
        Logs off selected user sessions.

    .DESCRIPTION
        Accepts piped input from Get-PSUUserSession and logs off the specified sessions
        using the session ID. Supports WhatIf and Confirm for safety.

    .PARAMETER Session
        (Mandatory) The session object from Get-PSUUserSession containing session details.

    .EXAMPLE
        Get-PSUUserSession | Where-Object { $_.State -eq 'Disc' } | Remove-PSUUserSession

    .EXAMPLE
        Get-PSUUserSession | Out-GridView -PassThru | Remove-PSUUserSession -WhatIf

    .OUTPUTS
        None

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2025-07-03

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [PSCustomObject]$Session
    )

    process {
        if (-not $Session.Id -or -not $Session.UserName) {
            Write-Warning "Invalid session object. Missing Id or UserName."
            return
        }

        $sessionId = $Session.Id
        $user = $Session.UserName

        if ($PSCmdlet.ShouldProcess("Session ID: $sessionId", "Log off user: $user")) {
            try {
                logoff $sessionId
                Write-Host "Logged off user '$user' (Session ID: $sessionId)" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to log off session $sessionId ($user): $_"
            }
        }
    }
}
