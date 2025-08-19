function Get-PSUAzToken {
<#
.SYNOPSIS
    Retrieves an Azure access token for a specified resource.

.DESCRIPTION
    Acquires an Azure access token using the current context for the specified resource URL.

.PARAMETER Resource
    The resource URL for which to acquire the token.

.EXAMPLE
    Get-PSUAzToken -Resource "https://graph.microsoft.com/"

.OUTPUTS
    [String]

.NOTES
    Author: Lakshmanachari Panuganti
    Date: 27th June 2025

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureCore
#>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Resource = "https://management.azure.com/"
    )

    try {
        # Ensure Az.Accounts is available
        if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
            throw "Az.Accounts module is not installed. Please run: Install-Module Az.Accounts"
        }

        # Ensure user is logged in
        if (-not (Get-AzContext)) {
            Write-Host "Logging in to Azure..." -ForegroundColor Yellow
            Connect-AzAccount -ErrorAction Stop
        }

        # Acquire token
        $token = (Get-AzAccessToken -ResourceUrl $Resource -ErrorAction Stop).Token
        Write-Host "Access token acquired for $Resource"
        return $token
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
