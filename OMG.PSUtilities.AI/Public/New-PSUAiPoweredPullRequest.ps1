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


    $ChangeSummary = Get-PSUAiPoweredGitChangeSummary

    if (-not $ChangeSummary) {
        Write-Warning "No changes found "
        return
    }

    # Convert summaries into a nice prompt for Gemini
    $formattedChanges = ($ChangeSummary | ForEach-Object {
            "- File: `$($_.File)` | Change: $($_.TypeOfChange) | Summary: $($_.Summary)"
        }) -join "`n"

    if($PullRequestTemplate ){
        $PRTemplateStatement = "Please try to fit the description into the following Pull Request template: " + $PullRequestTemplate + " Do not modify the template structure or checklists—only update the description thoughtfully." | Out-String

    }

    $prompt = @"
You are a professional software engineer and DevOps expert.
Given the following Git change summaries, generate a high-quality Pull Request title and a detailed, clear description suitable for code review.

Use a professional tone, and ensure the description is helpful to both developers, reviewers and should be in human writing style.

### Git Change Summaries:
$formattedChanges

Finally remove any duplicate data in description $PRTemplateStatement and respond in the following JSON format:
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
        #$PRContent = [PSCustomObject]@{
        #    Title       = $parsed.title
        #    Description = $parsed.description
        #}
        ($parsed.Title + "`n`n" + $parsed.Description) | Out-String | Set-Clipboard

        Convert-PSUPullRequestSummaryToHtml -Title $parsed.title -Description $parsed.description -OpenInBrowser
        
        #TODO: write the code to submit PR:
        #Logic to get the Base branch -like refs/heads/main
        #Logic to get the Base feature branch -like refs/heads/featuire-ui-design
        #Invoke-PSUPullRequestCreation

    }
    catch {
        Write-Warning "Failed to parse AI response as JSON. Raw output returned."
        [PSCustomObject]@{
            Title       = "PR Title (AI parsing failed)"
            Description = $response
        }
    }
    
}
