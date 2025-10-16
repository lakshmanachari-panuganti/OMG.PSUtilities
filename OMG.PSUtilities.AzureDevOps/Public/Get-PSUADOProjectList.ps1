function Get-PSUADOProjectList {
    <#
    .SYNOPSIS
        Retrieves the list of Azure DevOps projects within the specified organization.

    .DESCRIPTION
        Uses Azure DevOps REST API to fetch all visible projects in an organization.
        Leverages environment variables if parameters are not supplied.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the projects reside.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        Get-PSUADOProjectList -Organization "omg"

        Retrieves all projects from the "omg" organization.

    .EXAMPLE
        Get-PSUADOProjectList

        Retrieves all projects using the organization from $env:ORGANIZATION.

    .OUTPUTS
        [PSCustomObject[]]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2nd August 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://learn.microsoft.com/en-us/rest/api/azure/devops
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )


    begin {
        # Display parameters
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Parameters:"
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            if ($param.Key -eq 'PAT') {
                $maskedPAT = if ($param.Value -and $param.Value.Length -ge 3) { $param.Value.Substring(0, 3) + "********" } else { "***" }
                Write-Verbose "  $($param.Key): $maskedPAT"
            } else {
                Write-Verbose "  $($param.Key): $($param.Value)"
            }
        }

        # Validate Organization (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
        if (-not $Organization) {
            throw "The default value for the 'ORGANIZATION' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>' or provide via -Organization parameter."
        }

        # Validate PAT (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
        if (-not $PAT) {
            throw "The default value for the 'PAT' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<pat>' or provide via -PAT parameter."
        }

        $headers = Get-PSUAdoAuthHeader -PAT $PAT
    }
    process {
        try {
            $uri = "https://dev.azure.com/$Organization/_apis/projects?api-version=7.1-preview.4"

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
            $response.value | ForEach-Object {
                [PSCustomObject]@{
                    Name           = $_.name
                    Id             = $_.id
                    Description    = $_.description
                    Url            = $_.url
                    State          = $_.state
                    Revision       = $_.revision
                    Visibility     = $_.visibility
                    LastUpdateTime = $_.lastUpdateTime
                    PSTypeName     = 'PSU.ADO.Project'
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
