function Remove-PSUUserSession {
<#
.SYNOPSIS
    Logs off selected user sessions.

.DESCRIPTION
    Accepts piped input from Get-PSUUserSession and logs off the specified sessions
    using the session ID. Supports WhatIf and Confirm for safety.

.EXAMPLE
    Get-PSUUserSession | Where-Object { $_.State -eq 'Disc' } | Remove-PSUUserSession

.EXAMPLE
    Get-PSUUserSession | Out-GridView -PassThru | Remove-PSUUserSession -WhatIf

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 2025-07-03
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
                Write-Host "✅ Logged off user '$user' (Session ID: $sessionId)" -ForegroundColor Green
            } catch {
                Write-Warning "❌ Failed to log off session $sessionId ($user): $_"
            }
        }
    }
}
