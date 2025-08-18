function New-PSUADOPullRequest {
    <#
    .SYNOPSIS
        Creates a pull request in Azure DevOps using REST API.

    .DESCRIPTION
        This function submits a pull request (PR) from a specified source branch to a target branch in a given Azure DevOps repository.
        It authenticates using a Personal Access Token (PAT) and allows you to provide custom title and description content.
        You can specify the repository either by Repository ID or Repository Name.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "value_of_org_name"

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing the repository.

    .PARAMETER RepoId
        (Mandatory - ParameterSet: ByRepoId) The repository GUID in which to create the pull request.

    .PARAMETER Repository
        (Mandatory - ParameterSet: ByRepoName) The repository name in which to create the pull request.

    .PARAMETER SourceBranch
        (Optional) The full name of the source branch (e.g., 'refs/heads/feature-branch').
        Default value is 'refs/heads/' + current git branch from git branch --show-current.

    .PARAMETER TargetBranch
        (Optional) The full name of the target branch (e.g., 'refs/heads/main').
        Default value is 'refs/heads/' + default branch from git symbolic-ref refs/remotes/origin/HEAD.

    .PARAMETER Title
        (Mandatory) The title of the pull request.

    .PARAMETER Description
        (Mandatory) The detailed description of the pull request.

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "value_of_PAT"

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
        [ValidateScript({
            if ($_ -match '^refs/heads/.+') { $true }
            else { throw "SourceBranch must be in the format 'refs/heads/branch-name'." }
        })]
        [string]$SourceBranch = $("refs/heads/$((git branch --show-current).Trim())"),

        [Parameter()]
        [ValidateScript({
            if ($_ -match '^refs/heads/.+') { $true }
            else { throw "TargetBranch must be in the format 'refs/heads/branch-name'." }
        })]
        [string]$TargetBranch = $("refs/heads/$((git symbolic-ref refs/remotes/origin/HEAD | Split-Path -Leaf).Trim())"),

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
            # Resolve repository ID if needed
            $repositoryIdentifier = $null
            if ($PSCmdlet.ParameterSetName -eq 'ByRepoId') {
                $repositoryIdentifier = $RepoId
            } else {
                $repos = Get-PSUADORepositories -Project $Project -Organization $Organization -PAT $PAT
                $matchedRepo = $repos | Where-Object { $_.Name -eq $Repository }
                if (-not $matchedRepo) {
                    throw "Repository '$Repository' not found in project '$Project'."
                }
                $repositoryIdentifier = $matchedRepo.Id
            }

            # Compose authentication header
            $headers = Get-PSUAdoAuthHeader -PAT $PAT

            $body = @{
                sourceRefName = $SourceBranch
                targetRefName = $TargetBranch
                title         = $Title
                description   = ($Description -join "`n")
            } | ConvertTo-Json -Depth 10

            $escapedProject = [uri]::EscapeDataString($Project)
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$repositoryIdentifier/pullrequests?api-version=7.0"
            Write-Verbose "Creating pull request in project: $Project"
            Write-Verbose "Repository: $repositoryIdentifier"
            Write-Verbose "Source branch: $SourceBranch"
            Write-Verbose "Target branch: $TargetBranch"
            Write-Verbose "API URI: $uri"

            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -ContentType "application/json" -ErrorAction Stop
            $WebUrl = "https://dev.azure.com/$Organization/$escapedProject/_git/$repositoryIdentifier/pullrequest/$($response.pullRequestId)"
            Write-Host "Pull Request created successfully. PR ID: $($response.pullRequestId)" -ForegroundColor Green
            Write-Host "PR URL: $WebUrl" -ForegroundColor Cyan

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
                WebUrl          = $WebUrl
                ApiUrl          = $response.url
                PSTypeName      = 'PSU.ADO.PullRequest'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
