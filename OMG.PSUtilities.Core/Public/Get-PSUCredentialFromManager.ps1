function Get-PSUCredentialFromManager {
    <#
    .SYNOPSIS
        Retrieves a credential from Windows Credential Manager by target name.

    .DESCRIPTION
        Fetches the username, password, and comment stored under the specified target name.

    .PARAMETER Target
        (Mandatory) The name of the credential to retrieve.

    .EXAMPLE
        Get-PSUCredentialFromManager -Target "acred"

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
    param (
        [Parameter(Mandatory)]
        [string]$Target
    )

    process {
        try {
            $CredentialManager = [CredentialManager.CredMan]::Get($Target)
            if ($CredentialManager) {
                $securePassword = ConvertTo-SecureString $CredentialManager.Password -AsPlainText -Force
                New-Object System.Management.Automation.PSCredential (
                    $CredentialManager.Username,
                    $securePassword
                )
            } else {
                throw "No credential found in Windows Credential Manager for target: $Target"
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
