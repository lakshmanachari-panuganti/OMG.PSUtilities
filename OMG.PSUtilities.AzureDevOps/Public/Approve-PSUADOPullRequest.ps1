function Approve-PSUADOPullRequest {
    <#
    .SYNOPSIS
        Approves a pull request in Azure DevOps using REST API.

    .DESCRIPTION
        This function approves a pull request in Azure DevOps by its ID. It can approve with different vote values
        and optional comments. You can specify the repository details or use auto-detection from git remote.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is auto-detected from git remote origin URL or $env:ORGANIZATION.

    .PARAMETER Project
        (Optional) The Azure DevOps project name containing the repository.
        Default value is auto-detected from git remote origin URL.

    .PARAMETER Repository
        (Optional) The repository name containing the pull request.
        Default value is auto-detected from git remote origin URL.

    .PARAMETER PullRequestId
        (Mandatory) The ID of the pull request to approve.

    .PARAMETER Vote
        (Optional) The approval vote value:
        - 10: Approved
        - 5: Approved with suggestions
        - 0: No vote
        - -5: Waiting for author
        - -10: Rejected
        Default value is 10 (Approved).

    .PARAMETER Comment
        (Optional) Comment to add with the approval.

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "value_of_PAT"

    .EXAMPLE
        Approve-PSUADOPullRequest -PullRequestId 123

        Approves pull request with ID 123 using auto-detected organization, project, and repository.

    .EXAMPLE
        Approve-PSUADOPullRequest -Organization "myorg" -Project "myproject" -Repository "myrepo" -PullRequestId 123 -Vote 5 -Comment "Looks good with minor suggestions"

        Approves pull request with ID 123 with suggestions and a comment.

    .EXAMPLE
        Approve-PSUADOPullRequest -PullRequestId 123 -Vote -5 -Comment "Please address the unit test failures"

        Sets pull request to "Waiting for author" status with a comment.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 19th August 2025
        Requires: Azure DevOps Personal Access Token with appropriate permissions

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-request-reviewers/create-pull-request-reviewer
    #>
    [CmdletBinding()]
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

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Repository = $(git remote get-url origin 2>$null | ForEach-Object {
            if ($_ -match '/_git/([^/]+?)(?:\.git)?/?$') { $matches[1] }
        }),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]$PullRequestId,

        [Parameter()]
        [ValidateSet(10, 5, 0, -5, -10)]
        [int]$Vote = 10,

        [Parameter()]
        [string]$Comment,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    process {
        try {
            # Display parameters
            Write-Host "Parameters:" -ForegroundColor Cyan
            foreach ($param in $PSBoundParameters.GetEnumerator()) {
                if ($param.Key -eq 'PAT') {
                    $maskedPAT = if ($param.Value -and $param.Value.Length -ge 3) { $param.Value.Substring(0, 3) + "********" } else { "***" }
                    Write-Host "  $($param.Key): $maskedPAT" -ForegroundColor Cyan
                } else {
                    $displayValue = $param.Value.ToString()
                    if ($displayValue.Length -gt 30) {
                        $displayValue = $displayValue.Substring(0, 27) + "..."
                    }
                    Write-Host "  $($param.Key): $displayValue" -ForegroundColor Cyan
                }
            }
            Write-Host ""

            # Validate required parameters that have auto-detection
            if (-not $Organization) {
                throw "Organization parameter is required. Set it using: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value 'your-org' or ensure you're in a git repository with Azure DevOps remote."
            }
            
            if (-not $Project) {
                throw "Project parameter is required. Either specify it explicitly or ensure you're in a git repository with Azure DevOps remote URL."
            }
            
            if (-not $Repository) {
                throw "Repository parameter is required. Either specify it explicitly or ensure you're in a git repository with Azure DevOps remote URL."
            }

            # Get repository ID
            $repos = Get-PSUADORepositories -Project $Project -Organization $Organization -PAT $PAT
            $matchedRepo = $repos | Where-Object { $_.Name -eq $Repository }
            if (-not $matchedRepo) {
                throw "Repository '$Repository' not found in project '$Project'."
            }
            $repositoryId = $matchedRepo.Id

            # Compose authentication header
            $headers = Get-PSUAdoAuthHeader -PAT $PAT

            # Get current user information for the reviewer
            $userUri = "https://dev.azure.com/$Organization/_apis/profile/profiles/me?api-version=7.0"
            $userProfile = Invoke-RestMethod -Method Get -Uri $userUri -Headers $headers -ErrorAction Stop

            # Prepare the reviewer body
            $body = @{
                vote = $Vote
            }

            if ($Comment) {
                $body.comment = $Comment
            }

            $bodyJson = $body | ConvertTo-Json -Depth 10

            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            }
            else {
                [uri]::EscapeDataString($Project)
            }
            $reviewerId = $userProfile.id
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$repositoryId/pullrequests/$PullRequestId/reviewers/$reviewerId" + "?api-version=7.0"
            
            # Determine vote text for display
            $voteText = switch ($Vote) {
                10 { "Approved" }
                5 { "Approved with suggestions" }
                0 { "No vote" }
                -5 { "Waiting for author" }
                -10 { "Rejected" }
                default { "Vote: $Vote" }
            }

            Write-Verbose "Setting approval for pull request ID: $PullRequestId in project: $Project"
            Write-Verbose "Repository: $Repository ($repositoryId)"
            Write-Verbose "Vote: $Vote ($voteText)"
            Write-Verbose "API URI: $uri"

            $response = Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $bodyJson -ContentType "application/json" -ErrorAction Stop
            
            $WebUrl = "https://dev.azure.com/$Organization/$escapedProject/_git/$Repository/pullrequest/$PullRequestId"
            Write-Host "Pull Request ID $PullRequestId review submitted: $voteText" -ForegroundColor Green
            Write-Host "PR URL: $WebUrl" -ForegroundColor Cyan

            if ($Comment) {
                Write-Host "Comment: $Comment" -ForegroundColor Yellow
            }

            # Return structured result
            [PSCustomObject]@{
                Id              = $PullRequestId
                Vote            = $response.vote
                VoteText        = $voteText
                Comment         = $Comment
                ReviewerId      = $response.id
                ReviewerName    = $response.displayName
                ReviewerEmail   = $response.uniqueName
                IsRequired      = $response.isRequired
                Organization    = $Organization
                Project         = $Project
                Repository      = $Repository
                WebUrl          = $WebUrl
                PSTypeName      = 'PSU.ADO.PullRequestApproval'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
