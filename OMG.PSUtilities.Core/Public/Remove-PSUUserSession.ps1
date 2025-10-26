function Remove-PSUUserSession {
    <#
    .SYNOPSIS
        Logs off selected user sessions (local or remote).

    .DESCRIPTION
        Accepts piped input from Get-PSUUserSession and logs off the specified sessions using the session ID.
        Supports WhatIf and Confirm for safety. Supports remote logoff via ComputerName and Credential.
        Works for both local and remote computers. Credential parameter enables secure remote logoff.

    .PARAMETER Session
        (Mandatory) The session object from Get-PSUUserSession containing session details. Must include Id, UserName, and optionally ComputerName.
        Accepts pipeline input for bulk logoff scenarios.

    .PARAMETER Credential
        (Optional) Credential to use for remote logoff. Required for remote computers if not using current user context.
        Accepts [PSCredential] object. Use Get-Credential to create.

    .EXAMPLE
        Get-PSUUserSession | Where-Object { $_.State -eq 'Disc' } | Remove-PSUUserSession

        Logs off all disconnected sessions on the local computer.

    .EXAMPLE
        $cred = Get-Credential
        Get-PSUUserSession -ComputerName "Server01" -Credential $cred | Remove-PSUUserSession -Credential $cred

        Logs off all sessions on Server01 using provided credentials.

    .EXAMPLE
        $session = Get-PSUUserSession -ComputerName "Server02" -Credential $cred | Where-Object { $_.UserName -eq "jdoe" }
        $session | Remove-PSUUserSession -Credential $cred -Confirm:$false

        Logs off user 'jdoe' on Server02 without confirmation prompt.

    .OUTPUTS
        None

    .NOTES
        Author: Lakshmanachari Panuganti
        Created: 2025-07-03
        Last Modified: 2025-10-26

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [ValidateScript({ $_ -and $_.Id -and $_.UserName })]
        [PSCustomObject]$Session,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    process {
        $sessionId = $Session.Id
        $user = $Session.UserName
        $computer = if ($Session.PSObject.Properties['ComputerName']) { $Session.ComputerName } else { $env:COMPUTERNAME }

        if ($PSCmdlet.ShouldProcess("Session ID: $sessionId on $computer", "Log off user: $user")) {
            try {
                if ($computer -and $computer.ToLower() -ne $env:COMPUTERNAME.ToLower()) {
                    $invokeParams = @{ ComputerName = $computer; ScriptBlock = { param($id) logoff $id }; ArgumentList = $sessionId }
                    if ($Credential) { $invokeParams.Credential = $Credential }
                    Invoke-Command @invokeParams
                    Write-Host "Logged off user '$user' (Session ID: $sessionId) on $computer" -ForegroundColor Green
                } else {
                    logoff $sessionId
                    Write-Host "Logged off user '$user' (Session ID: $sessionId) on $computer" -ForegroundColor Green
                }
            } catch {
                Write-Warning "Failed to log off session $sessionId ($user) on $computer : $($_)"
            }
        }
    }
}
