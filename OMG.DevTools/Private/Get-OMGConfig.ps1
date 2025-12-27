function Get-OMGConfig {
    <#
    .SYNOPSIS
        Loads configuration from settings.json

    .DESCRIPTION
        Reads and parses the module configuration file.
        Returns default values if file doesn't exist.

    .PARAMETER ConfigName
        Name of the config file to load (without .json extension)

    .EXAMPLE
        Get-OMGConfig
        Loads the main settings.json configuration

    .EXAMPLE
        Get-OMGConfig -ConfigName "module-exclusions"
        Loads module-exclusions.json
    #>

    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]$ConfigName = 'settings'
    )

    try {
        $configPath = Join-Path $PSScriptRoot "..\Config\$ConfigName.json"

        if (Test-Path $configPath) {
            Write-Verbose "Loading config from: $configPath"
            $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

            # Convert to hashtable for easier manipulation
            $configHash = @{}
            $config.PSObject.Properties | ForEach-Object {
                $configHash[$_.Name] = $_.Value
            }

            return $configHash
        }
        else {
            Write-Warning "Config file not found: $configPath. Using defaults."
            return @{}
        }
    }
    catch {
        Write-Error "Failed to load config '$ConfigName': $_"
        return @{}
    }
}