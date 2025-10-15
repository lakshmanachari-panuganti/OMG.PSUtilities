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

    process {
        # Display parameters
        Write-Verbose "Parameters:"
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            if ($param.Key -eq 'PAT') {
                $maskedPAT = if ($param.Value -and $param.Value.Length -ge 3) { $param.Value.Substring(0, 3) + "********" } else { "***" }
                Write-Verbose "  $($param.Key): $maskedPAT"
            } else {
                Write-Verbose "  $($param.Key): $($param.Value)"
            }
        }

        $headers = Get-PSUAdoAuthHeader -PAT $PAT
        $uri = "https://dev.azure.com/$Organization/_apis/projects?api-version=7.1-preview.4"

        try {
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
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}