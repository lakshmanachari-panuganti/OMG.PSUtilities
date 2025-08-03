function Get-PSUADORepositories {
    <#
    .SYNOPSIS
        Retrieves all repositories from Azure DevOps for a given organization and project.

    .DESCRIPTION
        This function queries the Azure DevOps REST API to get all repositories in the specified organization and project.

    .PARAMETER Project
        The name of the Azure DevOps project.

    .PARAMETER Organization
        The Azure DevOps organization. If not provided, defaults to the ORGANIZATION environment variable.

    .PARAMETER PAT
        The Personal Access Token for authentication. If not provided, defaults to the PAT environment variable.

    .OUTPUTS
        [PSCustomObject]

    .EXAMPLE
        Get-PSUADORepositories -Project "PSUtilities"

        Retrieves all repositories in the "PSUtilities" project under the organization specified in $env:ORGANIZATION.

    .EXAMPLE
        Get-PSUADORepositories -Project "PSUtilities" -Organization "omgitsolutions" -PAT "<YourPAT>"

        Retrieves all repositories explicitly using provided organization and PAT.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2 July 2025: Initial Development.

    .LINK
        https://www.github.com/lakshmanachari-panuganti
        https://www.linkedin.com/in/lakshmanachari-panuganti
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        Install-Module -Name OMG.PSUtilities.AzureDevOps
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Project,

        [Parameter()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [string]$PAT = $env:PAT
    )

begin {
        if (-not [string]::IsNullOrWhiteSpace($Organization)) {
            return $Organization
        }
        else {
            Write-Warning 'A valid Azure DevOps organization is not provided.'
            Write-Host "`nTo fix this, either:"
            Write-Host "  1. Pass the -Organization parameter explicitly, OR" -ForegroundColor Yellow
            Write-Host "  2. Create an environment variable using:" -ForegroundColor Yellow
            Write-Host "     Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<YOUR ADO ORGANIZATION NAME>'`n" -ForegroundColor Cyan
            $script:ShouldExit = $true
            return
        }
    
        $headers = Get-PSUADOAuthorizationHeader -PAT $PAT
}

process {
    if ($script:ShouldExit) {
        return
    }

    $uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories?api-version=7.1-preview.1"

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        if ($response.value) {
            $response.value | ForEach-Object {
                ConvertTo-PSCustomWithCapitalizedKeys -InputObject $_
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

}