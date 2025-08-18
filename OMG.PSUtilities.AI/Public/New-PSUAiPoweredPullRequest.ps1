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

    .OUTPUTS
        [PSCustomObject]

    .EXAMPLE
        New-PSUAiPoweredPullRequest

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

        [Parameter()]
        $PullRequestTemplate = "C:\Temp\PRTemplate.txt",

        [Parameter()]
        [string] $ApiKey = $env:API_KEY_GEMINI
    )


    $ChangeSummary = Get-PSUAiPoweredGitChangeSummary -ApiKeyGemini $ApiKey

    if (-not $ChangeSummary) {
        Write-Warning "No changes found "
        return
    }

    # Convert summaries into a nice prompt for Gemini
    $formattedChanges = ($ChangeSummary | ForEach-Object {
            "- File: `$($_.File)` | Change: $($_.TypeOfChange) | Summary: $($_.Summary)"
        }) -join "`n"

    $PRTemplateContent = Get-Content -Path $PullRequestTemplate | Out-String

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


    $prompt = @"
You are a professional software engineer and DevOps expert.
Given the following Git change summaries, generate a high-quality Pull Request title and a detailed, clear description suitable for code review.

Use a professional tone, and ensure the description is helpful to both developers, reviewers and should be in human writing style.

### Git Change Summaries:
$formattedChanges

Finally remove any duplicate data in description and respond in the following JSON format:
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
        #$PRContent = [PSCustomObject]@{
        #    Title       = $parsed.title
        #    Description = $parsed.description
        #}
        ($parsed.title) + '`n ' + ($parsed.description) | Set-Clipboard
        Convert-PSUPullRequestSummaryToHtml -Title $parsed.title -Description $parsed.description -OpenInBrowser

        $readHost = Read-Host "Would you like me to submit the pull request with the current title and description, or retry generating new ones? (Y/N/R)"

        switch ($readHost) {
            'Y' {
                #TODO: write the code to submit PR:
                #Logic to get the Base branch -like refs/heads/main
                #Logic to get the Base feature branch -like refs/heads/featuire-ui-design
                #New-PSUADOPullRequest (available in 'OMG.PSUtilities.AzureDevOps' Module)
            }
            'N' {
                Write-Host "Pull request submission canceled."
            }
            'R' {
                Write-Host "Retrying PR generation..."
                # Logic to regenerate PR content
                & $MyInvocation.MyCommand @PSBoundParameters
                return
            }
            default {
                Write-Host "Invalid choice. Please enter Y, N, or R."
            }
        }

    }
    catch {
        Write-Warning "Failed to parse AI response as JSON. Raw output returned."
        [PSCustomObject]@{
            Title       = "PR Title (AI parsing failed)"
            Description = $response
        }
    }

}

