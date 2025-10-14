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
        (Optional) The Azure DevOps project name containing the repository.
        Default value is auto-detected from git remote origin URL.

    .PARAMETER RepoId
        (Mandatory - ParameterSet: ByRepoId) The repository GUID in which to create the pull request.

    .PARAMETER Repository
        (Optional - ParameterSet: ByRepoName) The repository name in which to create the pull request.
        Default value is auto-detected from git remote origin URL.

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

    .PARAMETER Draft
        (Optional) Switch parameter to create the pull request as a draft.

    .PARAMETER CompleteOnApproval
        (Optional) Switch parameter to enable auto-completion when the pull request is approved.
        The PR will automatically complete when all required approvals and policies are met.

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
        New-PSUADOPullRequest -Title "Auto-detected PR" -Description "Uses auto-detection for org, project, and repo"

        Creates a pull request using auto-detected organization, project, and repository from git remote URL.

    .EXAMPLE
        New-PSUADOPullRequest -Project "MyProject" -Repository "MyRepo" `
            -Title "Bug fix for login" -Description "Fixed authentication issue" -Draft

        Creates a draft pull request using repository name with default source/target branches.

    .EXAMPLE
        New-PSUADOPullRequest -Title "Auto-complete feature" -Description "This will auto-complete when approved" `
            -CompleteOnApproval

        Creates a pull request that will automatically complete when all approvals and policies are satisfied.

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
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
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
        [string]$Organization = $(if ($env:ORGANIZATION) { $env:ORGANIZATION } else {
            git remote get-url origin 2>$null | ForEach-Object {
                if ($_ -match 'dev\.azure\.com/([^/]+)/') { $matches[1] }
            }
        }),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Project = $(git remote get-url origin 2>$null | ForEach-Object {
            if ($_ -match 'dev\.azure\.com/[^/]+/([^/]+)/_git/') { 
                $matches[1]
            }
        }),

        [Parameter(Mandatory, ParameterSetName = 'ByRepoId')]
        [ValidateNotNullOrEmpty()]
        [string]$RepoId,

        [Parameter(ParameterSetName = 'ByRepoName')]
        [ValidateNotNullOrEmpty()]
        [string]$Repository = $(git remote get-url origin 2>$null | ForEach-Object {
            if ($_ -match '/_git/([^/]+?)(?:\.git)?/?$') { $matches[1] }
        }),
        
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
        [switch]$Draft,

        [Parameter()]
        [switch]$CompleteOnApproval,

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
                isDraft       = $Draft.IsPresent
            } | ConvertTo-Json -Depth 10

            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            }
            else {
                [uri]::EscapeDataString($Project)
            }
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$repositoryIdentifier/pullrequests?api-version=7.0"
            $draftStatus = if ($Draft.IsPresent) { "draft " } else { "" }
            Write-Verbose "Creating ${draftStatus}pull request in project: $Project"
            Write-Verbose "Repository: $repositoryIdentifier"
            Write-Verbose "Source branch: $SourceBranch"
            Write-Verbose "Target branch: $TargetBranch"
            Write-Verbose "API URI: $uri"

            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -ContentType "application/json" -ErrorAction Stop
            $WebUrl = "https://dev.azure.com/$Organization/$escapedProject/_git/$repositoryIdentifier/pullrequest/$($response.pullRequestId)"
            $draftText = if ($response.isDraft) { "Draft " } else { "" }
            Write-Host "${draftText}Pull Request created successfully. PR ID: $($response.pullRequestId)" -ForegroundColor Green
            Write-Host "PR URL: $WebUrl" -ForegroundColor Cyan

            # Enable auto-completion if specified
            if ($CompleteOnApproval) {
                try {
                    # Set auto-complete options
                    $autoCompleteBody = @{
                        autoCompleteSetBy = @{
                            id = $response.createdBy.id
                        }
                        completionOptions = @{
                            mergeStrategy = "noFastForward"
                            deleteSourceBranch = $false
                            squashMerge = $false
                        }
                    } | ConvertTo-Json -Depth 10

                    $autoCompleteUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$repositoryIdentifier/pullrequests/$($response.pullRequestId)?api-version=7.0"
                    Write-Verbose "Setting auto-completion for PR ID: $($response.pullRequestId)"
                    
                    Invoke-RestMethod -Method Patch -Uri $autoCompleteUri -Headers $headers -Body $autoCompleteBody -ContentType "application/json" -ErrorAction Stop
                    Write-Host "Auto-completion enabled. PR will complete automatically when all policies and approvals are satisfied." -ForegroundColor Yellow
                }
                catch {
                    Write-Warning "Failed to enable auto-completion: $($_.Exception.Message)"
                }
            }

            [PSCustomObject]@{
                Id                  = $response.pullRequestId
                Title               = $response.title
                Description         = $response.description
                Status              = $response.status
                IsDraft             = $response.isDraft
                SourceBranch        = $response.sourceRefName
                TargetBranch        = $response.targetRefName
                CreatedBy           = $response.createdBy.displayName
                CreatorEmail        = $response.createdBy.uniqueName
                CreationDate        = $response.creationDate
                RepositoryId        = $response.repository.id
                RepositoryName      = $response.repository.name
                ProjectName         = $response.repository.project.name
                WebUrl              = $WebUrl
                ApiUrl              = $response.url
                CompleteOnApproval  = $CompleteOnApproval.IsPresent
                PSTypeName          = 'PSU.ADO.PullRequest'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
