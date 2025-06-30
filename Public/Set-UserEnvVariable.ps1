function Set-UserEnvVariable {
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value
    )

    try {
        # Set the environment variable at the User level (persistent)
        [System.Environment]::SetEnvironmentVariable($Name, $Value, "User")

        # Set the environment variable in the current process (immediate use)
        $env:$Name = [System.Environment]::GetEnvironmentVariable($Name, "User")

        Write-Host "Environment variable '$Name' set and loaded into current session." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to set environment variable '$Name'. Error: $_"
    }
}