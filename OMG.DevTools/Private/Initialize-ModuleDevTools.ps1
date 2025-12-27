function Initialize-ModuleDevTools {
    <#
    .SYNOPSIS
        Initializes Module Developer Tools functions.

    .DESCRIPTION
        Lazy-loads Module Developer Tools functions only when needed.
        This function is called internally by other module functions.
    #>

    [CmdletBinding()]
    param()

    if ($script:Config.ModuleDevToolsLoaded) {
        Write-Verbose "Module Developer Tools already loaded"
        return
    }

    try {
        Write-Verbose "Loading Module Developer Tools..."

        # Load Set-ModuleEnvironmentVariables script
        $envVarScript = Join-Path $env:BASE_MODULE_PATH 'Module Developer Tools\Set-ModuleEnvironmentVariables.ps1'
        if (Test-Path $envVarScript) {
            . $envVarScript
            Write-Verbose "Loaded Set-ModuleEnvironmentVariables.ps1"
        }
        else {
            Write-Warning "Set-ModuleEnvironmentVariables.ps1 not found at: $envVarScript"
        }

        # Load all functions from Module Developer Tools
        $functionsPath = Join-Path $env:BASE_MODULE_PATH 'Module Developer Tools\functions'
        if (Test-Path $functionsPath) {
            Get-ChildItem -Path $functionsPath -Filter *.ps1 -Recurse | ForEach-Object {
                try {
                    . $_.FullName
                    Write-Verbose "Loaded $($_.Name)"
                }
                catch {
                    Write-Warning "Failed to load $($_.FullName): $_"
                }
            }
        }
        else {
            Write-Warning "Module Developer Tools functions path not found: $functionsPath"
        }

        $script:Config.ModuleDevToolsLoaded = $true
        Write-Verbose "Module Developer Tools loaded successfully"
    }
    catch {
        Write-Error "Failed to initialize Module Developer Tools: $_"
        throw
    }
}