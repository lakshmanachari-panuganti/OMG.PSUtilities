function Remove-PSUUserEnvironmentVariable {
    <#
    .SYNOPSIS
        Removes one or more user environment variables.

    .DESCRIPTION
        Deletes user-scoped environment variables from both the registry and the current session.
        Supports wildcards, confirmation prompts, verbose output, force deletion, and pipeline input.

    .PARAMETER Name
        The name (or wildcard pattern) of the environment variable(s) to remove.

    .PARAMETER Force
        Bypasses confirmation prompts and deletes variables without asking.

    .EXAMPLE
        Remove-PSUUserEnvironmentVariable -Name 'MY_SECRET' -Confirm

    .EXAMPLE
        Remove-PSUUserEnvironmentVariable -Name '*KEY*' -Force -Verbose

    .EXAMPLE
        'MY_SECRET' | Remove-PSUUserEnvironmentVariable -Force

    .OUTPUTS
        None

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 27th July 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$Name,

        [switch]$Force
    )

    process {
        foreach ($pattern in $Name) {
            $registryPath = 'HKCU:\Environment'
            $userVars = Get-Item -Path $registryPath | Get-ItemProperty | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $matchedNames = $userVars | Where-Object { $_ -like $pattern }

            if (-not $matchedNames) {
                Write-Warning "No environment variable(s) found matching '$pattern'."
                continue
            }

            foreach ($varName in $matchedNames) {
                if ($PSCmdlet.ShouldProcess("Environment Variable '$varName'", "Remove")) {
                    try {
                        if ($Force -or $PSCmdlet.ShouldContinue("Remove environment variable '$varName'?", "Confirm removal")) {
                            # Remove from registry
                            Remove-ItemProperty -Path $registryPath -Name $varName -ErrorAction Stop

                            # Remove from current session
                            if (Test-Path -Path "Env:\$varName") {
                                Remove-Item -Path "Env:\$varName" -ErrorAction SilentlyContinue
                            }

                            Write-Verbose "Removed variable '$varName' from registry and session."
                        }
                    } catch {
                        Write-Warning "Failed to remove '$varName': $_"
                    }
                }
            }
        }
    }
}
