function Get-PSUUserEnvironmentVariable {
    <#
    .SYNOPSIS
        Gets one or more user environment variables.

    .DESCRIPTION
        Retrieves user-scoped environment variables by exact name or wildcard pattern.
        Returns both the variable name and its value. Supports pipeline input and wildcards.

    .PARAMETER Name
        The name of the environment variable to retrieve. Wildcards are supported.
        If not specified, returns all user environment variables.

    .EXAMPLE
        Get-PSUUserEnvironmentVariable

    .EXAMPLE
        Get-PSUUserEnvironmentVariable -Name 'API_KEY_OPENAI'

    .EXAMPLE
        Get-PSUUserEnvironmentVariable -Name '*KEY*' -Verbose

    .EXAMPLE
        'API_KEY_OPENAI', 'ADO_ORGANIZATION' | Get-PSUUserEnvironmentVariable

    .EXAMPLE
        [PSCustomObject] @{'Name' = 'API_KEY_GEMINI'} | Get-PSUUserEnvironmentVariable

    .NOTES
        Author: Lakshmanachari Panuganti
        File Creation Date: 2025-07-27
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$Name
    )

    process {
        $envVars = [System.Environment]::GetEnvironmentVariables("User")

        if (-not $Name) {
            foreach ($key in $envVars.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Value = $envVars[$key]
                }
            }
        }
        else {
            foreach ($pattern in $Name) {
                $matched = $envVars.Keys | Where-Object { $_ -like $pattern }

                if (-not $matched) {
                    Write-Verbose "No match found for pattern '$pattern'"
                    continue
                }

                foreach ($key in $matched) {
                    [PSCustomObject]@{
                        Name  = $key
                        Value = $envVars[$key]
                    }
                }
            }
        }
    }
}