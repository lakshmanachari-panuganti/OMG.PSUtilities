function Get-OMGModule {
    <#
    .SYNOPSIS
        Gets all OMG modules in the base module path.

    .DESCRIPTION
        Retrieves a list of all OMG modules found in the BASE_MODULE_PATH directory.
        Results are cached for performance.

    .PARAMETER Force
        Forces a refresh of the cached module list.

    .EXAMPLE
        Get-OMGModule
        Returns all OMG modules with their names and paths.

    .EXAMPLE
        Get-OMGModule -Force
        Refreshes the cache and returns all OMG modules.

    .OUTPUTS
        PSCustomObject with ModuleName and Path properties.
    #>

    [CmdletBinding()]
    [alias("getomgmodules")]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "Getting OMG modules from: $env:BASE_MODULE_PATH"

        if (-not $env:BASE_MODULE_PATH) {
            throw "BASE_MODULE_PATH environment variable is not set. Run Initialize-OMGEnvironment first."
        }

        if (-not (Test-Path $env:BASE_MODULE_PATH)) {
            throw "BASE_MODULE_PATH does not exist: $env:BASE_MODULE_PATH"
        }
    }

    process {
        try {
            $cachedModules = Get-CachedModuleList -Force:$Force

            if ($cachedModules) {
                Write-Verbose "Found $($cachedModules.Count) OMG modules"
                return $cachedModules
            }
            else {
                Write-Warning "No OMG modules found in $env:BASE_MODULE_PATH"
                return $null
            }
        }
        catch {
            Write-Error "Failed to get OMG modules: $_"
            throw
        }
    }
}