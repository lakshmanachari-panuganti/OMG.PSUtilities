function Get-PSUADOPullRequest {
    <#
.SYNOPSIS
    Retrieves pull requests from Azure DevOps repositories within a project.

.DESCRIPTION
    This function retrieves pull requests from Azure DevOps repositories. If no repository is specified,
    it will get pull requests from all repositories in the project. You can filter by repository using
    either Repository ID or Repository Name.

.PARAMETER RepositoryId
    (Optional) The ID of the specific repository to get pull requests from.

.PARAMETER RepositoryName
    (Optional) The name of the specific repository to get pull requests from.

.PARAMETER Project
    (Mandatory) The Azure DevOps project name containing the repository.

.PARAMETER State
    (Optional) The state of pull requests to retrieve. Default is 'Active'. Other valid values: 'Completed', 'Abandoned'.

.PARAMETER Organization
    (Optional) The Azure DevOps organization name under which the project resides.
    Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

.PARAMETER PAT
    (Optional) Personal Access Token for Azure DevOps authentication.
    Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

.EXAMPLE
    Get-PSUADOPullRequest -Organization "omg" -Project "psutilities"

    Retrieves all active pull requests from all repositories in the "psutilities" project.

.EXAMPLE
    Get-PSUADOPullRequest -Organization "omg" -Project "psutilities" -RepositoryName "AzureDevOps" -State "Completed"

    Retrieves all completed pull requests from the "AzureDevOps" repository in "psutilities".

.EXAMPLE
    Get-PSUADOPullRequest -Organization "omg" -Project "psutilities" -RepositoryName "Ai"

    Retrieves all active pull requests from the "Ai" repository in the project.

.OUTPUTS
    [PSCustomObject]

.NOTES
    Author: Lakshmanachari Panuganti
    Date: 2nd August 2025
    Updated: 11th August 2025 - Made repository parameters optional

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    https://learn.microsoft.com/en-us/rest/api/azure/devops
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
            # Validate required parameters that have auto-detection
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
                    
                    # Escape project name for URI
                    $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                        $Project
                    } else {
                        [uri]::EscapeDataString($Project)
                    }
                    
                    try {
                        $stateParam = $State.ToLower()
                        $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$($repo.Id)/pullrequests?searchCriteria.status=$stateParam&api-version=7.0"

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
                    } catch {
                        Write-Warning "Failed to get pull requests from repository '$($repo.Name)': $($_.Exception.Message)"
                    }
                }

                Write-Verbose "Total pull requests found: $($allPullRequests.Count)"
                return $allPullRequests
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}