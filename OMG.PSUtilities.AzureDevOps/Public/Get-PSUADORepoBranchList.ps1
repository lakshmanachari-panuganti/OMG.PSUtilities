<#
.SYNOPSIS
    Retrieves a list of branches for a specified Azure DevOps repository.

.DESCRIPTION
    Connects to the Azure DevOps REST API and fetches all branches (refs/heads) for a given repository within a project.
    Returns an array of custom objects with branch properties, where each property name is capitalized for readability.
    Supports lookup by RepositoryId (GUID) or Repository (name).

.PARAMETER Project
    The name of the Azure DevOps project containing the repository.

.PARAMETER RepositoryId
    The unique identifier (GUID) of the repository to retrieve branches from.

.PARAMETER Repository
    The name of the repository to retrieve branches from.

.PARAMETER Organization
    The Azure DevOps organization name. Defaults to the ORGANIZATION environment variable if not specified.

.PARAMETER PAT
    Personal Access Token for Azure DevOps authentication. Defaults to the PAT environment variable if not specified.
    The PAT must have read permissions for Code (Git repositories).

.EXAMPLE
    Get-PSUADORepoBranchList -Project "PSUtilities" -RepositoryId "12345678-1234-1234-1234-123456789abc"
    Retrieves all branches for the specified repository using RepositoryId.

.EXAMPLE
    Get-PSUADORepoBranchList -Project "PSUtilities" -Repository "MyRepo"
    Retrieves all branches for the specified repository using Repository name.

.EXAMPLE
    $branches = Get-PSUADORepoBranchList -Project "PSUtilities" -Repository "WebRepo"
    $branches | Where-Object { $_.Name -like "*feature*" }
    Retrieves all branches and filters for feature branches.

.OUTPUTS
    [PSCustomObject]

.NOTES
    Author: Lakshmanachari Panuganti
    Created: August 2025

.LINK
    https://github.com/lakshmanachari-panuganti
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    https://learn.microsoft.com/en-us/rest/api/azure/devops/git/refs/list
    https://learn.microsoft.com/en-us/azure/devops/repos/git/branches
#>
function Get-PSUADORepoBranchList {
    [CmdletBinding(DefaultParameterSetName = 'ByRepositoryId')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ByRepositoryId')]
        [Parameter(Mandatory, ParameterSetName = 'ByRepositoryName')]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory, ParameterSetName = 'ByRepositoryId')]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryId,

        [Parameter(Mandatory, ParameterSetName = 'ByRepositoryName')]
        [ValidateNotNullOrEmpty()]
        [string]$Repository,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    process {
        try {
            # Display parameters
            Write-Host "Parameters:" -ForegroundColor Cyan
            foreach ($param in $PSBoundParameters.GetEnumerator()) {
                if ($param.Key -eq 'PAT') {
                    $maskedPAT = if ($param.Value -and $param.Value.Length -ge 3) { $param.Value.Substring(0, 3) + "********" } else { "***" }
                    Write-Host "  $($param.Key): $maskedPAT" -ForegroundColor Cyan
                } else {
                    $displayValue = $param.Value.ToString()
                    if ($displayValue.Length -gt 30) {
                        $displayValue = $displayValue.Substring(0, 27) + "..."
                    }
                    Write-Host "  $($param.Key): $displayValue" -ForegroundColor Cyan
                }
            }
            Write-Host ""

            if ($PSCmdlet.ParameterSetName -eq 'ByRepositoryName') {
                # Get repository ID from repository name
                $repoUri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$Repository?api-version=7.0"
                $headers = Get-PSUAdoAuthHeader -PAT $PAT
                $repoResponse = Invoke-RestMethod -Uri $repoUri -Headers $headers -Method Get
                if (-not $repoResponse.id) {
                    Write-Error "Repository '$Repository' not found in project '$Project'."
                    return
                }
                $RepositoryId = $repoResponse.id
            }

            $uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/refs?filter=heads/&api-version=7.0"
            $headers = Get-PSUAdoAuthHeader -PAT $PAT

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            $formattedResults = @()
            if ($response.value) {
                foreach ($item in $response.value) {
                    $formattedObject = [PSCustomObject]@{}

                    foreach ($property in $item.PSObject.Properties) {
                        $originalName = $property.Name
                        $originalValue = $property.Value

                        # Capitalize the first letter of the property name
                        $capitalizedName = ($originalName[0].ToString().ToUpper()) + ($originalName.Substring(1).ToLower())

                        $formattedObject | Add-Member -MemberType NoteProperty -Name $capitalizedName -Value $originalValue
                    }

                    $formattedResults += $formattedObject
                }
            }

            return $formattedResults
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
