function Invoke-PSUGitCommit {
    <#
    .SYNOPSIS
        Generates and commits a conventional Git commit message using Gemini AI, then syncs with remote.

    .DESCRIPTION
        Analyzes uncommitted changes in a Git repository, generates a conventional commit message using Gemini AI,
        commits those changes, pulls latest from remote with rebase, and pushes your new commit.

    .PARAMETER RootPath
        (Optional) Git repository root path.
        Default value is the current directory from (Get-Location).Path.

    .EXAMPLE
        Invoke-PSUGitCommit

    .EXAMPLE
        Invoke-PSUGitCommit -RootPath "c:\repo"

    .OUTPUTS
        None

    .NOTES
        Author : Lakshmanachari Panuganti
        Date   : 31st July 2025
        Requires:
            - Git CLI
            - Invoke-PSUAiPrompt

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
    [Alias("aigitcommit")]
    param (
        [string]$RootPath = (Get-Location).Path
    )

    $ignorePatterns = @(
        "*.env", ".env", ".env.*",
        ".gitignore",
        "*.lock", "package-lock.json", "yarn.lock",
        "*.tfstate", "*.tfstate.*", "*.tfvars", "*.tfvars.json",
        "*.key", "*.pem", "*.crt",
        "*.pfx",
        "*.dll", "*.pdb", "*.exe",
        "node_modules/*",
        "dist/*", "build/*",
        "bin/*", "obj/*",
        "*.zip", "*.tar", "*.gz"
    )

    function Should-SkipFile($path) {
        foreach ($pattern in $ignorePatterns) {
            if ($path -like $pattern) {
                return $true
            }
        }
        return $false
    }

    # ------------------------------------------------------------------

    Push-Location $RootPath
    try {
        $gitOutput = git status --porcelain

        if (-not $gitOutput.Count) {
            Write-Host "No uncommitted changes found." -ForegroundColor Green
            return
        }

        # Apply ignore filtering to changed file list
        $changedItems = foreach ($line in $gitOutput) {
            $line = $line.Trim()
            $changeCode = $line.Split(' ')[0].Trim()
            $path = $line.Split(' ', 2)[1].Trim().Trim('"')

            if (Should-SkipFile $path) { continue }

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

        # Ignore files during diff extraction (SECOND filter)
        $fileChanges = $changedItems | ForEach-Object {
            $item = $_

            if (Should-SkipFile $item.Path) { return }

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
Limit to 1-5 lines, based on the number of files changes and based on scenario.

Example: 

fix: typo in function name in utils.ps1!
- Corrected a spelling error in the `Get-ConfigData` function which was causing a runtime failure in some environments.

#----------------------------------------------------------------
chore: update logging logic and error handling in backup script!
- Improved log verbosity in Backup-Logs.ps1.
- Added fallback error message in ErrorHandler.ps1 for better diagnostics.

#----------------------------------------------------------------
refactor: clean up deployment scripts for clarity and reuse!
- Modularized common functions in Deploy-Common.ps1.
- Updated AzureDeploy.ps1 to use shared logic.
- Removed redundant code from PreDeploy.ps1.

#----------------------------------------------------------------
feat: add environment variable for staging to appsettings.json!
- Introduced `STAGE_API_URL` to support separate staging endpoints for CI pipelines.

#----------------------------------------------------------------
feat: implement retry logic in API integration scripts!
- Added `Invoke-WithRetry` to helper module.
- Refactored UploadArtifacts.ps1 and SyncMetadata.ps1 to use retry logic
- Updated config schema to include retry parameters.
- Improved test coverage for retry scenarios

#----------------------------------------------------------------
chore: enhance secret management for automation scripts!
- Integrated Azure Key Vault access in AuthHelper.ps1.
- Masked sensitive values in CI/CD output logs.

#----------------------------------------------------------------
docs: update README with new usage instructions for cleanup script!
- Clarified the usage examples and added a note on required permissions for `Cleanup-TempFiles.ps1`.

#----------------------------------------------------------------
test: add unit tests for Invoke-AzBackup and improve validation logic!
- Added Pester tests for core scenarios.
- Enhanced input validation inside Invoke-AzBackup.ps1.
- Minor formatting fixes in Test-Helpers.ps1.

#----------------------------------------------------------------

NOTE: No empty line or line breaks as follows, below is the example which should not be:
test: add unit tests for Invoke-AzBackup and improve validation logic

- Added Pester tests for core scenarios
- Enhanced input validation inside Invoke-AzBackup.ps1
- Minor formatting fixes in Test-Helpers.ps1

#----------------------------------------------------------------

Examples of commit messages that should NOT be used:

1. Missing conventional prefix:
Added new retry logic to API scripts
- Added Invoke-WithRetry function
- Refactored UploadArtifacts.ps1

2. Empty line between subject and body:
feat: add retry logic in API integration scripts

- Added Invoke-WithRetry function
- Refactored UploadArtifacts.ps1

3. Too long or verbose (exceeds 5 lines):
feat: implement retry logic in API integration scripts
- Added Invoke-WithRetry to helper module
- Refactored UploadArtifacts.ps1 and SyncMetadata.ps1
- Updated config schema to include retry parameters
- Improved test coverage for retry scenarios
- Updated README with new instructions
- Fixed minor bugs in SyncMetadata.ps1

4. Improper line breaks within bullet points:
fix: typo in function name in utils.ps1
- Corrected a spelling error in the `Get-ConfigData`
function which was causing a runtime failure in some
environments.

---------------------------------------------------
NOTE: 
--> The response should not start or end with triple backticks (``` ) or any code block formatting. 
--> Should not include any explanations or additional text outside the commit message.
--> Should not include markdown formatting.
--> Should only contain the commit message text as per the examples above.

---------------------------------------------------

Following are the git changes:
"@

        foreach ($item in $fileChanges) {
            $prompt += @"
### File: $($item.Path)
Change Type: $($item.Status)
```diff
$($item.Diff)
"@
        }

        $commitMessage = Invoke-PSUAiPrompt -Prompt ($prompt | Out-String)
        $commitMessage = $commitMessage.Trim() | where-object { $_ }
        Write-Host "Following is the Commit message!" -ForegroundColor Cyan
        Write-Host $CommitMessage -ForegroundColor DarkYellow

        Write-Host "`n[R]      --> Regenerate a new commit message!" -ForegroundColor Cyan
        Write-Host "[Ctrl+C] --> Abort commit process!" -ForegroundColor Cyan
        Write-Host "[Enter]  --> Accept the above commit message!" -ForegroundColor Cyan

        $CustomCommitMsg = Read-Host -Prompt "Enter your choice"
        $CustomCommitMsg = ($CustomCommitMsg).Trim()

        if ($CustomCommitMsg -ieq 'R') {
            Invoke-PSUGitCommit
        } elseif ($CustomCommitMsg) {
            $commitMessage = $CustomCommitMsg
        }
        # Stage and commit
        git add . *> $null
        git commit -m "$commitMessage" *> $null
        # Sync with remote
        Write-Host "`⇅ Syncing with remote..." -ForegroundColor Cyan
        git pull --rebase *> $null
        git push *> $null

        Write-Host "Sync complete." -ForegroundColor Green

    }
    catch {
        Write-Error "Error: $_"
        throw
    }
    finally {
        Pop-Location
    }
}
