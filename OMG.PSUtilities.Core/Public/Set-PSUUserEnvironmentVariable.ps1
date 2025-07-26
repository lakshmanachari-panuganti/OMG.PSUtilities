function Set-PSUUserEnvironmentVariable {
    <#
    .SYNOPSIS
        Sets or updates a user environment variable.

    .DESCRIPTION
        Sets a user environment variable both for the current session and persistently for the user.

    .PARAMETER Name
        The name of the environment variable.

    .PARAMETER Value
        The value to set for the environment variable.

    .EXAMPLE
        Set-PSUUserEnvironmentVariable -Name "MyVar" -Value "MyValue"

    .NOTES
        Author: Lakshmanachari Panuganti
        File Creation Date: 2025-06-27
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value
    )

    try {
        # Set at user scope (persists across sessions)
        [System.Environment]::SetEnvironmentVariable($Name, $Value, "User")

        # Set in current session
        Set-Item -Path "Env:\$Name" -Value $Value
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
