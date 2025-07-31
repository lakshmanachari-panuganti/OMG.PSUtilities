function New-PSUAiPoweredPullRequest {
    <#
    .SYNOPSIS
        Uses Gemini AI to generate a professional Pull Request (PR) title and description from Git change summaries.

    .DESCRIPTION
        This function takes Git change summaries and uses the Gemini model (via Invoke-PSUPromptOnGeminiAi)
        to produce a high-quality PR title and description written from a developer or DevOps perspective.

    .PARAMETER ChangeSummary
        Input array or pipeline of Git file change summaries, with File, TypeOfChange, and Summary fields.

    .PARAMETER ApiKey
        Optional API key to pass to Gemini if needed.

    .OUTPUTS
        [PSCustomObject]

    .EXAMPLE
        New-PSUAiPoweredPullRequest

    .NOTES
        Author: Lakshmanachari Panuganti
        Date  : 2025-07-28
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$BaseBranch = $(git symbolic-ref refs/remotes/origin/HEAD | Split-Path -Leaf),

        [Parameter()]
        [string]$FeatureBranch = $(git branch --show-current),

        [Parameter()]
        $PullRequestTemplate,

        [Parameter()]
        [string] $ApiKey = $env:API_KEY_GEMINI
    )


    $allChanges = Get-PSUAiPoweredGitChangeSummary -BaseBranch $BaseBranch -FeatureBranch $FeatureBranch -ApiKeyGemini $ApiKey

    if (-not $allChanges) {
        Write-Warning "No changes found "
        return
    }

    # Convert summaries into a nice prompt for Gemini
    $formattedChanges = ($allChanges | ForEach-Object {
            "- File: `$($_.File)` | Change: $($_.TypeOfChange) | Summary: $($_.Summary)"
        }) -join "`n"

    $prompt = @"
You are a professional software engineer and DevOps expert.
Given the following Git change summaries, generate a high-quality Pull Request title and a detailed, clear description suitable for code review.

Use a professional tone, and ensure the description is helpful to both developers and reviewers.

### Git Change Summaries:
$formattedChanges

Finally remove any duplicate data in description and respond in the following JSON format:
{
  "title": "<generated-title>",
  "description": "<generated-description>"
}
"@.Trim()

    # Call Gemini to generate PR content
    $response = Invoke-PSUPromptOnGeminiAi -Prompt $prompt -ApiKey:$ApiKey -ReturnJsonResponse

    # Try parsing the AI response as JSON
    try {
        $parsed = $response | ConvertFrom-Json -ErrorAction Stop
        $PRContent = [PSCustomObject]@{
            Title       = $parsed.title
            Description = $parsed.description
        }
        ($parsed.Title + "`n`n" + $parsed.Description) | Out-String | Set-Clipboard
        $PRContent
        #TODO: write the code to submit PR:
        #Logic to get the Base branch -like refs/heads/main
        #Logic to get the Base feature branch -like refs/heads/featuire-ui-design
        Invoke-PSUPullRequestCreation    
    }
    catch {
        Write-Warning "Failed to parse AI response as JSON. Raw output returned."
        [PSCustomObject]@{
            Title       = "PR Title (AI parsing failed)"
            Description = $response
        }
    }
    
}
