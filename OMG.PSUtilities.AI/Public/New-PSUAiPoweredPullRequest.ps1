function New-PSUAiPoweredPullRequest {
    <#
    .SYNOPSIS
        Uses Gemini AI to generate a professional Pull Request (PR) title and description from Git change summaries.

    .DESCRIPTION
        This function takes Git change summaries and uses the Gemini model (via Invoke-PSUPromptOnGeminiAi)
        to produce a high-quality PR title and description written from a developer or DevOps perspective.

    .PARAMETER BaseBranch
        (Optional) The base branch to compare against.
        Default value is the default branch from git symbolic-ref refs/remotes/origin/HEAD.

    .PARAMETER FeatureBranch
        (Optional) The feature branch being merged.
        Default value is the current git branch from git branch --show-current.

    .PARAMETER PullRequestTemplate
        (Optional) Path to the Pull Request template file.
        Default value is "C:\Temp\PRTemplate.txt".

    .PARAMETER ApiKey
        (Optional) The API key for Google Gemini AI service.
        Default value is $env:API_KEY_GEMINI. Set using: Set-PSUUserEnvironmentVariable -Name "API_KEY_GEMINI" -Value "your-api-key"

    .PARAMETER CompleteOnApproval
        (Optional) Switch parameter to enable auto-completion when the pull request is approved.
        This will be passed to the underlying PR creation function.

    .OUTPUTS
        [PSCustomObject]

    .EXAMPLE
        New-PSUAiPoweredPullRequest

    .EXAMPLE
        New-PSUAiPoweredPullRequest -CompleteOnApproval

        Generates an AI-powered pull request that will automatically complete when approved.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date  : 2025-07-28

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
        [string]$BaseBranch = $(git symbolic-ref refs/remotes/origin/HEAD | Split-Path -Leaf),

        [Parameter()]
        [string]$FeatureBranch = $(git branch --show-current),

        # Add validation for template path
        [Parameter()]
        [ValidateScript({
                if ($_ -and -not (Test-Path $_)) {
                    throw "PR template file not found: $_"
                }
                return $true
            })]
        [string]$PullRequestTemplate,

        [Parameter()]
        [string] $ApiKey = $env:API_KEY_GEMINI,

        [Parameter()]
        [switch]$CompleteOnApproval
    )


    $ChangeSummary = Get-PSUAiPoweredGitChangeSummary -ApiKeyGemini $ApiKey

    if (-not $ChangeSummary) {
        Write-Warning "No changes found "
        return
    }

    # Convert summaries into a nice prompt for Gemini
    $formattedChanges = ($ChangeSummary | ForEach-Object {
            "- File: $($_.File) | Change: $($_.TypeOfChange) | Summary: $($_.Summary)"
        }) -join "`n"

    # Handle PR template - check if file exists
    $PRTemplateContent = ""
    $PRTemplateStatement = @()
    
    if (Test-Path $PullRequestTemplate) {
        try {
            $PRTemplateContent = Get-Content -Path $PullRequestTemplate -ErrorAction Stop | Out-String
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
        }
        catch {
            Write-Warning "Could not read PR template file: $($_.Exception.Message)"
        }
    }
    else {
        Write-Verbose "No PR template specified. Proceeding without template."
    }


    $prompt = @"
You are a professional software engineer and DevOps expert.
Given the following Git change summaries, generate a high-quality Pull Request title and a detailed, clear description suitable for code review.

Use a professional tone, and ensure the description is helpful to both developers, reviewers and should be in human writing style.

### Git Change Summaries:
$formattedChanges

Finally remove any duplicate data in description and respond in the following JSON format (***ONLY JSON format***):
{
  "title": "<generated-title>",
  "description": "<generated-description>"
}
$PRTemplateStatement
"@.Trim()

    # Call Gemini to generate PR content
    $response = Invoke-PSUPromptOnGeminiAi -Prompt $prompt -ReturnJsonResponse

    # Try parsing the AI response as JSON
    try {
        $parsed = $response | ConvertFrom-Json -ErrorAction Stop
        $PRContent = [PSCustomObject]@{
            Title       = $parsed.title
            Description = $parsed.description
        }
        ($parsed.title) + '`n ' + ($parsed.description) | Set-Clipboard
        Convert-PSUPullRequestSummaryToHtml -Title $parsed.title -Description $parsed.description -OpenInBrowser

        # Better user prompt with clearer options

        Write-Host 'Choose an option:' -ForegroundColor Yellow
        Write-Host '  Y - Submit the pull request now' -ForegroundColor Cyan
        Write-Host '  N - Cancel and exit' -ForegroundColor Cyan
        Write-Host '  R - Regenerate with new AI content' -ForegroundColor Cyan
        Write-Host '  D - Draft the PR' -ForegroundColor Cyan

        $readHost = Read-Host 'Enter your choice (Y/N/R/D)' -ForegroundColor Yellow

        switch ($readHost) {
            'Y' {                
                # Determining the gitProvider
                $remoteUrl = git remote get-url origin
                if ($remoteUrl -match 'github\.com') {
                    Write-Host "Creating the GitHub pull request"
                    $params = @{
                        Title = $PRContent.Title
                        Description = $PRContent.Description
                        Token = $env:GITHUB_TOKEN
                    }
                    if ($CompleteOnApproval) { 
                        $params.CompleteOnApproval = $true 
                    }
                    New-PSUGithubPullRequest @params
                }
                elseif ($remoteUrl -match 'dev\.azure\.com|visualstudio\.com') {
                    Write-Host "Creating the Azure DevOps pull request"
                    $params = @{
                        Title = $PRContent.Title
                        Description = $PRContent.Description
                        PAT = $env:PAT
                    }
                    if ($CompleteOnApproval) { 
                        $params.CompleteOnApproval = $true 
                    }
                    New-PSUADOPullRequest @params
                }
                else {
                    Write-Warning "git url: $remoteUrl"
                    Write-Warning "Automatic pull request creation is not supported for this Git provider. Please create the PR manually."
                }
            }
            'N' {
                Write-Host "Pull request submission canceled."
            }
            'R' {
                Write-Host "Regenerating PR content..."
                return (New-PSUAiPoweredPullRequest @PSBoundParameters)
            }
            'D' {
                # Determining the $gitProvider for draft PR
                $remoteUrl = git remote get-url origin
                if ($remoteUrl -match 'github\.com') {
                    Write-Host "Creating draft GitHub pull request"
                    $params = @{
                        Title = $PRContent.Title
                        Description = $PRContent.Description
                        Token = $env:GITHUB_TOKEN
                        Draft = $true
                    }
                    if ($CompleteOnApproval) { 
                        $params.CompleteOnApproval = $true 
                    }
                    New-PSUGithubPullRequest @params
                }
                elseif ($remoteUrl -match 'dev\.azure\.com|visualstudio\.com') {
                    Write-Host "Creating draft Azure DevOps pull request"
                    $params = @{
                        Title = $PRContent.Title
                        Description = $PRContent.Description
                        PAT = $env:PAT
                        Draft = $true
                    }
                    if ($CompleteOnApproval) { 
                        $params.CompleteOnApproval = $true 
                    }
                    New-PSUADOPullRequest @params
                }
                else {
                    Write-Warning "git url: $remoteUrl"
                    Write-Warning "Automatic pull request creation is not supported for this Git provider. Please create the PR manually."
                }
            }
            default {
                Write-Warning "Invalid choice. Please enter Y, N, R, or D."
            }
        }

    }
    catch {
        $PSCmdlet.ThrowTerminatingError()
    }
}

