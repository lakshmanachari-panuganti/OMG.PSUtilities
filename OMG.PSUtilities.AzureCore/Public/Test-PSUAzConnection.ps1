
function Test-PSUAzConnection {
    <#
.SYNOPSIS
    Checks if an active Azure session exists.

.DESCRIPTION
    Checks for an active Azure session and returns $true if found, otherwise $false.

.EXAMPLE
    Test-PSUAzConnection

    Tests if there is an active Azure session and returns True or False.

.OUTPUTS
    [Boolean]

.NOTES
    Author: Lakshmanachari Panuganti
    Date: 27th June 2025

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureCore
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
