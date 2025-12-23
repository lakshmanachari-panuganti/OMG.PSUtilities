function New-PSUAiPoweredPullRequest {
    <#
    .SYNOPSIS
        Uses AI assistance to generate a professional Pull Request (PR) title and description from Git change summaries.

    .DESCRIPTION
        This function takes Git change summaries and uses Invoke-PSUAiPrompt to produce
        a meaningful PR title and description written from a developer or DevOps perspective.

    .PARAMETER BaseBranch
        (Optional) The base branch to compare against.
        Default value is the default branch from git symbolic-ref refs/remotes/origin/HEAD.

    .PARAMETER FeatureBranch
        (Optional) The feature branch being merged.
        Default value is the current git branch from git branch --show-current.

    .PARAMETER PullRequestTemplate
        (Optional) Path to the Pull Request template file.
        Default value is "C:\Temp\PRTemplate.txt".

    .PARAMETER CompleteOnApproval
        (Optional) Switch parameter to enable auto-completion when the pull request is approved.
        This will be passed to the underlying PR creation function.

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .OUTPUTS
        [PSCustomObject]

    .EXAMPLE
        New-PSUAiPoweredPullRequest

    .EXAMPLE
        New-PSUAiPoweredPullRequest -CompleteOnApproval

        Generates an AI-powered pull request that will automatically complete when approved.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 28th July 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AI
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AI
        https://ai.google.dev/gemini-api/docs

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
        [string]$BaseBranch = $((git symbolic-ref refs/remotes/origin/HEAD) -replace '^refs/remotes/origin/', ''),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$FeatureBranch = $(git branch --show-current),

        [Parameter()]
        [ValidateScript({
                if ($_ -and -not (Test-Path $_)) {
                    throw "PR template file not found: $_"
                }
                return $true
            })]
        [string]$PullRequestTemplatePath,

        [Parameter()]
        [switch]$CompleteOnApproval,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    # Parameter display
    Write-Host "FeatureBranch: $FeatureBranch" -ForegroundColor Cyan
    Write-Host "BaseBranch: $BaseBranch" -ForegroundColor Cyan
    Write-Host "PullRequestTemplatePath: $PullRequestTemplatePath" -ForegroundColor Cyan
    Write-Host "CompleteOnApproval: $CompleteOnApproval" -ForegroundColor Cyan

    $currentLocation = Get-Location
    # Auto-detect git repository root
    $gitRootOutput = git rev-parse --show-toplevel 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Not in a git repository. Please run this command from within a git repository." -ForegroundColor Red
        return
    }

    # Convert Unix paths to Windows format
    $RootPath = $gitRootOutput -replace '/', '\'
    Write-Verbose "Git repository root: $RootPath"

    Set-Location $RootPath
    $UpdateChangeLog = Read-Host "Do you want me to update ChangeLog.md file with the changes? (Y/N)"
    if ($UpdateChangeLog -eq 'Y') {
        Update-PSUChangeLog
        Invoke-PSUGitCommit
        Start-Sleep -Seconds 3
    }
    $ChangeSummary = Get-PSUAiPoweredGitChangeSummary
    if (-not $ChangeSummary) {
        Write-Warning "No changes found."
        return
    }

    # Convert summaries into a nice prompt for AI
    $formattedChanges = ($ChangeSummary | ForEach-Object {
        "- File: $($_.File) | Change: $($_.TypeOfChange) | Summary: $($_.Summary)"
    }) -join "`n"

    # Handle PR template content
    $PRTemplateContent = ""
    $PRTemplateStatement = @()
    if ($PullRequestTemplatePath -and (Test-Path $PullRequestTemplatePath)) {
        try {
            $PRTemplateContent = Get-Content -Path $PullRequestTemplatePath -ErrorAction Stop | Out-String
            $PRTemplateStatement = @(
                "NOTE: Please follow the Pull Request template guidelines below carefully:",
                "",
                $PRTemplateContent,
                "",
                "DO NOT modify the template structure.",
                "DO NOT change the checklists or their wording.",
                "Update the checklists by marking the correct [X] where applicable.",
                "DO NOT alter anything that impacts organizational standards.",
                "ONLY update the DESCRIPTION section thoughtfully and clearly."
            )
        } catch {
            Write-Warning "Could not read PR template file: $($_.Exception.Message)"
        }
    } else{
            Write-Verbose "No PR template specified. Proceeding without template."
    }

    # Construct AI prompt
    $prompt = @"
You are a professional software engineer and DevOps expert.
Given the following Git change summaries, generate a concise and professional Pull Request title and a detailed description suitable for code review. The description should be written in a clear human tone, helpful to both developers and reviewers.

### Git Change Summaries:
$formattedChanges

Remove any repetition or duplicated information in the description.

The ONLY valid response format is a single JSON object exactly like this:

{
  "title": "<Meaningfull title, that matches the changes>",
  "description": "This pull request introduces the following improvements:\n\n**FileName1 | Updated/New/Deleted**  \n*Short description of what changed in this file*\n\n**FileName2 | Updated/New/Deleted**  \n*Short description of what changed in this file*\n\n**FileName3 | Updated/New/Deleted**  \n*Short description of what changed in this file*\n\n### **Additional Information**\n\n- ** Small Heading (Example Feature/Change 1):** Detailed description of the improvement or change\n- **Small Heading (Example Feature/Change 2):** Detailed description of the improvement or change\n- **Small Heading (Example Feature/Change 3):** Detailed description of the improvement or change\n- **Small Heading (Example Feature/Change 4):** Detailed description of the improvement or change"
}

Do not wrap the JSON in markdown or code fences. The response must:
- Start with "{"
- End with "}"
- Contain no text before "{" or after "}"
- Do NOT include phrases like "Here is your response" or "JSON output"
- (Except in inside PR Description)Do NOT include markdown formatting, code fencing, bullet points, or commentary

$($PRTemplateStatement -join "`n")

If any rule is violated, regenerate the response until it strictly matches the required JSON format.
"@.Trim()

    # Call AI Assistant with prompt!
    $response = Invoke-PSUAiPrompt -Prompt $prompt -ReturnJsonResponse

    try {
        $parsed = $response | ConvertFrom-Json -ErrorAction Stop

        if (-not $parsed.title -or -not $parsed.description) {
            throw "AI response missing required keys: title and/or description"
        }

        $PRContent = [PSCustomObject]@{
            Title       = $parsed.title
            Description = $parsed.description
        }

        # Copy title + description to clipboard
        "$($parsed.title)`n$($parsed.description)" | Set-Clipboard

        # Generate HTML summary (optional)
        Convert-PSUPullRequestSummaryToHtml -Title $parsed.title -Description $parsed.description -OpenInBrowser

        # Prompt user for action
        do {
            Write-Host 'Choose an option:' -ForegroundColor Yellow
            Write-Host '  Y - Submit the pull request now' -ForegroundColor Cyan
            Write-Host '  N - Cancel and exit' -ForegroundColor Cyan
            Write-Host '  R - Regenerate with new AI content' -ForegroundColor Cyan
            Write-Host '  D - Draft the PR' -ForegroundColor Cyan
            $readHost = Read-Host 'Enter your choice (Y/N/R/D)' -ForegroundColor Yellow
        } while ($readHost -notin 'Y','N','R','D')

        switch ($readHost) {
            'Y' {
                $remoteUrl = (git remote get-url origin).Trim()
                if ($remoteUrl -match 'github\.com') {
                    Write-Host "Creating GitHub pull request..."
                    $params = @{
                        Title       = $PRContent.Title
                        Description = $PRContent.Description
                        Token       = $env:GITHUB_TOKEN
                    }
                    if ($CompleteOnApproval) { $params.CompleteOnApproval = $true }
                    New-PSUGithubPullRequest @params
                } elseif ($remoteUrl -match 'dev\.azure\.com|visualstudio\.com') {
                    Write-Host "Creating Azure DevOps pull request..."
                    $remoteUrl = (git remote get-url origin).Trim()

                    if ($remoteUrl -match '^.+dev\.azure\.com[/:]([^/]+)/([^/]+)/_git/.+$') {
                        $Organization = $matches[1]
                        $projectNameEncoded = $matches[2]
                    } else {
                        throw "Cannot parse project name from $remoteUrl"
                    }
                    $params = @{
                        Title       = $PRContent.Title
                        Description = $PRContent.Description
                        RepositoryName = (git rev-parse --show-toplevel | Split-Path -Leaf)
                        Project        = [uri]::UnescapeDataString($projectNameEncoded)
                        Organization   = $Organization
                        PAT            = $PAT
                    }
                    if ($CompleteOnApproval) { $params.CompleteOnApproval = $true }
                    New-PSUADOPullRequest @params
                } else {
                    Write-Warning "git url: $remoteUrl"
                    Write-Warning "Automatic pull request creation is not supported for this Git provider. Please create the PR manually."
                }
            }
            'N' { Write-Host "Pull request submission canceled." }
            'R' { Write-Host "Regenerating PR content..."; return (New-PSUAiPoweredPullRequest @PSBoundParameters) }
            'D' {
                $remoteUrl = (git remote get-url origin).Trim()
                if ($remoteUrl -match 'github\.com') {
                    Write-Host "Creating draft GitHub pull request..."
                    $params = @{
                        Title       = $PRContent.Title
                        Description = $PRContent.Description
                        Token       = $env:GITHUB_TOKEN
                        Draft       = $true
                    }
                    if ($CompleteOnApproval) { $params.CompleteOnApproval = $true }
                    New-PSUGithubPullRequest @params
                } elseif ($remoteUrl -match 'dev\.azure\.com|visualstudio\.com') {
                    Write-Host "Creating draft Azure DevOps pull request..."
                    $remoteUrl = (git remote get-url origin).Trim()

                    if ($remoteUrl -match '^.+dev\.azure\.com[/:]([^/]+)/([^/]+)/_git/.+$') {
                        $Organization = $matches[1]
                        $projectNameEncoded = $matches[2]
                    } else {
                        throw "Cannot parse project name from $remoteUrl"
                    }

                    $params = @{
                        Title          = $PRContent.Title
                        Description    = $PRContent.Description
                        RepositoryName = (git rev-parse --show-toplevel | Split-Path -Leaf)
                        Project        = [uri]::UnescapeDataString($projectNameEncoded)
                        Organization   = $Organization
                        Draft          = $true
                        PAT            = $PAT
                    }
                    if ($CompleteOnApproval) { $params.CompleteOnApproval = $true }
                    New-PSUADOPullRequest @params
                } else {
                    Write-Warning "git url: $remoteUrl"
                    Write-Warning "Automatic pull request creation is not supported for this Git provider. Please create the PR manually."
                }
            }
        }

    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    } finally {
        Set-Location $currentLocation
    }
}
