function Get-PSUADOAuthorizationHeader {
    <#
    .SYNOPSIS
        Constructs the Authorization header for Azure DevOps REST API requests.

    .DESCRIPTION
        This private helper function returns a hashtable containing the 'Authorization' and 'Content-Type' headers
        required to communicate with the Azure DevOps REST API. It prioritizes values from the environment variable
        $env:PAT but allows override via parameters.

    .PARAMETER PAT
        The Personal Access Token used to authenticate with Azure DevOps REST API.

    .OUTPUTS
        [Hashtable]

    .EXAMPLE
        $headers = Get-PSUADOAuthorizationHeader

    .EXAMPLE
        $headers = Get-PSUADOAuthorizationHeader -PAT "YourPATvalue"

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2 July 2025: Initial Development.

    .LINK
        https://github.com/lakshmanachari-panuganti
        https://www.linkedin.com/in/lakshmanachari-panuganti
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        Install-Module -Name OMG.PSUtilities.AzureDevOps
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $PAT = $env:PAT
    )

    if ([string]::IsNullOrWhiteSpace($PAT)) {
        Write-Warning 'A valid Azure DevOps PAT is not provided.'
        Write-Host "`nTo fix this, either:"
        Write-Host "  1. Pass the -PAT parameter explicitly, OR" -ForegroundColor Yellow
        Write-Host "  2. Create an environment variable using:" -ForegroundColor Yellow
        Write-Host "     Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<YOUR ADO PAT NAME>'`n" -ForegroundColor Cyan
        $script:ShouldExit = $true
    }
    else {
        $encodedPAT = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
        @{
            Authorization  = "Basic $encodedPAT"
            'Content-Type' = 'application/json'
        }
    }

}
