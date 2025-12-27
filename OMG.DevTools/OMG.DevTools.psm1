#Requires -Version 5.1

<#
.SYNOPSIS
    OMG.DevTools - Development tools for OMG PowerShell modules

.DESCRIPTION
    Provides a comprehensive set of functions for building, publishing, and managing
    OMG PowerShell modules. Features include:
    - Module discovery and listing
    - Environment variable management
    - Automated publishing to PSGallery
    - Module updates from PSGallery
    - Local module building

.NOTES
    Name: OMG.DevTools
    Author: Lakshmanachari Panuganti
    Version: 1.0.0

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/
#>

# ============================================================================
# Module Configuration
# ============================================================================

$script:Config = @{
    # Cached module list
    CachedModules = $null

    # Timestamp of last cache update
    CacheTimestamp = $null

    # Whether Module Developer Tools have been loaded
    ModuleDevToolsLoaded = $false

    # Module version
    Version = '1.0.0'

    # Cache expiration in minutes
    CacheExpirationMinutes = 5
}

# ============================================================================
# Load Functions
# ============================================================================

# Get public and private function definition files
$publicFunctions = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($publicFunctions + $privateFunctions)) {
    try {
        . $import.FullName
        Write-Verbose "Imported: $($import.BaseName)"
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# ============================================================================
# Export Module Members
# ============================================================================

# Export public functions only
if ($publicFunctions) {
    Export-ModuleMember -Function $publicFunctions.BaseName
}

# ============================================================================
# Create Aliases
# ============================================================================

# Create convenient aliases
$aliases = @{
    'omgmod' = 'Get-OMGModule'
    'omgenv' = 'Initialize-OMGEnvironment'
    'omgpublish' = 'Invoke-OMGPublishModule'
    'omgupdate' = 'Invoke-OMGUpdateModule'
    'omgbuild' = 'Invoke-OMGBuildModule'
}

foreach ($alias in $aliases.GetEnumerator()) {
    try {
        New-Alias -Name $alias.Key -Value $alias.Value -Description "Alias for $($alias.Value)" -Force
        Write-Verbose "Created alias: $($alias.Key) → $($alias.Value)"
    }
    catch {
        Write-Warning "Failed to create alias '$($alias.Key)': $_"
    }
}

# Export aliases
Export-ModuleMember -Alias $aliases.Keys

# ============================================================================
# Module Initialization
# ============================================================================

Write-Verbose "OMG.DevTools v$($script:Config.Version) loaded successfully"

# Check for required environment variables on import (non-blocking)
if (-not $env:BASE_MODULE_PATH) {
    Write-Warning @"
┌─────────────────────────────────────────────────────────────┐
│ BASE_MODULE_PATH environment variable is not set            │
│ Run 'Initialize-OMGEnvironment' to configure settings       │
└─────────────────────────────────────────────────────────────┘
"@
}
else {
    Write-Verbose "BASE_MODULE_PATH: $env:BASE_MODULE_PATH"

    # Validate path exists
    if (-not (Test-Path $env:BASE_MODULE_PATH)) {
        Write-Warning "BASE_MODULE_PATH directory does not exist: $env:BASE_MODULE_PATH"
    }
}

# Show quick start hint
if ($Host.Name -eq 'ConsoleHost') {
    Write-Host "💡 Tip: Use 'Get-Command -Module OMG.DevTools' to see available commands" -ForegroundColor Cyan
}

# ============================================================================
# Module Cleanup
# ============================================================================

# Register cleanup on module removal
$ExecutionContext.SessionState.Module.OnRemove = {
    Write-Verbose "Cleaning up OMG.DevTools module..."

    # Clear module cache
    if ($script:Config) {
        $script:Config.CachedModules = $null
        $script:Config.CacheTimestamp = $null
    }

    # Remove aliases
    foreach ($aliasName in $aliases.Keys) {
        if (Get-Alias -Name $aliasName -ErrorAction SilentlyContinue) {
            Remove-Alias -Name $aliasName -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Verbose "OMG.DevTools module cleanup completed"
}

# ============================================================================
# Helper Functions (Module Scope)
# ============================================================================

<#
.SYNOPSIS
    Gets module configuration
.DESCRIPTION
    Internal function to access module configuration
#>
function Get-ModuleConfig {
    [CmdletBinding()]
    param()

    return $script:Config
}

<#
.SYNOPSIS
    Sets module configuration value
.DESCRIPTION
    Internal function to update module configuration
#>
function Set-ModuleConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [object]$Value
    )

    if ($script:Config.ContainsKey($Key)) {
        $script:Config[$Key] = $Value
        Write-Verbose "Config updated: $Key = $Value"
    }
    else {
        Write-Warning "Unknown configuration key: $Key"
    }
}
