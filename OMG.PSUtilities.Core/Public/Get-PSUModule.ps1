function Get-PSUModule {
    <#
    .SYNOPSIS
        Detects the module based on .psd1 or .psm1 file existence.

    .DESCRIPTION
        Walks up the directory tree from the specified root (or $PSScriptRoot by default) until it finds a .psd1 or .psm1 file.
        Returns module metadata including name, version, and paths. Useful for dynamic module introspection and automation scenarios.

    .PARAMETER ScriptRoot
            (Optional) The path to start searching from. Defaults to $PSScriptRoot.

    .PARAMETER ScriptPath
            (Optional) A specific script file path to use as the starting point. If provided, its directory is used.
    .EXAMPLE
        $Module = Get-PSUModule
        Detects the module from the current script's root.

    .EXAMPLE
        Get-PSUModule -ScriptPath "C:\repos\OMG.PSUtilities\OMG.PSUtilities.Core\Public\SomeScript.ps1"
        Detects the module starting from a specific script file.

    .OUTPUTS
            [PSCustomObject]

    .NOTES
            Author: Lakshmanachari Panuganti
            Date: 22nd August 2025

    .LINK
            https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
            https://www.linkedin.com/in/lakshmanachari-panuganti/
            https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'ByRoot')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Container)) {
            throw "`nThe specified ScriptRoot '$_' does not exist or `n'It is not a directory'."
            }
            $true
        })]
        [string]$ScriptRoot = $PSScriptRoot,

        [Parameter(ParameterSetName = 'ByPath')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
            throw "`nThe specified ScriptPath '$_' does not exist or `n'It is not a file'."
            }
            $true
        })]
        [string]$ScriptPath
    )

    try {
        $startPath = if ($PSCmdlet.ParameterSetName -eq 'ByPath' -and $ScriptPath) {
            Split-Path -Path $ScriptPath -Parent
        } else {
            $ScriptRoot
        }

        $currentPath = $startPath
        while ($currentPath -and (Test-Path $currentPath)) {
            $psd1 = Get-ChildItem -Path $currentPath -Filter '*.psd1' -ErrorAction SilentlyContinue | Select-Object -First 1
            $psm1 = Get-ChildItem -Path $currentPath -Filter '*.psm1' -ErrorAction SilentlyContinue | Select-Object -First 1

            if ($psd1 -or $psm1) {
                $parentModule = Split-Path -Path $currentPath -Parent | Split-Path -Leaf
                $currentVersion = $null
                if ($psd1) {
                    try {
                        $manifestData = Import-PowerShellDataFile -Path $psd1.FullName
                        $currentVersion = $manifestData.ModuleVersion
                    } catch {}
                }
                return [PSCustomObject]@{
                    ModuleName     = (Split-Path -Path $currentPath -Leaf)
                    Path           = $currentPath
                    ManifestPath   = if ($psd1) { $psd1.FullName } else { $null }
                    ModuleFilePath = if ($psm1) { $psm1.FullName } else { $null }
                    HasManifest    = [bool]$psd1
                    HasModuleFile  = [bool]$psm1
                    ParentModule   = $parentModule
                    CurrentVersion = $currentVersion
                    PSTypeName     = 'PSU.ModuleName.Info'
                }
            }

            # Walk up one level
            $currentPath = Split-Path -Path $currentPath -Parent
        }

        throw "No module manifest (.psd1) or module file (.psm1) found above '$startPath'. Ensure you are running inside a valid PowerShell module folder."
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}