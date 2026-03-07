<#
.SYNOPSIS
    Retrieves an Azure access token for a specified resource.

.DESCRIPTION
    Acquires an Azure access token using the current Azure context for the specified
    resource URL. Ensures Az.Accounts is available and the user is logged in before
    attempting to retrieve the token.

.PARAMETER Resource
    (Optional) The resource URL for which to acquire the token.
    Default is "https://management.azure.com/".
    Example: "https://graph.microsoft.com/"

.EXAMPLE
    Get-PSUAzToken

    Retrieves an access token for the default Azure Management resource.

.EXAMPLE
    Get-PSUAzToken -Resource "https://graph.microsoft.com/"

    Retrieves an access token for the Microsoft Graph API.

.OUTPUTS
    [String]

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 27th June 2025
    Last Modified: 7th March 2026
    Version: 1.1

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureCore
    https://learn.microsoft.com/en-us/powershell/module/az.accounts/get-azaccesstoken
#>
function Get-PSUAzToken {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Resource = "https://management.azure.com/"
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Parameters:"
        Write-Verbose "  Resource = $Resource"

        # Ensure Az.Accounts is available
        if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
            throw "Az.Accounts module is not installed. Please run: Install-Module Az.Accounts"
        }
    }

    process {
        try {
            # Ensure user is logged in
            if (-not (Get-AzContext)) {
                Write-Host "Logging in to Azure..." -ForegroundColor Yellow
                Connect-AzAccount -ErrorAction Stop
            }

            # Acquire token
            $token = (Get-AzAccessToken -ResourceUrl $Resource -ErrorAction Stop).Token
            Write-Host "Access token acquired for $Resource"
            return $token
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
