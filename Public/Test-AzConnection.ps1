<#
.SYNOPSIS
    Checks if an active Azure session exists.

.DESCRIPTION
    This function checks whether there is an active Azure session. It retrieves the current Azure context using the `Get-AzContext` cmdlet. 
    If an active session is found, it returns `$true`; otherwise, it returns `$false`. 
    If the session check fails, a warning is displayed.

.PARAMETER None
    No parameters are required.

.EXAMPLE
    Test-AzConnection
    This will check if the current Azure session is active and return `$true` or `$false` accordingly.

.NOTES
    Author: Lakshmanachari Panuganti
    Date: 27th June 2025

#>
function Test-AzConnection {
    [CmdletBinding()]
    param ()

    try {
        $context = Get-AzContext
        if ($null -ne $context -and $null -ne $context.Account) {
            return $true
        } else {
            Write-Warning "⚠️ No active Azure session found."
            return $false
        }
    } catch {
        Write-Warning "⚠️ Azure session check failed: $_"
        return $false
    }
}
