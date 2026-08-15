function Complete-PSUADOPullRequest {
    <#
    .SYNOPSIS
        Completes (merges) a pull request in Azure DevOps using REST API.

    .DESCRIPTION
        This function completes a pull request in Azure DevOps by its ID. It supports different merge strategies
        including merge, squash, and rebase. You can specify the repository details or use auto-detection from git remote.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing the repository.

    .PARAMETER Repository
        (Mandatory) The repository name containing the pull request.

    .PARAMETER PullRequestId
        (Mandatory) The ID of the pull request to complete.

    .PARAMETER MergeStrategy
        (Optional) The merge strategy to use: 'merge', 'squash', or 'rebase'.
        An explicitly supplied value overrides CompletionOptions.mergeStrategy.
        Defaults to 'merge' when neither input specifies a strategy.

    .PARAMETER DeleteSourceBranch
        (Optional) Switch parameter to delete the source branch after completion.

    .PARAMETER CompletionOptions
        (Optional) Additional completion options as a hashtable. Explicit MergeStrategy
        and DeleteSourceBranch parameters take precedence over matching hashtable keys.

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        Complete-PSUADOPullRequest -Organization "omg" -Project "psutilities" -Repository "AzureDevOps" -PullRequestId 123

        Completes pull request with ID 123 using default merge strategy.

    .EXAMPLE
        Complete-PSUADOPullRequest -Organization "omg" -Project "psutilities" -Repository "Ai" -PullRequestId 456 -MergeStrategy "squash"

        Completes pull request with ID 456 using squash merge strategy.

    .EXAMPLE
        Complete-PSUADOPullRequest -Organization "omg" -Project "psutilities" -Repository "Core" -PullRequestId 789 -DeleteSourceBranch

        Completes pull request with ID 789 and deletes the source branch.

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
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Repository,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
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
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    begin {
        Write-PSUAdoParameterTrace -Invocation $MyInvocation -BoundParameters $PSBoundParameters
        Confirm-PSUAdoConnectionParameter -Organization $Organization -PAT $PAT

        $headers = Get-PSUAdoAuthHeader -PAT $PAT
    }

    process {
        try {
            # Escape project name for URI
            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            } else {
                [uri]::EscapeDataString($Project)
            }
            
            # Get repository ID
            $repos = Get-PSUADORepositories -Project $Project -Organization $Organization -PAT $PAT
            $matchedRepo = $repos | Where-Object { $_.Name -eq $Repository }
            if (-not $matchedRepo) {
                throw "Repository '$Repository' not found in project '$Project'."
            }
            $repositoryId = $matchedRepo.Id

            # First, get the current PR details
            $getPrUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$repositoryId/pullrequests/$PullRequestId" + "?api-version=7.0"
            Write-Verbose "Getting pull request details from: $getPrUri"

            $currentPr = Invoke-RestMethod -Method Get -Uri $getPrUri -Headers $headers -ErrorAction Stop

            $mergeOptions = [ordered]@{}
            if ($CompletionOptions) {
                foreach ($entry in @($CompletionOptions.GetEnumerator())) {
                    $mergeOptions[$entry.Key] = $entry.Value
                }
            }

            if ($PSBoundParameters.ContainsKey('MergeStrategy') -or -not $mergeOptions.Contains('mergeStrategy')) {
                $mergeOptions.mergeStrategy = switch ($MergeStrategy) {
                    'merge' { 'noFastForward' }
                    'squash' { 'squash' }
                    'rebase' { 'rebase' }
                    'rebaseMerge' { 'rebaseMerge' }
                }
            }

            if ($PSBoundParameters.ContainsKey('DeleteSourceBranch')) {
                $mergeOptions.deleteSourceBranch = $DeleteSourceBranch.IsPresent
            }

            $deleteSourceBranchRequested = [bool]$mergeOptions.deleteSourceBranch

            # Determine source commit id; fall back defensively if property missing
            $sourceCommitId = $null
            if ($currentPr.PSObject.Properties.Name -contains 'lastMergeSourceCommit' -and $currentPr.lastMergeSourceCommit.commitId) {
                $sourceCommitId = $currentPr.lastMergeSourceCommit.commitId
            } elseif ($currentPr.PSObject.Properties.Name -contains 'lastMergeCommit' -and $currentPr.lastMergeCommit.commitId) {
                $sourceCommitId = $currentPr.lastMergeCommit.commitId
            } else {
                Write-Verbose "Source commit id not found on PR object; proceeding without lastMergeSourceCommit optimistic concurrency check."            
            }

            $bodyObject = [ordered]@{
                status = 'completed'
                completionOptions = $mergeOptions
            }
            if ($sourceCommitId) {
                $bodyObject.lastMergeSourceCommit = @{ commitId = $sourceCommitId }
            }
            $body = $bodyObject | ConvertTo-Json -Depth 10
            Write-Verbose "Completion payload: $body"

            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$repositoryId/pullrequests/$PullRequestId" + "?api-version=7.0"

            Write-Verbose "Completing pull request ID: $PullRequestId in project: $Project"
            Write-Verbose "Repository: $Repository ($repositoryId)"
            Write-Verbose "Merge strategy: $MergeStrategy"
            Write-Verbose "API URI: $uri"

            try {
                $response = Invoke-RestMethod -Method Patch -Uri $uri -Headers $headers -Body $body -ContentType "application/json" -ErrorAction Stop
            } catch {
                Write-Verbose "Raw failure body (if any) following completion attempt."            
                if ($_.Exception.Response) {
                    try {
                        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                        $raw = $reader.ReadToEnd()
                        Write-Verbose $raw
                    } catch {}
                }
                throw
            }

            $WebUrl = "https://dev.azure.com/$Organization/$escapedProject/_git/$Repository/pullrequest/$PullRequestId"
            Write-Host "Pull Request ID $PullRequestId completed successfully!" -ForegroundColor Green
            Write-Host "PR URL: $WebUrl" -ForegroundColor Cyan
            Write-Host "Merge strategy: $MergeStrategy" -ForegroundColor Yellow

            if ($deleteSourceBranchRequested) {
                Write-Host "Source branch will be deleted." -ForegroundColor Green
            }

            # Return structured result
            [PSCustomObject]@{
                Id                  = $response.pullRequestId
                Status              = $response.status
                Title               = $response.title
                MergeStrategy       = $MergeStrategy
                SourceBranch        = $response.sourceRefName
                TargetBranch        = $response.targetRefName
                CompletedBy         = $response.closedBy.displayName
                CompletionDate      = $response.closedDate
                MergeId             = $response.mergeId
                DeletedSourceBranch = $deleteSourceBranchRequested
                Organization        = $Organization
                Project             = $Project
                Repository          = $Repository
                WebUrl              = $WebUrl
                PSTypeName          = 'PSU.ADO.PullRequestCompletion'
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
