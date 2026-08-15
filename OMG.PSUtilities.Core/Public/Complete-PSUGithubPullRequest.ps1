function Complete-PSUGithubPullRequest {
    <#
    .SYNOPSIS
        Completes (merges) a pull request in GitHub using REST API.

    .DESCRIPTION
        This function merges an open pull request in GitHub by its number and optionally deletes the
        source branch afterwards. It supports the merge, squash, and rebase strategies offered by the
        GitHub pull request merge API.

    .PARAMETER Owner
        (Optional) The GitHub repository owner (username or organization).
        Default value is auto-detected from git remote origin URL.

    .PARAMETER Repository
        (Optional) The GitHub repository name.
        Default value is auto-detected from git remote origin URL.

    .PARAMETER PullRequestNumber
        (Mandatory) The number/ID of the pull request to complete.

    .PARAMETER MergeMethod
        (Optional) The merge strategy to use:
        - 'merge': Create a merge commit
        - 'squash': Squash the commits into a single commit
        - 'rebase': Rebase the commits onto the base branch
        Default value is 'merge'.

    .PARAMETER CommitTitle
        (Optional) The title of the merge commit. GitHub generates one when omitted.

    .PARAMETER CommitMessage
        (Optional) The body of the merge commit. GitHub generates one when omitted.

    .PARAMETER DeleteBranch
        (Optional) Switch parameter to delete the source branch after a successful merge.

    .PARAMETER Token
        (Optional) GitHub Personal Access Token for authentication.
        Default value is $env:GITHUB_TOKEN. Set using: Set-PSUUserEnvironmentVariable -Name "GITHUB_TOKEN" -Value "value_of_token"

    .EXAMPLE
        Complete-PSUGithubPullRequest -PullRequestNumber 42

        Merges pull request #42 using auto-detected repository and a merge commit.

    .EXAMPLE
        Complete-PSUGithubPullRequest -PullRequestNumber 42 -MergeMethod "squash" -DeleteBranch

        Squash merges pull request #42 and deletes the source branch.

    .EXAMPLE
        Complete-PSUGithubPullRequest -Owner "myuser" -Repository "myrepo" -PullRequestNumber 42 -CommitTitle "Feature complete"

        Merges pull request #42 in an explicit repository with a custom merge commit title.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 6th August 2026
        Requires: GitHub Personal Access Token with repo permissions

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
        https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request
    #>
    [CmdletBinding(SupportsShouldProcess)]
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

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]$PullRequestNumber,

        [Parameter()]
        [ValidateSet('merge', 'squash', 'rebase')]
        [string]$MergeMethod = 'merge',

        [Parameter()]
        [string]$CommitTitle,

        [Parameter()]
        [string]$CommitMessage,

        [Parameter()]
        [switch]$DeleteBranch,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Token = $env:GITHUB_TOKEN
    )

    process {
        try {
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

            if (-not $Token) {
                throw "GitHub token not found. Set it using: Set-PSUUserEnvironmentVariable -Name 'GITHUB_TOKEN' -Value 'your-token'"
            }

            $headers = @{
                'Authorization'        = "Bearer $Token"
                'Accept'               = 'application/vnd.github.v3+json'
                'X-GitHub-Api-Version' = '2022-11-28'
            }

            $prUri = "https://api.github.com/repos/$Owner/$Repository/pulls/$PullRequestNumber"
            Write-Verbose "Getting pull request details from: $prUri"

            $prDetails = Invoke-RestMethod -Method Get -Uri $prUri -Headers $headers -ErrorAction Stop

            if ($prDetails.state -ne 'open') {
                throw "Pull request #$PullRequestNumber is '$($prDetails.state)' and cannot be completed."
            }

            $body = @{
                merge_method = $MergeMethod
            }

            if ($CommitTitle) {
                $body.commit_title = $CommitTitle
            }

            if ($CommitMessage) {
                $body.commit_message = $CommitMessage
            }

            $bodyJson = $body | ConvertTo-Json -Depth 10

            $mergeUri = "$prUri/merge"
            Write-Verbose "Completing pull request #$PullRequestNumber in repository: $Owner/$Repository"
            Write-Verbose "Merge method: $MergeMethod"
            Write-Verbose "API URI: $mergeUri"

            if (-not $PSCmdlet.ShouldProcess("$Owner/$Repository pull request #$PullRequestNumber", "Complete with $MergeMethod")) {
                return
            }

            $response = Invoke-RestMethod -Method Put -Uri $mergeUri -Headers $headers -Body $bodyJson -ContentType "application/json" -ErrorAction Stop

            Write-Host "Successfully completed pull request #$PullRequestNumber" -ForegroundColor Green
            Write-Host "PR URL: $($prDetails.html_url)" -ForegroundColor Cyan

            $sourceBranch = $prDetails.head.ref
            $branchDeleted = $false

            if ($DeleteBranch -and $response.merged) {
                $branchUri = "https://api.github.com/repos/$Owner/$Repository/git/refs/heads/$sourceBranch"
                Write-Verbose "Deleting source branch: $sourceBranch"

                try {
                    Invoke-RestMethod -Method Delete -Uri $branchUri -Headers $headers -ErrorAction Stop | Out-Null
                    $branchDeleted = $true
                    Write-Host "Deleted source branch: $sourceBranch" -ForegroundColor Green
                } catch {
                    Write-Warning "Merged pull request #$PullRequestNumber but could not delete branch '$sourceBranch': $($_.Exception.Message)"
                }
            }

            [PSCustomObject]@{
                PullRequestNumber = $PullRequestNumber
                Merged            = $response.merged
                MergeMethod       = $MergeMethod
                MergeCommitSha    = $response.sha
                Message           = $response.message
                SourceBranch      = $sourceBranch
                TargetBranch      = $prDetails.base.ref
                BranchDeleted     = $branchDeleted
                Owner             = $Owner
                Repository        = $Repository
                PullRequestUrl    = $prDetails.html_url
                PSTypeName        = 'PSU.GitHub.PullRequestCompletion'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}