function Get-PSUADOProjectList {
    <#
    .SYNOPSIS
        Retrieves the list of Azure DevOps projects within the specified organization.

    .DESCRIPTION
        Uses Azure DevOps REST API to fetch all visible projects in an organization.
        Leverages environment variables if parameters are not supplied.

    .PARAMETER Organization
        The Azure DevOps organization name. If not provided, uses $env:ORGANIZATION.

    .EXAMPLE
        Get-PSUADOProjectList -Organization 'omgitsolutions'

    .EXAMPLE
        Get-PSUADOProjectList

    .OUTPUTS
        [PSCustomObject[]]

    .NOTES
        Author: Lakshmanachari Panuganti
        2 August 2025: Initial Development

    .LINK
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://github.com/lakshmanachari-panuganti
        https://www.linkedin.com/in/lakshmanachari-panuganti/
    #>

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [string]$PAT = $env:PAT
    )

    begin {
        if (-not $PSBoundParameters.ContainsKey('Organization') -and [string]::IsNullOrWhiteSpace($env:ORGANIZATION)) {
            Write-Warning "The environment variable 'ORGANIZATION' is not set and no -Organization parameter was passed. Please set it using:`nSet-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<Your organization name>'"
            return
        }

        $headers = Get-PSUADOAuthorizationHeader -PAT $PAT
    }

    process {
        $uri = "https://dev.azure.com/$Organization/_apis/projects?api-version=7.1-preview.4"

        try {
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
            if ($response.value) {
                ConvertTo-PSCustomWithCapitalizedKeys -InputObject $response.value
            }

        }
        catch {
            $PSCmdlet.ThrowTerminatingError("Failed to retrieve project list from ADO: $_") 
        }
    }
}
