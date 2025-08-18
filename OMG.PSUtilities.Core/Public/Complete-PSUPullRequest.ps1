function Complete-PSUPullRequest {
    <#
    .SYNOPSIS
        Completes (merges) a pull request in GitHub or Azure DevOps automatically based on git remote.

    .DESCRIPTION
        This function automatically detects whether you're working with a GitHub or Azure DevOps repository
        and calls the appropriate completion function. It supports all the common merge strategies for both platforms.

    .PARAMETER PullRequestId
        (Mandatory) The ID/number of the pull request to complete.

    .PARAMETER MergeStrategy
        (Optional) The merge strategy to use. Valid values depend on the platform:
        - GitHub: 'merge', 'squash', 'rebase'
        - Azure DevOps: 'merge', 'squash', 'rebase', 'rebaseMerge'
        Default value is 'merge'.

    .PARAMETER DeleteSourceBranch
        (Optional) Switch parameter to delete the source branch after completion.

    .PARAMETER CommitTitle
        (Optional) The title for the merge commit (GitHub only).

    .PARAMETER CommitMessage
        (Optional) The message for the merge commit (GitHub only).

    .EXAMPLE
        Complete-PSUPullRequest -PullRequestId 42

        Completes pull request #42 using auto-detected platform and default merge strategy.

    .EXAMPLE
        Complete-PSUPullRequest -PullRequestId 42 -MergeStrategy "squash" -DeleteSourceBranch

        Completes pull request #42 using squash merge and deletes the source branch.

    .EXAMPLE
        Complete-PSUPullRequest -PullRequestId 42 -CommitTitle "Feature complete" -CommitMessage "Implemented feature X"

        Completes pull request #42 with custom commit message (GitHub only).

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
        [ValidateSet('merge', 'squash', 'rebase', 'rebaseMerge')]
        [string]$MergeStrategy = 'merge',

        [Parameter()]
        [switch]$DeleteSourceBranch,

        [Parameter()]
        [string]$CommitTitle,

        [Parameter()]
        [string]$CommitMessage
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
                
                # Validate merge strategy for GitHub
                if ($MergeStrategy -eq 'rebaseMerge') {
                    Write-Warning "GitHub doesn't support 'rebaseMerge' strategy. Using 'rebase' instead."
                    $MergeStrategy = 'rebase'
                }

                $params = @{
                    PullRequestNumber = $PullRequestId
                    MergeMethod = $MergeStrategy
                }

                if ($DeleteSourceBranch) {
                    $params.DeleteBranch = $true
                }

                if ($CommitTitle) {
                    $params.CommitTitle = $CommitTitle
                }

                if ($CommitMessage) {
                    $params.CommitMessage = $CommitMessage
                }

                Write-Host "Completing GitHub pull request #$PullRequestId..." -ForegroundColor Blue
                return Complete-PSUGithubPullRequest @params

            } elseif ($remoteUrl -match 'dev\.azure\.com|visualstudio\.com') {
                Write-Verbose "Detected Azure DevOps repository"

                if ($CommitTitle -or $CommitMessage) {
                    Write-Warning "Custom commit title/message not supported for Azure DevOps pull requests."
                }

                $params = @{
                    PullRequestId = $PullRequestId
                    MergeStrategy = $MergeStrategy
                }

                if ($DeleteSourceBranch) {
                    $params.DeleteSourceBranch = $true
                }

                Write-Host "Completing Azure DevOps pull request #$PullRequestId..." -ForegroundColor Blue
                return Complete-PSUADOPullRequest @params

            } else {
                throw "Unsupported git provider. This function supports GitHub and Azure DevOps repositories only. Remote URL: $remoteUrl"
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
