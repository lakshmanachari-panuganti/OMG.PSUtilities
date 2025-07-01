function Set-PSUUserEnvironmentVariable {
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
