function New-PSUGitCommitMessge {
    <#
    .SYNOPSIS
        Generates and commits a conventional Git commit message using Gemini AI, then syncs with remote.

    .DESCRIPTION
        Analyzes uncommitted changes in a Git repository, generates a conventional commit message using Gemini AI,
        commits those changes, pulls latest from remote with rebase, and pushes your new commit.

    .PARAMETER RootPath
        Optional. Git repository root path. Defaults to current directory.

    .EXAMPLE
        New-PSUGitCommitMessge

    .EXAMPLE
        New-PSUGitCommitMessge -RootPath "c:\repo"

    .NOTES
        Author : Lakshmanachari Panuganti
        Date   : 2025-07-31
        Requires:
            - Git CLI
            - $env:API_KEY_GEMINI
            - Invoke-PSUPromptOnGeminiAi

    #>
    [CmdletBinding()]
    param (
        [string]$RootPath = (Get-Location).Path
    )

    Push-Location $RootPath
    try {
        $gitOutput = git status --porcelain

        if (-not $gitOutput.Count) {
            Write-Host "No uncommitted changes found." -ForegroundColor Green
            return
        }

        $changedItems = foreach ($line in $gitOutput) {
            $line = $line.Trim()
            $changeCode = $line.Split(' ')[0].Trim()
            $path = $line.Split(' ', 2)[1].Trim().Trim('"')
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
                    'C' { 'Copied' }
                    'U' { 'Unmerged' }
                    '??' { 'New' }
                    default { "Other: $changeCode" }
                }
                Path       = $fullPath
            }
        }

        $fileChanges = $changedItems | ForEach-Object {
            $item = $_
            $status = $item.ChangeType
            $path = $item.Path
            $itemType = $item.ItemType

            $diff = switch ($status) {
                'Modified' { git diff -- "$path" }
                'New' { if ($itemType -eq 'File') { Get-Content -Path $path } }
                default { "" }
            }

            [PSCustomObject]@{
                Path     = $path
                ItemType = $itemType
                Status   = $status
                Diff     = $diff -join "`n"
            }
        }

        $prompt = @"
You are a Git commit message generator with expertise in software development.

Generate a clear, conventional commit message based on the following file changes.
The message must start with one of: feat, fix, chore, docs, refactor, style, test.
Limit to 1-2 lines.

Changes:
"@

        foreach ($item in $fileChanges) {
            $prompt += @"
### File: $($item.Path)
Change Type: $($item.Status)
```diff
$($item.Diff)
"@
            $commitMessage = Invoke-PSUPromptOnGeminiAi -Prompt ($prompt | Out-String) -ApiKey $env:API_KEY_GEMINI
            $commitMessage = $commitMessage.Trim() | where-object { $_ }

            Write-Host "Following is the Commit message!" -ForegroundColor Cyan
            Write-Host $CommitMessage -ForegroundColor DarkYellow
            $CustomCommitMsg = Read-Host "Press enter to commit with this message or provide your own commit message"
        
            if ($CustomCommitMsg) {
                $commitMessage = $CustomCommitMsg
            }
            # Stage and commit
            git add . *> $null
            git commit -m "$commitMessage" *> $null

            Write-Host "Committed with message:" -ForegroundColor Cyan
            Write-Host "`"$commitMessage`"" -ForegroundColor Yellow

            # Sync with remote
            Write-Host "`⇅ Syncing with remote..." -ForegroundColor Cyan
            git pull --rebase *> $null
            git push *> $null

            Write-Host "Sync complete." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Error: $_"
        throw
    }
    finally {
        Pop-Location
    }
}