function Get-CachedModuleList {
    <#
    .SYNOPSIS
        Gets the cached list of OMG modules or refreshes the cache.

    .DESCRIPTION
        Retrieves a list of OMG modules from BASE_MODULE_PATH with intelligent caching.
        Respects module exclusions defined in config and uses configurable cache expiration.

    .PARAMETER Force
        Forces a refresh of the cache, ignoring the cache expiration time.

    .EXAMPLE
        Get-CachedModuleList
        Gets the cached module list or refreshes if expired.

    .EXAMPLE
        Get-CachedModuleList -Force
        Forces an immediate cache refresh.

    .OUTPUTS
        Array of PSCustomObjects with ModuleName and Path properties.
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "Get-CachedModuleList: Starting..."

        # Load configuration settings
        try {
            $moduleConfig = Get-OMGConfig -ErrorAction SilentlyContinue
            $exclusionConfig = Get-OMGConfig -ConfigName "module-exclusions" -ErrorAction SilentlyContinue
        }
        catch {
            Write-Verbose "Could not load config, using defaults: $_"
            $moduleConfig = @{}
            $exclusionConfig = @{}
        }

        # Get cache expiration from config or use default
        $cacheExpirationMinutes = if ($moduleConfig.cache.expirationMinutes) {
            $moduleConfig.cache.expirationMinutes
        }
        else {
            5  # Default fallback
        }

        Write-Verbose "Cache expiration set to: $cacheExpirationMinutes minutes"
    }

    process {
        # Check if cache is enabled
        $cacheEnabled = if ($null -ne $moduleConfig.cache.enabled) {
            $moduleConfig.cache.enabled
        }
        else {
            $true  # Default to enabled
        }

        if (-not $cacheEnabled) {
            Write-Verbose "Cache is disabled in config, forcing refresh"
            $Force = $true
        }

        # Check if cache exists and is valid
        $cacheValid = $script:Config.CachedModules -and
                      $script:Config.CacheTimestamp -and
                      ((Get-Date) - $script:Config.CacheTimestamp).TotalMinutes -lt $cacheExpirationMinutes

        if ($Force -or -not $cacheValid) {
            if ($Force) {
                Write-Verbose "Force refresh requested"
            }
            else {
                Write-Verbose "Cache expired or invalid, refreshing..."
            }

            try {
                # Validate BASE_MODULE_PATH exists
                if (-not $env:BASE_MODULE_PATH) {
                    throw "BASE_MODULE_PATH environment variable is not set"
                }

                if (-not (Test-Path $env:BASE_MODULE_PATH)) {
                    throw "BASE_MODULE_PATH does not exist: $env:BASE_MODULE_PATH"
                }

                $basePath = $env:BASE_MODULE_PATH
                $baseModuleName = Split-Path $basePath -Leaf

                Write-Verbose "Scanning for modules in: $basePath"
                Write-Verbose "Looking for modules matching: $baseModuleName*"

                # Get exclusion patterns from config
                $excludedModules = if ($exclusionConfig.excludedModules) {
                    $exclusionConfig.excludedModules
                }
                else {
                    @('*.Tests', '*-wip', '*.backup')  # Default exclusions
                }

                Write-Verbose "Exclusion patterns: $($excludedModules -join ', ')"

                # Get all directories matching the base module name
                $allModules = Get-ChildItem -Path $basePath -Directory -ErrorAction Stop |
                    Where-Object { $_.Name -like "$baseModuleName*" }

                Write-Verbose "Found $($allModules.Count) potential modules"

                # Filter out excluded modules
                $filteredModules = $allModules | Where-Object {
                    $moduleName = $_.Name
                    $isExcluded = $false

                    foreach ($pattern in $excludedModules) {
                        if ($moduleName -like $pattern) {
                            Write-Verbose "Excluding module: $moduleName (matches pattern: $pattern)"
                            $isExcluded = $true
                            break
                        }
                    }

                    -not $isExcluded
                }

                # Create module info objects
                $script:Config.CachedModules = $filteredModules | ForEach-Object {
                    [PSCustomObject]@{
                        PSTypeName = 'OMG.ModuleInfo'
                        ModuleName = $_.Name
                        Path       = $_.FullName
                        LastWriteTime = $_.LastWriteTime
                        Exists = $true
                    }
                }

                $script:Config.CacheTimestamp = Get-Date

                Write-Verbose "Cache refreshed successfully with $($script:Config.CachedModules.Count) modules"

                # Log module names if verbose
                if ($VerbosePreference -eq 'Continue') {
                    $script:Config.CachedModules | ForEach-Object {
                        Write-Verbose "  • $($_.ModuleName)"
                    }
                }
            }
            catch {
                Write-Error "Failed to refresh module cache: $_"

                # Return empty array on error but don't clear existing cache
                if (-not $script:Config.CachedModules) {
                    return @()
                }

                Write-Warning "Returning stale cached data due to error"
            }
        }
        else {
            $cacheAge = [math]::Round(((Get-Date) - $script:Config.CacheTimestamp).TotalMinutes, 2)
            Write-Verbose "Using cached module list (age: $cacheAge minutes)"
        }

        return $script:Config.CachedModules
    }

    end {
        Write-Verbose "Get-CachedModuleList: Completed"
    }
}