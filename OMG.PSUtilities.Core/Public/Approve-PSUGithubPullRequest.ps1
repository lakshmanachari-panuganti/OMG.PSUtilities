function Approve-PSUGithubPullRequest {
    <#
    .SYNOPSIS
        Approves a pull request in GitHub using REST API.

    .DESCRIPTION
        This function creates a review approval for a pull request in GitHub by its number. It supports
        different review states including approval, request changes, or comments only.

    .PARAMETER Owner
        (Optional) The GitHub repository owner (username or organization).
        Default value is auto-detected from git remote origin URL.

    .PARAMETER Repository
        (Optional) The GitHub repository name.
        Default value is auto-detected from git remote origin URL.

    .PARAMETER PullRequestNumber
        (Mandatory) The number/ID of the pull request to approve.

    .PARAMETER ReviewState
        (Optional) The review state to submit:
        - 'APPROVE': Approve the pull request
        - 'REQUEST_CHANGES': Request changes before approval
        - 'COMMENT': Comment without explicit approval
        Default value is 'APPROVE'.

    .PARAMETER Comment
        (Optional) Comment to add with the review.

    .PARAMETER Token
        (Optional) GitHub Personal Access Token for authentication.
        Default value is $env:GITHUB_TOKEN. Set using: Set-PSUUserEnvironmentVariable -Name "GITHUB_TOKEN" -Value "value_of_token"

    .EXAMPLE
        Approve-PSUGithubPullRequest -PullRequestNumber 42

        Approves pull request #42 using auto-detected repository.

    .EXAMPLE
        Approve-PSUGithubPullRequest -Owner "myuser" -Repository "myrepo" -PullRequestNumber 42 -Comment "LGTM! Great work."

        Approves pull request #42 with a comment.

    .EXAMPLE
        Approve-PSUGithubPullRequest -PullRequestNumber 42 -ReviewState "REQUEST_CHANGES" -Comment "Please fix the unit tests"

        Requests changes on pull request #42 with a comment.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 19th August 2025
        Requires: GitHub Personal Access Token with repo permissions

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
        https://docs.github.com/en/rest/pulls/reviews#create-a-review-for-a-pull-request
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

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]$PullRequestNumber,

        [Parameter()]
        [ValidateSet('APPROVE', 'REQUEST_CHANGES', 'COMMENT')]
        [string]$ReviewState = 'APPROVE',

        [Parameter()]
        [string]$Comment,

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

            # Get PR details first to validate it exists
            $prUri = "https://api.github.com/repos/$Owner/$Repository/pulls/$PullRequestNumber"
            Write-Verbose "Getting pull request details from: $prUri"
            
            $prDetails = Invoke-RestMethod -Method Get -Uri $prUri -Headers $headers -ErrorAction Stop

            # Prepare review body
            $body = @{
                event = $ReviewState
            }

            if ($Comment) {
                $body.body = $Comment
            }

            $bodyJson = $body | ConvertTo-Json -Depth 10

            # Submit the review
            $reviewUri = "https://api.github.com/repos/$Owner/$Repository/pulls/$PullRequestNumber/reviews"
            Write-Verbose "Submitting review for pull request #$PullRequestNumber in repository: $Owner/$Repository"
            Write-Verbose "Review state: $ReviewState"
            Write-Verbose "API URI: $reviewUri"

            $response = Invoke-RestMethod -Method Post -Uri $reviewUri -Headers $headers -Body $bodyJson -ContentType "application/json" -ErrorAction Stop
            
            # Determine action text for display
            $actionText = switch ($ReviewState) {
                'APPROVE' { 'approved' }
                'REQUEST_CHANGES' { 'requested changes for' }
                'COMMENT' { 'commented on' }
                default { 'reviewed' }
            }

            Write-Host "Successfully $actionText pull request #$PullRequestNumber" -ForegroundColor Green
            Write-Host "PR URL: $($prDetails.html_url)" -ForegroundColor Cyan
            Write-Host "Review URL: $($response.html_url)" -ForegroundColor Cyan

            if ($Comment) {
                Write-Host "Comment: $Comment" -ForegroundColor Yellow
            }

            # Return structured result
            [PSCustomObject]@{
                PullRequestNumber = $PullRequestNumber
                ReviewId         = $response.id
                ReviewState      = $response.state
                ActionText       = $actionText
                Comment          = $Comment
                ReviewerLogin    = $response.user.login
                SubmittedAt      = $response.submitted_at
                Owner            = $Owner
                Repository       = $Repository
                PullRequestUrl   = $prDetails.html_url
                ReviewUrl        = $response.html_url
                PSTypeName       = 'PSU.GitHub.PullRequestApproval'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
