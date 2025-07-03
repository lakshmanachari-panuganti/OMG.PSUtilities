
function Test-PSUAzConnection {
    <#
.SYNOPSIS
    Checks if an active Azure session exists.

.DESCRIPTION
    Checks for an active Azure session and returns $true if found, otherwise $false.

.EXAMPLE
    Test-PSUAzConnection

.NOTES
    Author: Lakshmanachari Panuganti
    File Creation Date: 2025-06-27
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    try {
        $context = Get-AzContext
        if ($null -ne $context -and $null -ne $context.Account) {
            return $true
        }
        else {
            Write-Warning "⚠️ No active Azure session found."
            return $false
        }
    }
    catch {
        Write-Warning "⚠️ Azure session check failed: $_"
        return $false
    }
}
