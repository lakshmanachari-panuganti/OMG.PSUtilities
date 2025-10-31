function Get-PSUCredentialManagerInventory {
    <#
    .SYNOPSIS
        Lists all credentials stored in Windows Credential Manager.

    .DESCRIPTION
        Returns a list of all target names for credentials stored in Windows Credential Manager.

    .EXAMPLE
        Get-PSUCredentialManagerInventory

    .OUTPUTS
        [System.Object[]]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date:   31st October 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>

    [CmdletBinding()]
    [Alias("listcred")]
    param ()

    process {
        try {
            $targets = [CredentialManager.CredMan]::List()
            [PSCustomObject]@{
                Targets    = $targets
                Count      = $targets.Count
                Status     = 'Success'
                PSTypeName = 'PSU.CredentialManager.Inventory'
            }
        } catch {
            Write-Error "Exception: $($_.Exception.Message)"
            [PSCustomObject]@{
                Targets    = @()
                Count      = 0
                Status     = 'Failed'
                Error      = $_.Exception.Message
                PSTypeName = 'PSU.CredentialManager.Inventory'
            }
        }
    }
}
