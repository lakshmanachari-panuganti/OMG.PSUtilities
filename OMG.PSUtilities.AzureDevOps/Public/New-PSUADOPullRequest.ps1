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
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing the repository.

    .PARAMETER RepoId
        (Mandatory - ParameterSet: ByRepoId) The repository GUID in which to create the pull request.

    .PARAMETER RepositoryName
        (Mandatory - ParameterSet: ByRepoName) The repository name in which to create the pull request.

    .PARAMETER SourceBranch
        (Optional) The full name of the source branch (e.g., 'feature/enhance-ui', 'bugfix/login-issue', 'hotfix/urgent-fix', 'develop').

    .PARAMETER TargetBranch
        (Optional) The full name of the target branch (e.g., 'main' or 'release/main', or 'master', or 'release/master')..

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
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        $params = @{
            Organization = "omg"
            Project      = "psutilities"
            RepoId       = "12345678-1234-1234-1234-123456789012"
            SourceBranch = "feature-x"
            TargetBranch = "main"
            Title        = "Feature X Implementation"
            Description  = "This PR adds feature X."
        }
        New-PSUADOPullRequest @params

        Creates a pull request using repository ID.

    .EXAMPLE
        $params = @{
            Organization   = "omg"
            Project        = "psutilities"
            RepositoryName = "AzureDevOps"
            SourceBranch   = "feature-branch"
            TargetBranch   = "main"
            Title          = "Bug fix for login"
            Description    = "Fixed authentication issue"
        }
        New-PSUADOPullRequest @params

        Creates a pull request using repository name with specific branches.

    .EXAMPLE
        $params = @{
            Organization   = "omg"
            Project        = "psutilities"
            RepositoryName = "Ai"
            Title          = "Bug fix for login"
            Description    = "Fixed authentication issue"
            Draft          = $true
        }
        New-PSUADOPullRequest @params

        Creates a draft pull request using repository name with git-detected source/target branches.

    .EXAMPLE
        $params = @{
            Organization       = "omg"
            Project            = "psutilities"
            RepositoryName     = "Core"
            Title              = "Auto-complete feature"
            Description        = "This will auto-complete when approved"
            CompleteOnApproval = $true
        }
        New-PSUADOPullRequest @params

        Creates a pull request that will automatically complete when all approvals and policies are satisfied.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2025-07-30
        Updated: 2025-08-14 - Added RepositoryName parameter and parameter sets

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
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter()]
        [Parameter(Mandatory)]
        [string]$SourceBranch,

        [Parameter(Mandatory)]
        [string]$TargetBranch,

        [Parameter(Mandatory, ParameterSetName = 'ByRepoId')]
        [ValidateNotNullOrEmpty()]
        [string]$RepoId,

        [Parameter(Mandatory, ParameterSetName = 'ByRepoName')]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [switch]$Draft,

        [Parameter()]
        [switch]$CompleteOnApproval,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )


    begin {
        # Display parameters
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Parameters:"
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            if ($param.Key -eq 'PAT') {
                $maskedPAT = if ($param.Value -and $param.Value.Length -ge 3) { $param.Value.Substring(0, 3) + "********" } else { "***" }
                Write-Verbose "  $($param.Key): $maskedPAT"
            } else {
                Write-Verbose "  $($param.Key): $($param.Value)"
            }
        }

        # Validate Organization (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
        if (-not $Organization) {
            throw "The default value for the 'ORGANIZATION' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>' or provide via -Organization parameter."
        }

        # Validate PAT (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
        if (-not $PAT) {
            throw "The default value for the 'PAT' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<pat>' or provide via -PAT parameter."
        }

        $headers = Get-PSUAdoAuthHeader -PAT $PAT
    }
    process {
        try {
            # Validate required parameters that have auto-detection
            $repositoryIdentifier = $null
            if ($PSCmdlet.ParameterSetName -eq 'ByRepoId') {
                $repositoryIdentifier = $RepoId
            } else {
                $repos = Get-PSUADORepositories -Project $Project -Organization $Organization -PAT $PAT
                $matchedRepo = $repos | Where-Object { $_.Name -eq $RepositoryName }
                if (-not $matchedRepo) {
                    throw "Repository '$RepositoryName' not found in project '$Project'."
                }
                $repositoryIdentifier = $matchedRepo.Id
            }
            # Get available git branches as an array
            $availableBranches = $(git branch --list | ForEach-Object { $_.Trim().TrimStart('*').Trim() }) | Sort-Object { $_.Length }

            # Validating source/target branches and standardizing to 'refs/heads/branch-name' format
            if ($SourceBranch -in $availableBranches) {
                $SourceBranch = 'refs/heads/' + $SourceBranch
            } else {
                throw "SourceBranch must be in the available branches:`n$($availableBranches -join "`n")"
            }
            if ($TargetBranch -in $availableBranches) {
                $TargetBranch = 'refs/heads/' + $TargetBranch
            } else {
                throw "TargetBranch must be in the available branches:`n$($availableBranches -join "`n")"
            }
            
            Write-Host "Creating Pull Request:" -ForegroundColor Cyan
            Write-Host "  SourceBranch: $SourceBranch"
            Write-Host "  TargetBranch: $TargetBranch"
            Write-Host "  Repository: $repositoryIdentifier"
            Write-Host "  Title: $Title"
            Write-Host "  Description: $Description"

            $body = @{
                sourceRefName = $SourceBranch
                targetRefName = $TargetBranch
                title         = $Title
                description   = ($Description -join "`n")
                isDraft       = $Draft.IsPresent
            } | ConvertTo-Json -Depth 10

            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            } else {
                [uri]::EscapeDataString($Project)
            }
            
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$repositoryIdentifier/pullrequests?api-version=7.0"

            $irmParams = @{
                Method      = 'Post'
                Uri         = $uri
                Headers     = $headers
                Body        = $body
                ContentType = 'application/json'
                ErrorAction = 'Stop'
            }
            
            # Create safe version for verbose output (mask Authorization header)
            $verboseParams = $irmParams.Clone()
            if ($verboseParams.Headers -and $verboseParams.Headers['Authorization']) {
                $verboseParams.Headers = $verboseParams.Headers.Clone()
                $verboseParams.Headers['Authorization'] = 'Basic ***MASKED***'
                $verboseParams.Body = $verboseParams.Body | ConvertFrom-Json -Depth 10
            }
            Write-Verbose  "Invoke-RestMethod parameters for Pull Request creation: $($verboseParams | Out-String)"
            
            $response = Invoke-RestMethod @irmParams -Verbose:$false
            $WebUrl = "https://dev.azure.com/$Organization/$escapedProject/_git/$repositoryIdentifier/pullrequest/$($response.pullRequestId)"
            $draftText = if ($response.isDraft) { "Draft " } else { "" }
            Write-Verbose "  ${draftText}Pull Request created successfully. PR ID: $($response.pullRequestId)"
            Write-Verbose "  PR URL: $WebUrl"

            # Enable auto-completion if specified
            if ($CompleteOnApproval) {
                try {
                    # Set auto-complete options
                    $autoCompleteBody = @{
                        autoCompleteSetBy = @{
                            id = $response.createdBy.id
                        }
                        completionOptions = @{
                            mergeStrategy      = "noFastForward"
                            deleteSourceBranch = $false
                            squashMerge        = $false
                        }
                    } | ConvertTo-Json -Depth 10

                    $autoCompleteUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$repositoryIdentifier/pullrequests/$($response.pullRequestId)?api-version=7.0"
                    Write-Verbose "  Setting auto-completion for PR ID: $($response.pullRequestId)"

                    # Use parameter splatting for auto-complete PATCH call
                    $autoIRMParams = @{
                        Method      = 'Patch'
                        Uri         = $autoCompleteUri
                        Headers     = $headers
                        Body        = $autoCompleteBody
                        ContentType = 'application/json'
                        ErrorAction = 'Stop'
                    }

                    # Create safe version for verbose output (mask Authorization header)
                    $verboseAutoIRMParams = $autoIRMParams.Clone()
                    if ($verboseAutoIRMParams.Headers -and $verboseAutoIRMParams.Headers['Authorization']) {
                        $verboseAutoIRMParams.Headers = $verboseAutoIRMParams.Headers.Clone()
                        $verboseAutoIRMParams.Headers['Authorization'] = 'Basic ***MASKED***'
                        $verboseAutoIRMParams.Body = $verboseAutoIRMParams.Body | ConvertFrom-Json -Depth 10
                    }
                    Write-Verbose "  Invoke-RestMethod parameters for set auto-complete: $($verboseAutoIRMParams | Out-String)"

                    $response = Invoke-RestMethod @autoIRMParams -Verbose:$false
                    if($response.completionOptions.mergeStrategy -eq "noFastForward") {
                        Write-Verbose "  Auto-completion options set: MergeStrategy=$($response.completionOptions.mergeStrategy), DeleteSourceBranch=$($response.completionOptions.deleteSourceBranch), SquashMerge=$($response.completionOptions.squashMerge)"
                    }
                } catch {
                    Write-Warning "Failed to enable auto-completion: $($_.Exception.Message)"
                }
            }

            [PSCustomObject]@{
                Id                 = $response.pullRequestId
                Title              = $response.title
                Description        = $response.description
                Status             = $response.status
                IsDraft            = $response.isDraft
                SourceBranch       = $response.sourceRefName
                TargetBranch       = $response.targetRefName
                CreatedBy          = $response.createdBy.displayName
                CreatorEmail       = $response.createdBy.uniqueName
                CreationDate       = $response.creationDate
                RepositoryId       = $response.repository.id
                RepositoryName     = $response.repository.name
                ProjectName        = $response.repository.project.name
                WebUrl             = $WebUrl
                ApiUrl             = $response.url
                CompleteOnApproval = $CompleteOnApproval.IsPresent
                PSTypeName         = 'PSU.ADO.PullRequest'
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
