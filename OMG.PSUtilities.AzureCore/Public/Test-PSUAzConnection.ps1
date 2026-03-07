<#
.SYNOPSIS
    Checks if an active Azure session exists.

.DESCRIPTION
    Checks for an active Azure session using the current Az context and returns
    $true if a valid account is found, otherwise $false.

.EXAMPLE
    Test-PSUAzConnection

    Returns $true if an active Azure session exists, otherwise $false.

.OUTPUTS
    [Boolean]

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 27th June 2025
    Last Modified: 7th March 2026
    Version: 1.1

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureCore
#>
function Test-PSUAzConnection {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Checking Azure session..."
    }

    process {
        try {
            $context = Get-AzContext
            if ($null -ne $context -and $null -ne $context.Account) {
                return $true
            } else {
                Write-Warning "No active Azure session found."
                return $false
            }
        } catch {
            Write-Warning "Azure session check failed: $_"
            return $false
        }
    }
}
