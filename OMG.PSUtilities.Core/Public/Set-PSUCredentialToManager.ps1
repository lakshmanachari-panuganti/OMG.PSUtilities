function Set-PSUCredentialToManager {
    <#
    .SYNOPSIS
        Stores a credential in Windows Credential Manager.

    .DESCRIPTION
        Stores the specified username and password under the given target name in Windows Credential Manager.

    .PARAMETER Target
        (Mandatory) The name under which to store the credential.

    .PARAMETER Username
        (Mandatory) The username to store.

    .PARAMETER Password
        (Mandatory) The password to store.

    .PARAMETER Comment
        (Optional) A comment to associate with the credential.

    .EXAMPLE
        Set-PSUCredentialToManager -Target "acred" -Username "A092721" -Password "123123123"

    .EXAMPLE
        Set-PSUCredentialToManager -Target "prod-db-server" -Username "dbadmin" -Password "SecurePass123" -Comment "Production DB"

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date:   31st October 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByUserPass')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ByUserPass')]
        [Parameter(Mandatory, ParameterSetName = 'ByCredential')]
        [string]$Target,

        [Parameter(Mandatory, ParameterSetName = 'ByUserPass')]
        [string]$Username,

        [Parameter(Mandatory, ParameterSetName = 'ByUserPass')]
        [string]$Password,

        [Parameter(Mandatory, ParameterSetName = 'ByCredential')]
        [PSCredential]$Credential,

        [string]$Comment = "Set via Set-PSUCredentialToManager function"
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByCredential') {
            $Username = $Credential.UserName
            $Password = $Credential.GetNetworkCredential().Password
        }

        try {
            $CredentialManager = [CredentialManager.CredMan]::Store(
                $Target, 
                $Username, 
                $Password, 
                $Comment
            )

            if ($CredentialManager) {
                [PSCustomObject]@{
                    Target     = $Target
                    Username   = $Username
                    Status     = 'Success'
                    PSTypeName = 'PSU.CredentialManager.StoreResult'
                }
            } else {
                $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                Write-Error "Failed to store credential. Win32Error: $err"
                [PSCustomObject]@{
                    Target     = $Target
                    Username   = $Username
                    Status     = 'Failed'
                    Error      = $err
                    PSTypeName = 'PSU.CredentialManager.StoreResult'
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
