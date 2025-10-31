function Get-PSUCredentialFromManager {
    <#
    .SYNOPSIS
        Retrieves a credential from Windows Credential Manager by target name.

    .DESCRIPTION
        Retrieves the PSCredential object stored under the specified target name in Windows Credential Manager.
        If the -Clipboard switch is used, the password is copied to the clipboard.

    .PARAMETER Target
        (Mandatory) The name of the credential to retrieve.

    .PARAMETER Clipboard
        (Optional) If specified, copies the retrieved password to the Windows clipboard.
        Use with caution: copying sensitive data to the clipboard may expose it to other applications or users on the system.

    .EXAMPLE
        Get-PSUCredentialFromManager -Target "WindowsLogin"

    .EXAMPLE
        Get-PSUCredentialFromManager -Target "Computer01Cred" -Clipboard
        Retrieves the credential and copies the password to the clipboard.

    .OUTPUTS
        [PSCredential]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date:   31st October 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>

    [CmdletBinding()]
    [Alias("fetchcred")]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Target,

        [Parameter()]
        [switch]$Clipboard
    )

    process {
        try {
            $CredentialManager = [CredentialManager.CredMan]::Get($Target)

            if (-not $CredentialManager) {
                throw "No credential found in Windows Credential Manager for target: $Target"
            }

            if ($Clipboard.IsPresent) {
                $CredentialManager.Password | Set-Clipboard
                Write-Verbose "Password copied to clipboard. Use with caution."
            }

            $securePassword = ConvertTo-SecureString $CredentialManager.Password -AsPlainText -Force
            $credObj = New-Object System.Management.Automation.PSCredential (
                $CredentialManager.Username,
                $securePassword
            )
            $credObj | Add-Member -MemberType NoteProperty -Name LastModified -Value $CredentialManager.LastModified
            $credObj.PSTypeNames.Insert(0, 'PSU.CredentialManager.Credential')
            return $credObj | Select-Object UserName, Password, LastModified
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
