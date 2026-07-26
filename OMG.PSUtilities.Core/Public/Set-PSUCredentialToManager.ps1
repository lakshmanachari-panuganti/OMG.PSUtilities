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
        (Mandatory) The password to store. The Credential parameter is recommended
        because it avoids passing a plaintext password.

    .PARAMETER Comment
        (Optional) A comment to associate with the credential.

    .EXAMPLE
        Set-PSUCredentialToManager -Target "acred" -Username "A092721" -Password $plainTextPassword

        Stores a credential using the backward-compatible username and password parameters.

    .EXAMPLE
        $credential = Get-Credential
        Set-PSUCredentialToManager -Target "prod-db-server" -Credential $credential -Comment "Production DB"

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

    [CmdletBinding(DefaultParameterSetName = 'ByUserPass', SupportsShouldProcess)]
    [Alias("setcred")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingUsernameAndPasswordParams',
        '',
        Justification = 'The legacy parameter set is retained for backward compatibility. Use -Credential for secure input.'
    )]
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
            $plainTextPassword = $Credential.GetNetworkCredential().Password
        } else {
            $plainTextPassword = $Password
        }

        try {
            if (-not $PSCmdlet.ShouldProcess($Target, "Store credential for $Username")) {
                return
            }

            $CredentialManager = [CredentialManager.CredMan]::Store(
                $Target,
                $Username,
                $plainTextPassword,
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
        } finally {
            $plainTextPassword = $null
        }
    }
}
