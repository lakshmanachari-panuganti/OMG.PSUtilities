function Get-PSUADOPullRequest {
    <#
.SYNOPSIS
    Retrieves pull requests from Azure DevOps repositories within a project.

.DESCRIPTION
    This function retrieves pull requests from Azure DevOps repositories. If no repository is specified,
    it will get pull requests from all repositories in the project. You can filter by repository using
    either Repository ID or Repository Name.

.PARAMETER RepositoryId
    Optional. The ID of the specific repository to get pull requests from.

.PARAMETER RepositoryName
    Optional. The name of the specific repository to get pull requests from.

.PARAMETER Project
    The name of the Azure DevOps project.

.PARAMETER State
    The state of pull requests to retrieve. Default is 'Active'. Other valid values: 'Completed', 'Abandoned'.

.PARAMETER Organization
    The name of the Azure DevOps organization. Defaults to the environment variable ORGANIZATION if not specified.

.PARAMETER PAT
    The Personal Access Token used for authentication. Defaults to the environment variable PAT if not specified.

.EXAMPLE
    Get-PSUADOPullRequest -Project "MyProject"

    Retrieves all active pull requests from all repositories in the "MyProject" project.

.EXAMPLE
    Get-PSUADOPullRequest -Project "MyProject" -RepositoryName "MyRepo" -State "Completed"

    Retrieves all completed pull requests from the "MyRepo" repository in "MyProject".

.EXAMPLE
    Get-PSUADOPullRequest -Organization "omgitsolutions" -Project "PSUtilities" -PAT $env:PAT

    Retrieves all active pull requests from all repositories in the project using specific organization and PAT.

.OUTPUTS
    [PSCustomObject]

.NOTES
    Author: Lakshmanachari Panuganti  
    Date: 2 August 2025 - Initial Development
    Updated: 11 August 2025 - Made repository parameters optional

.LINK
    https://www.linkedin.com/in/lakshmanachari-panuganti
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
#>

    [CmdletBinding(DefaultParameterSetName = 'AllRepos')]
    param (
        [Parameter(ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryId,

        [Parameter(ParameterSetName = 'ByName')]
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
            $headers = Get-PSUAdoAuthHeader -PAT $PAT
            $allPullRequests = @()

            # Determine which repositories to process
            $repositoriesToProcess = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ById' {
                    # Get repository by ID
                    $repositoriesToProcess = Get-PSUADORepositories -Project $Project -Organization $Organization -PAT $PAT | Where-Object { $_.Id -eq $RepositoryId }
                }
                'ByName' {
                    # Get repository by name
                    $repositoriesToProcess = Get-PSUADORepositories -Project $Project -Organization $Organization -PAT $PAT | Where-Object { $_.Name -eq $RepositoryName }
                }
                'AllRepos' {
                    # Get all repositories in the project
                    $repositoriesToProcess = Get-PSUADORepositories -Project $Project -Organization $Organization -PAT $PAT
                }
            }

            # Process each repository
            foreach ($repo in $repositoriesToProcess) {
                Write-Verbose "Fetching $State pull requests for repository '$($repo.Name)' (ID: $($repo.Id))"
                $Project = $repo.Project
                try {
                    $stateParam = $State.ToLower()
                    $uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$($repo.Id)/pullrequests?searchCriteria.status=$stateParam&api-version=7.0"

                    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
                    Write-Verbose "Found $($response.value.Count) pull requests in repository '$($repo.Name)'"
                    if ($response.value.Count) {
                        $pullRequests = $response.value | ForEach-Object {
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
                        $allPullRequests += $pullRequests
                    }
                }
                catch {
                    Write-Warning "Failed to get pull requests from repository '$($repo.Name)': $($_.Exception.Message)"
                }
            }

            Write-Verbose "Total pull requests found: $($allPullRequests.Count)"
            return $allPullRequests
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}