
function Set-OMGConfig {
    <#
    .SYNOPSIS
        Saves configuration to settings.json

    .DESCRIPTION
        Writes configuration settings to the config file.

    .PARAMETER ConfigName
        Name of the config file (without .json extension)

    .PARAMETER Configuration
        Hashtable or PSCustomObject to save

    .EXAMPLE
        $config = Get-OMGConfig
        $config.cache.expirationMinutes = 10
        Set-OMGConfig -Configuration $config
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigName = 'settings',

        [Parameter(Mandatory)]
        [object]$Configuration
    )

    try {
        $configPath = Join-Path $PSScriptRoot "..\Config\$ConfigName.json"

        $Configuration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Force

        Write-Verbose "Config saved to: $configPath"
        return $true
    }
    catch {
        Write-Error "Failed to save config '$ConfigName': $_"
        return $false
    }
}