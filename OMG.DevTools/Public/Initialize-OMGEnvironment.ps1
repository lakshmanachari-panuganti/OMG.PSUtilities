function Initialize-OMGEnvironment {
    <#
    .SYNOPSIS
        Initializes and validates required environment variables for OMG DevTools.

    .DESCRIPTION
        Checks for required environment variables and prompts to create them if missing.
        Optionally runs in non-interactive mode for automation scenarios.

    .PARAMETER NonInteractive
        Runs in non-interactive mode. Missing variables will be reported but not prompted.

    .PARAMETER Force
        Forces re-validation even if variables exist.

    .EXAMPLE
        Initialize-OMGEnvironment
        Interactively checks and sets environment variables.

    .EXAMPLE
        Initialize-OMGEnvironment -NonInteractive
        Validates environment variables without prompting.

    .OUTPUTS
        Hashtable with validation results.
    #>

    [CmdletBinding()]
    [alias("checkomgenvironment")]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [switch]$NonInteractive,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $requiredVars = @(
            'BASE_MODULE_PATH'
            'API_KEY_GEMINI'
            'API_KEY_CLAUDE'
            'API_KEY_OPENAI'
            'API_KEY_PERPLEXITY'
            'API_KEY_PSGALLERY'
        )

        $results = @{
            Valid = @()
            Missing = @()
            Created = @()
        }
    }

    process {
        foreach ($varName in $requiredVars) {
            $envVarValue = [Environment]::GetEnvironmentVariable($varName, 'User')

            if ([string]::IsNullOrWhiteSpace($envVarValue) -or $Force) {
                $results.Missing += $varName

                if (-not $NonInteractive) {
                    Write-Host "Environment variable '$varName' is not set or empty." -ForegroundColor Yellow
                    $readHost = Read-Host "Enter a value for $varName (or press Enter to skip)"

                    if (-not [string]::IsNullOrWhiteSpace($readHost)) {
                        try {
                            [Environment]::SetEnvironmentVariable($varName, $readHost, 'User')
                            $env:$varName = $readHost  # Set for current session
                            $results.Created += $varName
                            Write-Host "✓ Set $varName successfully" -ForegroundColor Green
                        }
                        catch {
                            Write-Error "Failed to set $varName: $_"
                        }
                    }
                }
                else {
                    Write-Warning "Missing environment variable: $varName"
                }
            }
            else {
                $results.Valid += $varName
                Write-Verbose "✓ $varName is set"
            }
        }

        # Initialize Module Developer Tools if BASE_MODULE_PATH is set
        if ($env:BASE_MODULE_PATH) {
            Initialize-ModuleDevTools
        }

        return $results
    }

    end {
        if ($results.Missing.Count -gt 0 -and $NonInteractive) {
            Write-Warning "Missing environment variables: $($results.Missing -join ', ')"
            Write-Host "Run 'Initialize-OMGEnvironment' interactively to set them." -ForegroundColor Cyan
        }
        elseif ($results.Created.Count -gt 0) {
            Write-Host "`n✓ Created $($results.Created.Count) environment variable(s)" -ForegroundColor Green
            Write-Host "Note: You may need to restart your PowerShell session for changes to take effect." -ForegroundColor Cyan
        }
    }
}