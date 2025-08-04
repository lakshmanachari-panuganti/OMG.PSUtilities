function Get-PSUADOPullRequest {
    <#
.SYNOPSIS
    Retrieves all active pull requests from all accessible Azure DevOps projects and repositories.

.DESCRIPTION
    This function iterates through all projects and repositories within an Azure DevOps organization 
    and gathers pull requests that are in an active state. It requires a valid Personal Access Token (PAT) 
    and organization name either via parameters or environment variables.

.PARAMETER Organization
    The name of the Azure DevOps organization. Defaults to the environment variable ORGANIZATION if not specified.

.PARAMETER PAT
    The Personal Access Token used for authentication. Defaults to the environment variable PAT if not specified.

.PARAMETER State
    The state of pull requests to retrieve. Default is 'active'. Other valid values: 'completed', 'abandoned', 'all'.

.EXAMPLE
    Get-PSUADOPullRequest -Organization "omgitsolutions" -PAT $env:PAT

    Retrieves all active pull requests across the organization 'omgitsolutions'.

.EXAMPLE
    Get-PSUADOPullRequest -State Completed

    Retrieves all completed pull requests using environment variables $env:ORGANIZATION and $env:PAT.

.OUTPUTS
    [PSCustomObject]

.NOTES
    Author: Lakshmanachari Panuganti  
    Date: 2 August 2025 - Initial Development

.LINK
    https://www.linkedin.com/in/lakshmanachari-panuganti
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
#>

    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryId,

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [ValidateSet('Active', 'Completed', 'Abandoned')]
        [string]$State = 'Active',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )
    process {
        try {
            $headers = Get-PSUADOAuthorizationHeader -PAT $PAT
            # Resolve RepositoryId if RepositoryName is provided
            if ($PSCmdlet.ParameterSetName -eq 'ByName') {
                Write-Verbose "Resolving repository name '$RepositoryName' to ID..."
                $repoUri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories?api-version=7.1-preview.1"
                $repoResponse = Invoke-RestMethod -Uri $repoUri -Headers $headers -Method Get

                $matchedRepo = $repoResponse.value | Where-Object { $_.name -eq $RepositoryName }
                if (-not $matchedRepo) {
                    throw "Repository '$RepositoryName' not found in project '$Project'."
                }

                $RepositoryId = $matchedRepo.id
                Write-Verbose "Resolved repository ID: $RepositoryId"
            }

            Write-Verbose "Fetching $State pull requests for repository ID '$RepositoryId' in project '$Project'..."
            $stateParam = $State.ToLower()
            $uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/pullrequests?searchCriteria.status=$stateParam&api-version=7.0"

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            $response.value | ForEach-Object {
                [pscustomobject]@{
                    Id             = $_.pullRequestId
                    Title          = $_.title
                    Description    = $_.description
                    Status         = $_.status
                    IsDraft        = $_.isDraft
                    SourceBranch   = $_.sourceRefName
                    TargetBranch   = $_.targetRefName
                    CreatedBy      = $_.createdBy.displayName
                    CreatorEmail   = $_.createdBy.uniqueName
                    CreationDate   = $_.creationDate
                    MergeStatus    = $_.mergeStatus
                    WebUrl         = $_.url
                    RepositoryId   = $_.repository.id
                    RepositoryName = $_.repository.name
                    ProjectName    = $_.repository.project.name
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}