function New-PSUGitCommitMessge {
    <#
    .SYNOPSIS
        Generates a conventional Git commit message based on uncommitted changes.

    .DESCRIPTION
        This function leverages `git status --porcelain` to identify changed files (added, modified, deleted, renamed, copied, unmerged, or new). 
        It then constructs a prompt using these changes and sends it to the Gemini AI to generate a concise, conventional commit message. 
        The generated message is automatically copied to the clipboard and also returned as output.

    .PARAMETER RootPath
        (Optional) Specifies the root directory of the Git repository to analyze.
        Deffault is the current working directory.

    .EXAMPLE 
        New-PSUGitCommitMessge
        
    .OUTPUTS
        [string]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date  : 2025-07-16
    #>
    [CmdletBinding()]
    param (
        [string]$RootPath = (Get-Location).Path
    )

    Push-Location $RootPath
    try {
        $gitOutput = git status --porcelain

        if ($null -eq $gitOutput) {
            Write-Host "No uncommited changes found" -ForegroundColor Green
            Continue
        }
        
        $changedItems = foreach ($line in $gitOutput) {
            $line = $line.Trim()

            $changeCode = $line.Split(' ')[0].Trim()
            $path = $line.Split(' ', 2)[1].Trim() -replace '"'
            $fullPath = Join-Path -Path $RootPath -ChildPath $path

            $itemInfo = Get-Item $fullPath -ErrorAction SilentlyContinue

            $itemType = if ($changeCode -eq 'D' -or -not $itemInfo) {
                'File/Folder'
            }
            elseif ($itemInfo -is [System.IO.DirectoryInfo]) {
                'Folder'
            }
            elseif ($itemInfo -is [System.IO.FileInfo]) {
                'File'
            }
            else {
                'Unknown'
            }

            [pscustomobject]@{
                Name       = Split-Path $path -Leaf
                ItemType   = $itemType
                ChangeType = switch ($changeCode) {
                    'M' { 'Modified' }
                    'A' { 'Added' }
                    'D' { 'Deleted' }
                    'R' { 'Renamed' }
                    'C' { 'Copied ' }
                    'U' { 'Unmerged' }
                    '??' { 'New' }
                    default { "Other: $changeCode" }
                }
                Path       = $fullPath
            }
        }

        $FileChanges = $changedItems | ForEach-Object {
            $item = $_
            $status = $item.ChangeType
            $Path = $item.Path
            $itemType = $item.ItemType
            $diff = switch ($status) {
                'Modified' { git diff -- "$Path" }
                'New' { if ($itemType -eq 'File') { Get-Content -Path $Path } }
                default { "" }
            }

            [PSCustomObject]@{
                Path     = $Path
                ItemType = $itemType
                Status   = $status
                Diff     = $diff -join "`n"
            }
        }

        $prompt = @"
You are a commit message generator with expertise in Git and DevOps.

Based on the following list of file changes (from `git status --porcelain`),
generate a concise, conventional commit message that follows this format:

Type: Short summary

Example types:
- Feature Example
---------------
feat: Implement user profile page! 
Adds a new user profile section where users can view and edit their personal information, including name, email, and password. 
Includes client-side validation for all input fields.

- Bug Fix Example
---------------
fix: Resolve infinite loop in data fetching! 
Corrects an issue where the data fetching mechanism would enter aninfinite loop under specific error conditions, causing the application to freeze. 
Ensures proper error handling and retry logic.

- Refactoring Example
-------------------
refactor: Extract API calls into dedicated service! Moves all data fetching logic from component files into a new `apiService.js`. 
This centralizes API interactions, improves code reusability, and makescomponents cleaner and easier to test.

- Documentation Example
----------------------
docs: Update README with setup instructions! 
Adds a detailed section to the README.md file explaining how to set up the development environment, install dependencies, and run the project locally.

- Chore/Maintenance Example
--------------------------
chore: Upgrade dependencies to latest versions! Updates all project dependencies to their most recent stable versions. 
Includes updates to React, Webpack, and various development tools to improve performance and security.

--> should be very short in two or three lines

Here are the changes:
"@
        

        foreach ($item in $fileChanges) {
            $prompt += @"
### File: $($item.File)
Change Type: $($item.Status)
Full Path: $($item.Path)
```diff
$($item.Diff)
"@
        }

        $CommitMessage = Invoke-PSUPromptOnGeminiAi -Prompt ($prompt | Out-String) -ApiKey $env:API_KEY_GEMINI
        $CommitMessage | Set-Clipboard
        Return $CommitMessage
        
    }
    Catch {
        Pop-Location
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
