function Invoke-PSUGitCommit {
    <#
    .SYNOPSIS
        Generates and commits a conventional Git commit message using Gemini AI, then syncs with remote.

    .DESCRIPTION
        Analyzes uncommitted changes in a Git repository, generates a conventional commit message using Gemini AI,
        commits those changes, pulls latest from remote with rebase, and pushes your new commit.

    .EXAMPLE
        Invoke-PSUGitCommit

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
    param ( )

    $ignorePatterns = @(
        "*.env", ".env", ".env.*",
        ".gitignore",
        "*.lock", "package-lock.json", "yarn.lock",
        "*.tfstate", "*.tfstate.*",
        "*.key", "*.pem", "*.crt",
        "*.pfx",
        "*.dll", "*.pdb", "*.exe",
        "node_modules/*",
        "dist/*", "build/*",
        "bin/*", "obj/*",
        "*.zip", "*.tar", "*.gz"
    )

    function Test-SkipFile($path) {
        foreach ($pattern in $ignorePatterns) {
            if ($path -like $pattern) {
                return $true
            }
        }
        return $false
    }

    function Invoke-CheckedGit {
        param (
            [Parameter(Mandatory)]
            [string]$Operation,

            [Parameter(Mandatory)]
            [string[]]$Arguments
        )

        $output = @(& git @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            $failureDetail = ($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
            throw "git $Operation failed with exit code $exitCode. $failureDetail"
        }

        $output
    }

    try {
        $currentLocation = Get-Location
        $gitRootOutput = @(Invoke-CheckedGit -Operation 'rev-parse' -Arguments @('rev-parse', '--show-toplevel'))
        $RootPath = [string]($gitRootOutput | Select-Object -Last 1)
        Write-Verbose "Git repository root: $RootPath"

        Set-Location -LiteralPath $RootPath

        $gitOutput = @(Invoke-CheckedGit -Operation 'status' -Arguments @('status', '--porcelain', '-uall') |
                Where-Object { $_ })
        if (-not $gitOutput.Count) {
            Write-Host "No uncommitted changes found." -ForegroundColor Green
            return
        }

        $statusEntries = @($gitOutput | ForEach-Object {
                $line = [string]$_
                if ($line.Length -lt 4) {
                    return
                }

                $indexStatus = [string]$line[0]
                $workTreeStatus = [string]$line[1]
                $changeCode = "$indexStatus$workTreeStatus"
                $path = $line.Substring(3).Trim()
                if ($path -match ' -> ') {
                    $path = ($path -split ' -> ')[-1]
                }
                $path = $path.Trim('"')

                $changeType = if ($changeCode -eq '??') {
                    'New'
                } elseif ($changeCode -match 'D') {
                    'Deleted'
                } elseif ($changeCode -match 'R') {
                    'Renamed'
                } elseif ($changeCode -match 'C') {
                    'Copied'
                } elseif ($changeCode -match 'A') {
                    'Added'
                } elseif ($changeCode -match 'U') {
                    'Unmerged'
                } else {
                    'Modified'
                }

                $fullPath = Join-Path -Path $RootPath -ChildPath $path
                $itemInfo = Get-Item -LiteralPath $fullPath -ErrorAction SilentlyContinue

                $itemType = if ($changeType -eq 'Deleted' -or -not $itemInfo) {
                    'File/Folder'
                } elseif ($itemInfo -is [System.IO.DirectoryInfo]) {
                    'Folder'
                } elseif ($itemInfo -is [System.IO.FileInfo]) {
                    'File'
                } else {
                    'Unknown'
                }

                [pscustomobject]@{
                    Name         = Split-Path $path -Leaf
                    ItemType     = $itemType
                    ChangeType   = $changeType
                    Path         = $fullPath
                    RelativePath = $path
                    IsStaged     = $indexStatus -notin @(' ', '?')
                }
            })

        $preStagedPaths = @($statusEntries |
                Where-Object { $_.IsStaged } |
                ForEach-Object { $_.RelativePath })
        $changedItems = @($statusEntries |
                Where-Object { -not (Test-SkipFile $_.RelativePath) })

        if ($changedItems.Count -eq 0) {
            Write-Host "No reviewed changes remain after applying the safety filters." -ForegroundColor Yellow
            return
        }

        $reviewedPaths = @($changedItems.RelativePath | Sort-Object -Unique)
        $preStagedOutsideReview = @($preStagedPaths |
                Where-Object { $_ -notin $reviewedPaths } |
                Sort-Object -Unique)
        if ($preStagedOutsideReview.Count -gt 0) {
            throw "Commit aborted because pre-staged paths are outside the reviewed set: $($preStagedOutsideReview -join ', ')"
        }

        $popupResponse = Popup-SensitiveContent -Files ($changedItems | Where-Object { $_.ItemType -eq 'File' } | Select-Object -ExpandProperty Path)
        if (-not $popupResponse) {
            Write-Host "Commit aborted due to sensitive content." -ForegroundColor Red
            return
        }

        $fileChanges = $changedItems | ForEach-Object {
            $item = $_
            $status = $item.ChangeType
            $path = $item.Path

            $diff = if ($status -eq 'New') {
                if ($item.ItemType -eq 'File') {
                    Get-Content -LiteralPath $path
                }
            } else {
                Invoke-CheckedGit -Operation 'diff' -Arguments @('diff', 'HEAD', '--', $item.RelativePath)
            }

            [PSCustomObject]@{
                Path     = $path
                ItemType = $item.ItemType
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

IMPORTANT:
If any file contains passwords, tokens, secrets, API keys, connection strings,
client secrets, or ANY sensitive value, DO NOT include the actual value in the commit message.
Summarize it generically (e.g., "updated credential configuration")
instead of exposing plaintext data.

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

        do {
            $commitMessage = [string](Invoke-PSUAiPrompt -Prompt ($prompt | Out-String))
            if ([string]::IsNullOrWhiteSpace($commitMessage)) {
                throw "AI did not generate a commit message."
            }
            $commitMessage = $commitMessage.Trim()

            Write-Host "Following is the Commit message!" -ForegroundColor Cyan
            Write-Host $commitMessage -ForegroundColor DarkYellow
            Write-Host "`n[R]      --> Regenerate a new commit message!" -ForegroundColor Cyan
            Write-Host "[Ctrl+C] --> Abort commit process!" -ForegroundColor Cyan
            Write-Host "[Enter]  --> Accept the above commit message!" -ForegroundColor Cyan

            $customCommitMessage = ([string](Read-Host -Prompt "Enter your choice")).Trim()
            if ($customCommitMessage -ieq 'R') {
                continue
            }
            if ($customCommitMessage) {
                $commitMessage = $customCommitMessage
            }
            break
        } while ($true)

        $null = Invoke-CheckedGit -Operation 'add' -Arguments (@('add', '--') + $reviewedPaths)
        $null = Invoke-CheckedGit -Operation 'commit' -Arguments @('commit', '-m', $commitMessage)

        Write-Host "`⇅ Syncing with remote..." -ForegroundColor Cyan
        $null = Invoke-CheckedGit -Operation 'pull' -Arguments @('pull', '--rebase')
        $null = Invoke-CheckedGit -Operation 'push' -Arguments @('push')

        Write-Host "Sync complete." -ForegroundColor Green

    }
    catch {
        Write-Error "Error: $_"
        throw
    }
    finally {
        Set-Location $currentLocation
    }
}
