function Test-EnvironmentVariable {
    <#
    .SYNOPSIS
        Tests if an environment variable exists and has a value.

    .PARAMETER Name
        The name of the environment variable to test.

    .PARAMETER Scope
        The scope to check (Process, User, Machine). Default is User.

    .OUTPUTS
        Boolean indicating if the variable exists and has a value.
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [System.EnvironmentVariableTarget]$Scope = 'User'
    )

    $value = [Environment]::GetEnvironmentVariable($Name, $Scope)
    return (-not [string]::IsNullOrWhiteSpace($value))
}