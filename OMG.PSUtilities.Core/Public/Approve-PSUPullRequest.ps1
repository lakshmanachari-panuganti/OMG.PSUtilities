function Approve-PSUPullRequest {
    <#
    .SYNOPSIS
        Approves a pull request in GitHub or Azure DevOps automatically based on git remote.

    .DESCRIPTION
        This function automatically detects whether you're working with a GitHub or Azure DevOps repository
        and calls the appropriate approval function. It provides a unified interface for both platforms.

    .PARAMETER PullRequestId
        (Mandatory) The ID/number of the pull request to approve.

    .PARAMETER Comment
        (Optional) Comment to add with the approval.

    .PARAMETER ApprovalType
        (Optional) The type of approval:
        - 'Approve': Standard approval (default)
        - 'ApproveWithSuggestions': Approve but with minor suggestions (ADO only)
        - 'RequestChanges': Request changes before approval
        - 'CommentOnly': Add comment without explicit approval/rejection
        Default value is 'Approve'.

    .EXAMPLE
        Approve-PSUPullRequest -PullRequestId 42

        Approves pull request #42 using auto-detected platform.

    .EXAMPLE
        Approve-PSUPullRequest -PullRequestId 42 -Comment "LGTM! Great implementation."

        Approves pull request #42 with a comment using auto-detected platform.

    .EXAMPLE
        Approve-PSUPullRequest -PullRequestId 42 -ApprovalType "RequestChanges" -Comment "Please add unit tests"

        Requests changes on pull request #42 with a comment.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2025-08-19
        Requires: Appropriate tokens for GitHub (GITHUB_TOKEN) or Azure DevOps (PAT)

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]$PullRequestId,

        [Parameter()]
        [string]$Comment,

        [Parameter()]
        [ValidateSet('Approve', 'ApproveWithSuggestions', 'RequestChanges', 'CommentOnly')]
        [string]$ApprovalType = 'Approve'
    )

    process {
        try {
            # Detect git provider from remote URL
            $remoteUrl = git remote get-url origin 2>$null
            if (-not $remoteUrl) {
                throw "No git remote origin found. Please ensure you're in a git repository."
            }

            if ($remoteUrl -match 'github\.com') {
                Write-Verbose "Detected GitHub repository"
                
                # Map approval types to GitHub review states
                $reviewState = switch ($ApprovalType) {
                    'Approve' { 'APPROVE' }
                    'ApproveWithSuggestions' { 
                        Write-Warning "GitHub doesn't have 'Approve with Suggestions'. Using standard 'APPROVE'."
                        'APPROVE' 
                    }
                    'RequestChanges' { 'REQUEST_CHANGES' }
                    'CommentOnly' { 'COMMENT' }
                }

                $params = @{
                    PullRequestNumber = $PullRequestId
                    ReviewState = $reviewState
                }

                if ($Comment) {
                    $params.Comment = $Comment
                }

                Write-Host "Reviewing GitHub pull request #$PullRequestId..." -ForegroundColor Blue
                return Approve-PSUGithubPullRequest @params

            } elseif ($remoteUrl -match 'dev\.azure\.com|visualstudio\.com') {
                Write-Verbose "Detected Azure DevOps repository"

                # Map approval types to Azure DevOps vote values
                $vote = switch ($ApprovalType) {
                    'Approve' { 10 }
                    'ApproveWithSuggestions' { 5 }
                    'RequestChanges' { -5 }
                    'CommentOnly' { 0 }
                }

                $params = @{
                    PullRequestId = $PullRequestId
                    Vote = $vote
                }

                if ($Comment) {
                    $params.Comment = $Comment
                }

                Write-Host "Reviewing Azure DevOps pull request #$PullRequestId..." -ForegroundColor Blue
                return Approve-PSUADOPullRequest @params

            } else {
                throw "Unsupported git provider. This function supports GitHub and Azure DevOps repositories only. Remote URL: $remoteUrl"
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
