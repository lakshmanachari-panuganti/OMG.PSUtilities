function Uninstall-PSUInstalledSoftware {
    <#
    .SYNOPSIS
        Uninstalls software objects piped in from Get-PSUInstalledSoftware.

    .DESCRIPTION
        Accepts piped input of software entries with DisplayName and UninstallString properties
        and runs the uninstaller in silent mode where possible. Supports -WhatIf for safe preview.

    .EXAMPLE
        Get-PSUInstalledSoftware -Name '*Zoom*' | Uninstall-PSUInstalledSoftware

    .EXAMPLE
        Get-PSUInstalledSoftware -Name '*Zoom*' | Uninstall-PSUInstalledSoftware -WhatIf

    .NOTES
        Author: Lakshmanachari Panuganti
        Updated: 2025-07-03
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [Alias('Remove-PSUInstalledSoftware', 'Uninstall-Software')]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [PSCustomObject]$Software
    )

    process {
        if (-not $Software.DisplayName -or -not $Software.UninstallString) {
            Write-Warning "Invalid input: missing DisplayName or UninstallString."
            return
        }

        $cmd = $Software.UninstallString

        # Add silent flags if MSI-based
        if ($cmd -match '^MsiExec\.exe\s+/X\{.+\}$') {
            $cmd += ' /quiet /norestart'
        }
        elseif ($cmd -like '*.exe*') {
            if ($cmd -match 'chrome.*setup\\.exe') {
                $cmd += ' --disable-uninstall-dialog --force-uninstall'
            }
            elseif ($cmd -notmatch '(?i)(/quiet|--quiet|--uninstall|--silent|/s)') {
                $cmd += ' /quiet'
            }
        }

        if ($PSCmdlet.ShouldProcess($Software.DisplayName, "Uninstall using: $cmd")) {
            try {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -Verb RunAs -WindowStyle Hidden
                Write-Host "Uninstall triggered: $($Software.DisplayName)" -ForegroundColor Cyan
            }
            catch {
                Write-Warning "Failed to uninstall $($Software.DisplayName): $_"
            }
        }
    }
}
