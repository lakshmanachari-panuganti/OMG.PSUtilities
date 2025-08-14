function New-PSUADOPullRequest {
    <#
    .SYNOPSIS
        Creates a pull request in Azure DevOps using REST API.

    .DESCRIPTION
        This function submits a pull request (PR) from a specified source branch to a target branch in a given Azure DevOps repository.
        It authenticates using a Personal Access Token (PAT) and allows you to provide custom title and description content.
        You can specify the repository either by Repository ID or Repository Name.

    .PARAMETER Organization
        The Azure DevOps organization name (optional). Defaults to the ORGANIZATION environment variable.

    .PARAMETER Project
        The Azure DevOps project name.

    .PARAMETER RepoId
        The repository GUID in which to create the pull request.

    .PARAMETER Repository
        The repository name in which to create the pull request (optional).

    .PARAMETER SourceBranch
        The full name of the source branch (e.g., 'refs/heads/feature-branch') (optional). Defaults to current git branch.

    .PARAMETER TargetBranch
        The full name of the target branch (e.g., 'refs/heads/main') (optional). Defaults to the default branch from git.

    .PARAMETER Title
        The title of the pull request.

    .PARAMETER Description
        The detailed description of the pull request.

    .PARAMETER PAT
        The Azure DevOps Personal Access Token (PAT) used for authentication (optional). Defaults to the PAT environment variable.

    .EXAMPLE
        New-PSUADOPullRequest -Organization "myOrganization" -Project "MyProject" -RepoId "12345678-1234-1234-1234-123456789012" `
            -SourceBranch "refs/heads/feature-x" -TargetBranch "refs/heads/main" `
            -Title "Feature X Implementation" -Description "This PR adds feature X."

        Creates a pull request using repository ID.

    .EXAMPLE
        New-PSUADOPullRequest -Project "MyProject" -Repository "MyRepo" `
            -Title "Bug fix for login" -Description "Fixed authentication issue"

        Creates a pull request using repository name with default source/target branches.

    .EXAMPLE
        New-PSUADOPullRequest -Organization "myOrganization" -Project "MyProject" -Repository "MyRepo" `
            -SourceBranch "refs/heads/feature-branch" -TargetBranch "refs/heads/develop" `
            -Title "New Feature" -Description "Added new functionality" -PAT $env:AZDO_PAT

        Creates a pull request using repository name with specific branches and PAT.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2025-07-30
        Updated: 2025-08-14 - Added Repository parameter and parameter sets

    .LINK
        https://github.com/lakshmanachari-panuganti
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-requests/create
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByRepoName')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory, ParameterSetName = 'ByRepoId')]
        [ValidateNotNullOrEmpty()]
        [string]$RepoId,

        [Parameter(Mandatory, ParameterSetName = 'ByRepoName')]
        [ValidateNotNullOrEmpty()]
        [string]$Repository,

        [Parameter()]
        [string]$SourceBranch = $(git branch --show-current),

        [Parameter()]
        [string]$TargetBranch = $(git symbolic-ref refs/remotes/origin/HEAD | Split-Path -Leaf),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    process {
        try {
            $headers = Get-PSUAdoAuthHeader -PAT $PAT
            $headers['Content-Type'] = 'application/json'

            $escapedProject = [uri]::EscapeDataString($Project)

            # Determine repository identifier based on parameter set
            $repositoryIdentifier = switch ($PSCmdlet.ParameterSetName) {
                'ByRepoId' { 
                    $RepoId 
                }
                'ByRepoName' { 
                    # Resolve repository name to ID
                    Write-Verbose "Resolving repository name '$Repository' to ID..."
                    $repos = Get-PSUADORepositories -Project $Project -Organization $Organization -PAT $PAT
                    $matchedRepo = $repos | Where-Object { $_.Name -eq $Repository }
                    
                    if (-not $matchedRepo) {
                        throw "Repository '$Repository' not found in project '$Project'."
                    }
                    
                    Write-Verbose "Resolved repository '$Repository' to ID: $($matchedRepo.Id)"
                    $matchedRepo.Id
                }
            }

            # Ensure $SourceBranch and $TargetBranch are exists.
            $branches = git branch --list | ForEach-Object { $_.TrimStart('*').Trim() }
            if (-not ($branches -contains $SourceBranch)) {
                throw "Source branch '$SourceBranch' does not exist."
            }
            if (-not ($branches -contains $TargetBranch)) {
                throw "Target branch '$TargetBranch' does not exist."
            }

            $body = @{
                sourceRefName = $SourceBranch
                targetRefName = $TargetBranch
                title         = $Title
                description   = $Description
            } | ConvertTo-Json -Depth 3

            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$repositoryIdentifier/pullrequests?api-version=7.1-preview.1"

            Write-Verbose "Creating pull request in project: $Project"
            Write-Verbose "Repository: $repositoryIdentifier"
            Write-Verbose "Source branch: $SourceBranch"
            Write-Verbose "Target branch: $TargetBranch"
            Write-Verbose "API URI: $uri"

            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -ErrorAction Stop

            Write-Host "Pull Request created successfully. PR ID: $($response.pullRequestId)" -ForegroundColor Green
            Write-Host "PR URL: $($response._links.web.href)" -ForegroundColor Cyan

            [PSCustomObject]@{
                Id              = $response.pullRequestId
                Title           = $response.title
                Description     = $response.description
                Status          = $response.status
                IsDraft         = $response.isDraft
                SourceBranch    = $response.sourceRefName
                TargetBranch    = $response.targetRefName
                CreatedBy       = $response.createdBy.displayName
                CreatorEmail    = $response.createdBy.uniqueName
                CreationDate    = $response.creationDate
                RepositoryId    = $response.repository.id
                RepositoryName  = $response.repository.name
                ProjectName     = $response.repository.project.name
                WebUrl          = $response._links.web.href
                ApiUrl          = $response.url
                PSTypeName      = 'PSU.ADO.PullRequest'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
