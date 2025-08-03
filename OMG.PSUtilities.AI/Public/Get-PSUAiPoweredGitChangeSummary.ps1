function Get-PSUAiPoweredGitChangeSummary {
    <#
    .SYNOPSIS
        Summarizes file-level changes between two Git branches using Google Gemini AI.

    .DESCRIPTION
        Compares a feature branch to a base branch (e.g., main) and identifies all changed files.
        Sends the diffs in batch to Gemini AI for per-file summarization, returning a structured object
        with filename, type of change (New/Modify/Delete), and a concise summary.

        Depends: git CLI

    .PARAMETER BaseBranch
        The base branch to compare against. Defaults to 'main'.

    .PARAMETER FeatureBranch
        The feature branch being merged. Defaults to 'feature/dev'.

    .EXAMPLE
        Get-PSUAiPoweredGitChangeSummary -BaseBranch main -FeatureBranch feature/login-ui

    .NOTES
        Author: Lakshmanachari Panuganti
        Created: 2025-07-27

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AI
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    param(
        [string]$BaseBranch = $(git symbolic-ref refs/remotes/origin/HEAD | Split-Path -Leaf),
        [string]$FeatureBranch = $(git branch --show-current),
        [string]$ApiKeyGemini = $env:API_KEY_GEMINI
    )

    # Ensure Git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git CLI not found. Please ensure Git is installed and available in PATH."
    }

    # Ensure branches exist
    git rev-parse --verify $BaseBranch 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Base branch '$BaseBranch' does not exist." }

    git rev-parse --verify $FeatureBranch 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Feature branch '$FeatureBranch' does not exist." }

    $null = Invoke-SafeGitCheckout -TargetBranch $BaseBranch -ReturnToBranch $FeatureBranch

    # Fetch list of changed files and type of change
    $gitChanges = Get-PSUGitFileChangeMetadata -BaseBranch $BaseBranch -FeatureBranch $FeatureBranch


    if (-not $gitChanges) {
        Write-Host "No differences found between $BaseBranch and $FeatureBranch." -ForegroundColor Green
        return @()
    }

    # Build prompt for Gemini summarization
    $prompt = @"
You are a helpful assistant summarizing code changes with expert in understanding the response give by Git cmds. Analyze the following list of files and their diffs.
For each file, return a JSON array element with:
- File: file name
- TypeOfChange: New/Modify/Delete
- Summary: a short summary of what changed (max 1-2 sentences)

Respond with a pure JSON array only. Example:
[
  {"File": "src/module/file1.ps1", "TypeOfChange": "New", "Summary": "Added logging for user authentication."},
  {"File": "scripts/util.ps1", "TypeOfChange": "Modify", "Summary": "Refactored parameter parsing logic."}
  {"File": "scripts/util.ps1", "TypeOfChange": "Renamed", "Summary": "The <Old File Name> was fanamed to <New File Name, with so and so refactors>"}
]

Here are the file-level diffs:

"@

    foreach ($item in $gitChanges) {
        $diff = if ($item.Type -eq "Delete") {
            "[Deleted File]"
        }
        elseif ($item.Type -eq "New") {
            git show "$($FeatureBranch):$($item.File)" 2>$null
        }
        else {
            git diff $BaseBranch $FeatureBranch -- "$($item.File)"
        }

        $prompt += "\n### File: $($item.File) [$($item.Type)]\n"
        if ($item.Comment) {
            $prompt += $item.Comment
        }
        $prompt += $diff
        $prompt += "\n"
    }

    # Call Gemini for summarization
    $json = Invoke-PSUPromptOnGeminiAi -Prompt $prompt -ApiKey $ApiKeyGemini -ReturnJsonResponse

    try {
        $results = $json | ConvertFrom-Json -ErrorAction Stop
        return $results | ForEach-Object {
            [PSCustomObject]@{
                File         = $_.File
                TypeOfChange = $_.TypeOfChange
                Summary      = $_.Summary
            }
        }
    }
    catch {
        Write-Warning "Failed to parse Gemini response as JSON. Raw response:`n$json"
        return @()
    }
}
