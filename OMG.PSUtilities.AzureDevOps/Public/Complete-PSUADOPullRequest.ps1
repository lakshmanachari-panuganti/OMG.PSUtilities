function Complete-PSUADOPullRequest {
    <#
    .SYNOPSIS
        Completes (merges) a pull request in Azure DevOps using REST API.

    .DESCRIPTION
        This function completes a pull request in Azure DevOps by its ID. It supports different merge strategies
        including merge, squash, and rebase. You can specify the repository details or use auto-detection from git remote.

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
        (Mandatory) The ID of the pull request to complete.

    .PARAMETER MergeStrategy
        (Optional) The merge strategy to use: 'merge', 'squash', or 'rebase'.
        Default value is 'merge'.

    .PARAMETER DeleteSourceBranch
        (Optional) Switch parameter to delete the source branch after completion.

    .PARAMETER CompletionOptions
        (Optional) Additional completion options as a hashtable.

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "value_of_PAT"

    .EXAMPLE
        Complete-PSUADOPullRequest -PullRequestId 123

        Completes pull request with ID 123 using auto-detected organization, project, and repository.

    .EXAMPLE
        Complete-PSUADOPullRequest -Organization "myorg" -Project "myproject" -Repository "myrepo" -PullRequestId 123 -MergeStrategy "squash"

        Completes pull request with ID 123 using squash merge strategy.

    .EXAMPLE
        Complete-PSUADOPullRequest -PullRequestId 123 -DeleteSourceBranch

        Completes pull request with ID 123 and deletes the source branch.

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
        https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-requests/update
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
        [ValidateSet('merge', 'squash', 'rebase', 'rebaseMerge')]
        [string]$MergeStrategy = 'merge',

        [Parameter()]
        [switch]$DeleteSourceBranch,

        [Parameter()]
        [hashtable]$CompletionOptions,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    process {
        try {
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

            # First, get the current PR details
            $getPrUri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$repositoryId/pullrequests/$PullRequestId" + "?api-version=7.0"
            Write-Verbose "Getting pull request details from: $getPrUri"
            
            $currentPr = Invoke-RestMethod -Method Get -Uri $getPrUri -Headers $headers -ErrorAction Stop

            # Prepare completion options
            $completionOptions = @{}
            
            if ($MergeStrategy -eq 'merge') {
                $completionOptions.mergeStrategy = 'noFastForward'
            } elseif ($MergeStrategy -eq 'squash') {
                $completionOptions.mergeStrategy = 'squash'
            } elseif ($MergeStrategy -eq 'rebase') {
                $completionOptions.mergeStrategy = 'rebase'
            } elseif ($MergeStrategy -eq 'rebaseMerge') {
                $completionOptions.mergeStrategy = 'rebaseMerge'
            }

            if ($DeleteSourceBranch) {
                $completionOptions.deleteSourceBranch = $true
            }

            # Add any additional completion options
            if ($CompletionOptions) {
                foreach ($key in $CompletionOptions.Keys) {
                    $completionOptions[$key] = $CompletionOptions[$key]
                }
            }

            # Prepare the update body
            $body = @{
                status = "completed"
                lastMergeSourceCommit = @{
                    commitId = $currentPr.lastMergeSourceCommit.commitId
                }
                completionOptions = $completionOptions
            } | ConvertTo-Json -Depth 10

            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            }
            else {
                [uri]::EscapeDataString($Project)
            }
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$repositoryId/pullrequests/$PullRequestId" + "?api-version=7.0"
            
            Write-Verbose "Completing pull request ID: $PullRequestId in project: $Project"
            Write-Verbose "Repository: $Repository ($repositoryId)"
            Write-Verbose "Merge strategy: $MergeStrategy"
            Write-Verbose "API URI: $uri"

            $response = Invoke-RestMethod -Method Patch -Uri $uri -Headers $headers -Body $body -ContentType "application/json" -ErrorAction Stop
            
            $WebUrl = "https://dev.azure.com/$Organization/$escapedProject/_git/$Repository/pullrequest/$PullRequestId"
            Write-Host "Pull Request ID $PullRequestId completed successfully!" -ForegroundColor Green
            Write-Host "PR URL: $WebUrl" -ForegroundColor Cyan
            Write-Host "Merge strategy: $MergeStrategy" -ForegroundColor Yellow

            if ($DeleteSourceBranch) {
                Write-Host "Source branch will be deleted." -ForegroundColor Green
            }

            # Return structured result
            [PSCustomObject]@{
                Id                    = $response.pullRequestId
                Status                = $response.status
                Title                 = $response.title
                MergeStrategy         = $MergeStrategy
                SourceBranch          = $response.sourceRefName
                TargetBranch          = $response.targetRefName
                CompletedBy           = $response.closedBy.displayName
                CompletionDate        = $response.closedDate
                MergeId               = $response.mergeId
                DeletedSourceBranch   = $DeleteSourceBranch.IsPresent
                Organization          = $Organization
                Project               = $Project
                Repository            = $Repository
                WebUrl                = $WebUrl
                PSTypeName            = 'PSU.ADO.PullRequestCompletion'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
