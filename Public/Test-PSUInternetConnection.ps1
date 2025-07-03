<#
.SYNOPSIS
    Tests general internet connectivity.

.DESCRIPTION
    Attempts to connect to www.google.com to verify internet access.

.EXAMPLE
    Test-PSUInternetConnection

.NOTES
    Author: Lakshmanachari Panuganti
    File Creation Date: 2025-06-27
#>
function Test-PSUInternetConnection {
    try {
        $null = Invoke-WebRequest www.google.com -UseBasicParsing -TimeoutSec 5
        return $true
    } catch {
        return $false
    }
}
