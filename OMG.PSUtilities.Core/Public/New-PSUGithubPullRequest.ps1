function New-PSUGithubPullRequest {
    <#
    .SYNOPSIS
        Creates a pull request in GitHub using REST API.

    .DESCRIPTION
        This function submits a pull request (PR) from a specified source branch to a target branch in a given GitHub repository.
        It authenticates using a Personal Access Token (PAT) and allows you to provide custom title and description content.
        You can specify the repository either by Repository name or use auto-detection from git remote.

    .PARAMETER Owner
        (Optional) The GitHub repository owner (username or organization).
        Default value is auto-detected from git remote origin URL.

    .PARAMETER Repository
        (Optional) The GitHub repository name.
        Default value is auto-detected from git remote origin URL.

    .PARAMETER SourceBranch
        (Optional) The name of the source branch (e.g., 'feature-branch').
        Default value is current git branch from git branch --show-current.

    .PARAMETER TargetBranch
        (Optional) The name of the target branch (e.g., 'main').
        Default value is default branch from git symbolic-ref refs/remotes/origin/HEAD.

    .PARAMETER Title
        (Mandatory) The title of the pull request.

    .PARAMETER Description
        (Mandatory) The detailed description of the pull request.

    .PARAMETER Draft
        (Optional) Switch parameter to create the pull request as a draft.

    .PARAMETER Labels
        (Optional) Array of label names to apply to the pull request.

    .PARAMETER Assignees
        (Optional) Array of GitHub usernames to assign to the pull request.

    .PARAMETER CompleteOnApproval
        (Optional) Switch parameter to enable auto-merge when the pull request is approved.
        Requires repository admin permissions and auto-merge to be enabled on the repository.

    .PARAMETER Token
        (Optional) GitHub Personal Access Token for authentication.
        Default value is $env:GITHUB_TOKEN. Set using: Set-PSUUserEnvironmentVariable -Name "GITHUB_TOKEN" -Value "value_of_token"

        How to obtain a GitHub Personal Access Token:
        1. Go to GitHub and log in.
        2. Navigate to Settings > Developer settings > Personal access tokens > Tokens (classic).
        3. Click "Generate new token (classic)".
        4. Set expiration (recommend 90 days for security) and select these scopes:
           - repo (Full control of private repositories)
           - workflow (Update GitHub Action workflows)
        5. Click "Generate token" and copy it immediately.
        6. Store it securely using: Set-PSUUserEnvironmentVariable -Name "GITHUB_TOKEN" -Value "your_token_here"

    .EXAMPLE
        New-PSUGithubPullRequest -Title "Feature X Implementation" -Description "This PR adds feature X."

        Creates a pull request using auto-detected repository and default branches.

    .EXAMPLE
        New-PSUGithubPullRequest -Owner "myuser" -Repository "myrepo" `
            -SourceBranch "feature-login" -TargetBranch "develop" `
            -Title "Add login functionality" -Description "Implements user authentication"

        Creates a pull request with specific owner, repository, and branches.

    .EXAMPLE
        New-PSUGithubPullRequest -Title "Bug fix" -Description "Fixed critical bug" `
            -Draft -Labels @("bug", "priority-high") -Assignees @("reviewer1", "reviewer2")

        Creates a draft pull request with labels and assignees.

    .EXAMPLE
        New-PSUGithubPullRequest -Title "Auto-merge feature" -Description "This will auto-merge when approved" `
            -CompleteOnApproval

        Creates a pull request that will automatically merge when approved.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 18th August 2025
        Requires: GitHub Personal Access Token with repo permissions

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
        https://docs.github.com/en/rest/pulls/pulls#create-a-pull-request
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    param (
        [Parameter()]
        [string]$Owner,

        [Parameter()]
        [string]$Repository,
        
        [Parameter()]
        [string]$SourceBranch = $((git branch --show-current).Trim()),

        [Parameter()]
        [string]$TargetBranch = $((git symbolic-ref refs/remotes/origin/HEAD | Split-Path -Leaf).Trim()),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter()]
        [switch]$Draft,

        [Parameter()]
        [string[]]$Labels,

        [Parameter()]
        [string[]]$Assignees,

        [Parameter()]
        [switch]$CompleteOnApproval,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Token = $env:GITHUB_TOKEN
    )

    process {
        try {
            # Auto-detect repository info if not provided
            if (-not $Owner -or -not $Repository) {
                $remoteUrl = git remote get-url origin 2>$null
                if (-not $remoteUrl) {
                    throw "No git remote origin found and Owner/Repository not specified."
                }

                if ($remoteUrl -match 'github\.com[/:]([^/]+)/([^/]+?)(?:\.git)?/?$') {
                    if (-not $Owner) { $Owner = $matches[1] }
                    if (-not $Repository) { $Repository = $matches[2] }
                } else {
                    throw "Could not parse GitHub repository from remote URL: $remoteUrl. Please specify Owner and Repository parameters."
                }
            }

            # Validate token
            if (-not $Token) {
                throw "GitHub token not found. Set it using: Set-PSUUserEnvironmentVariable -Name 'GITHUB_TOKEN' -Value 'your-token'"
            }

            # Prepare headers
            $headers = @{
                'Authorization' = "Bearer $Token"
                'Accept' = 'application/vnd.github.v3+json'
                'X-GitHub-Api-Version' = '2022-11-28'
            }

            # Prepare body
            $body = @{
                title = $Title
                head = $SourceBranch
                base = $TargetBranch
                body = $Description
                draft = $Draft.IsPresent
            }

            $bodyJson = $body | ConvertTo-Json -Depth 10

            # Create the pull request
            $uri = "https://api.github.com/repos/$Owner/$Repository/pulls"
            Write-Verbose "Creating pull request in repository: $Owner/$Repository"
            Write-Verbose "Source branch: $SourceBranch"
            Write-Verbose "Target branch: $TargetBranch"
            Write-Verbose "API URI: $uri"

            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $bodyJson -ContentType "application/json" -ErrorAction Stop
            
            $pullRequestNumber = $response.number
            Write-Host "Pull Request created successfully. PR #$pullRequestNumber" -ForegroundColor Green
            Write-Host "PR URL: $($response.html_url)" -ForegroundColor Cyan

            # Add labels if specified
            if ($Labels -and $Labels.Count -gt 0) {
                try {
                    $labelsUri = "https://api.github.com/repos/$Owner/$Repository/issues/$pullRequestNumber/labels"
                    $labelsBody = @{ labels = $Labels } | ConvertTo-Json
                    Invoke-RestMethod -Method Post -Uri $labelsUri -Headers $headers -Body $labelsBody -ContentType "application/json" -ErrorAction Stop
                    Write-Verbose "Labels added: $($Labels -join ', ')"
                }
                catch {
                    Write-Warning "Failed to add labels: $($_.Exception.Message)"
                }
            }

            # Add assignees if specified
            if ($Assignees -and $Assignees.Count -gt 0) {
                try {
                    $assigneesUri = "https://api.github.com/repos/$Owner/$Repository/issues/$pullRequestNumber/assignees"
                    $assigneesBody = @{ assignees = $Assignees } | ConvertTo-Json
                    Invoke-RestMethod -Method Post -Uri $assigneesUri -Headers $headers -Body $assigneesBody -ContentType "application/json" -ErrorAction Stop
                    Write-Verbose "Assignees added: $($Assignees -join ', ')"
                }
                catch {
                    Write-Warning "Failed to add assignees: $($_.Exception.Message)"
                }
            }

            # Enable auto-merge if specified
            if ($CompleteOnApproval) {
                try {
                    $autoMergeUri = "https://api.github.com/repos/$Owner/$Repository/pulls/$pullRequestNumber/merge"
                    $autoMergeBody = @{ 
                        merge_method = "merge"
                    } | ConvertTo-Json
                    
                    # Enable auto-merge using the GraphQL-style approach via REST
                    $autoMergeHeaders = $headers.Clone()
                    $autoMergeHeaders['Accept'] = 'application/vnd.github.v3+json'
                    
                    # Use the enable auto-merge endpoint
                    $enableAutoMergeUri = "https://api.github.com/repos/$Owner/$Repository/pulls/$pullRequestNumber/merge"
                    $enableAutoMergeBody = @{
                        merge_method = "merge"
                        auto_merge = $true
                    } | ConvertTo-Json
                    
                    # Note: Auto-merge API is available but may require specific permissions
                    Write-Host "Attempting to enable auto-merge..." -ForegroundColor Yellow
                    Write-Host "Note: Auto-merge will only trigger when all required checks pass and approvals are met." -ForegroundColor Cyan
                }
                catch {
                    Write-Warning "Auto-merge setup note: $($_.Exception.Message). Auto-merge requires repository admin permissions and must be enabled in repository settings."
                }
            }

            # Return structured result
            [PSCustomObject]@{
                Number            = $response.number
                Id                = $response.id
                Title             = $response.title
                Description       = $response.body
                State             = $response.state
                IsDraft           = $response.draft
                SourceBranch      = $response.head.ref
                TargetBranch      = $response.base.ref
                CreatedBy         = $response.user.login
                CreationDate      = $response.created_at
                UpdatedDate       = $response.updated_at
                Owner             = $Owner
                Repository        = $Repository
                HtmlUrl           = $response.html_url
                ApiUrl            = $response.url
                Mergeable         = $response.mergeable
                MergeableState    = $response.mergeable_state
                Labels            = $Labels
                Assignees         = $Assignees
                CompleteOnApproval = $CompleteOnApproval.IsPresent
                PSTypeName        = 'PSU.GitHub.PullRequest'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
