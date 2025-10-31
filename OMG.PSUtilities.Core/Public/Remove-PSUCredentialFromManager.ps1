function Remove-PSUCredentialFromManager {
    <#
    .SYNOPSIS
        Deletes a credential from Windows Credential Manager.

    .DESCRIPTION
        Securely removes the credential entry stored under the specified target name from Windows Credential Manager.
        Use this function to delete saved UserName, Passwords that are no longer needed or should be rotated.
        This operation is permanent and cannot be undone.

    .PARAMETER Target
        (Mandatory) The unique name (Target) of the credential to delete.
        This is the identifier you used when storing the credential (e.g., "WindowsLogin", "prod-db-server", "api.example.com").

    .EXAMPLE
        Remove-PSUCredentialFromManager -Target "WindowsLogin"

        Deletes the credential entry named "WindowsLogin" from Windows Credential Manager.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 31st October 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory)]
        [string]$Target
    )

    process {
        if ($PSCmdlet.ShouldProcess($Target, "Delete credential from Windows Credential Manager")) {
            try {
                $CredentialManager = [CredentialManager.CredMan]::Delete($Target)
                if ($CredentialManager) {
                    Write-Verbose "Credential deleted successfully!"
                    [PSCustomObject]@{
                        Target     = $Target
                        Status     = 'Deleted'
                        PSTypeName = 'PSU.CredentialManager.DeleteResult'
                    }
                } else {
                    throw "Failed to delete credential (may not exist): $Target"
                }
            } catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }
}