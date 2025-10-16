function Update-PSUChangeLog {
    <#
    .SYNOPSIS
        Uses AI to generate and prepend a professional changelog entry for major module updates, based on file diffs between branches.
    .DESCRIPTION
        Compares .ps1 file changes between branches, summarizes them with AI, and prepends the result to CHANGELOG.md.
    .PARAMETER ModuleName
        The name of the module to update (e.g., OMG.PSUtilities.AI).
    .PARAMETER RootPath
        The root path where modules are located. Defaults to $env:BASE_MODULE_PATH.
    .PARAMETER BaseBranch
        The base branch to compare (default: origin/main).
    .PARAMETER FeatureBranch
        The feature branch to compare (default: current branch).
    .EXAMPLE
        Update-PSUChangeLog -ModuleName OMG.PSUtilities.AI
    .NOTES
        Author : Lakshmanachari Panuganti
        Date : 22nd August 2025
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [Alias("aichangelog")]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RootPath = $env:BASE_MODULE_PATH,

        [Parameter()]
        [string]$BaseBranch = $(git symbolic-ref refs/remotes/origin/HEAD 2>$null),

        [Parameter()]
        [string]$FeatureBranch = $(git branch --show-current 2>$null)
    )
    process {
        Write-Host "Starting Update-PSUChangeLog for module [$ModuleName]"
        try {
            $moduleRoot = Join-Path $RootPath $ModuleName
            $changelogPath = Join-Path $moduleRoot 'CHANGELOG.md'

            if (-not (Test-Path $changelogPath)) {
                Write-Error "CHANGELOG.md not found for $ModuleName at path [$changelogPath]."
                return
            }

            # Detect changed files
            Write-Verbose "Comparing changes between [$BaseBranch] and [$FeatureBranch]"
            $files = git -C $moduleRoot diff "$($BaseBranch)...$($FeatureBranch)" --name-only |
            Where-Object { ($_ -replace '\\', '/') -match "$ModuleName/(Public|Private)/.*\.ps1$" }

            if (-not $files) {
                Write-Warning "No .ps1 file changes detected between $BaseBranch and $FeatureBranch."
                return
            }

            $diffs = foreach ($file in $files) {
                Write-Verbose "Processing diff for file: $file"
                [PSCustomObject]@{
                    FileName    = $file
                    DiffContent = (git -C $RootPath diff "$($BaseBranch)...$($FeatureBranch)" -- "$file")
                }
            }

            # Build prompt for AI

            $prompt = @"
You are a master in reviewing and analyzing git logs.

Strictly follow the output rules below:
- Format the result in **valid Markdown**.
- Use `### Added` and `### Changed` sections.
- Only include `### Deprecated`, `### Removed`, `### Fixed`, or `### Security` if there are actual entries (ignore them if none).
- Use a dash `-` for each bullet point.
- Wrap **all function names, filenames, cmdlets, and module names** in backticks (e.g., `Get-MyFunction.ps1`, `Invoke-Something`).
- Do not include version numbers or dates.
- Keep the output minimal and ready to paste into a changelog.

Example output:

### Added
- Comprehensive `.OUTPUTS` sections to all public-facing cmdlets.
- `New-PSUAiPoweredPullRequest` (Public): Generates a pull request with AI-generated summary.
- `Invoke-PSUPullRequestCreation` (Private): Handles internal PR creation logic.
- `Get-PSUAiPoweredGitChangeSummary` (Public): Summarizes Git changes using AI models.
- `Invoke-PSUGitCommit` (Public): Standardizes Git commit process with templating.
- `Invoke-PSUPromptOnAzureOpenAi` (Public): Sends prompt to Azure OpenAI endpoint.
- `Invoke-SafeGitCheckout` (Private): Safely checks out a Git branch with recovery options.
- `Start-PSUGeminiChat` (Public): Launches an interactive Gemini AI-powered chat session.
- `Invoke-PSUPromptOnGeminiAi` (Public): Sends prompt to Gemini AI and retrieves the response.
- `Invoke-PSUPromptOnPerplexityAi` (Public): Sends prompt to Perplexity AI and retrieves a response.
- `Convert-PSUMarkdownToHtml` (Private): Converts Markdown content to HTML.
- `Convert-PSUPullRequestSummaryToHtml` (Private): Converts AI-generated PR summaries to HTML format.
- Initial scaffolding for `OMG.PSUtilities.AI` PowerShell module.

### Changed
- Updated all public functions to comply with `OMG.PSUtilities.StyleGuide.md` standards.
- Standardized comment-based help with ordinal date format (e.g., 21st August 2025).
- Corrected `.LINK` section ordering: GitHub → LinkedIn → PowerShell Gallery → Microsoft Docs.
- Enhanced documentation consistency and formatting across all public/private functions.
- Default values for `SourceBranch` and `TargetBranch` in `Invoke-PSUPullRequestCreation.ps1` are now auto-resolved using Git commands.
- Minor metadata updates and version bump for maintenance purposes.

### Deprecated
- Deprecated `Invoke-OldApiRequest` function in favor of the new `Invoke-NewApiRequest`.
- Deprecated support for PowerShell 5.1 in upcoming versions.

### Removed
- Removed legacy `Get-OldConfig` cmdlet no longer in use.
- Removed obsolete XML config files from the module root.

### Fixed
- Fixed issue where `Invoke-PSUGitCommit` failed on empty commit messages.
- Fixed typo in `Update-PSUReadMe.ps1` that caused documentation generation errors.
- Fixed race condition in `Start-PSUGeminiChat` initialization logic.

### Security
- Patched vulnerability related to unsafe handling of user inputs in `Invoke-PSUPromptOnAzureOpenAi`.
- Improved token encryption for API credentials stored in memory.
- Updated dependencies to address CVE-2025-12345 affecting the JSON parsing library.

Note: if any type change (like Deprecated, Removed, Fixed, Security) is not available ignore that!
#------[ Generate a changelog entry summary for the following file changes: ]------#
"@

            foreach ($diff in $diffs) {
                $prompt += "`n### File: $($diff.FileName)`n"
                $prompt += "`nDiff: `n$($diff.DiffContent | Out-String)`n"
                $prompt += "#------[ End of this file changes ]------#`n`n"
            }

            if ($PSCmdlet.ShouldProcess($ModuleName, "Update CHANGELOG.md")) {
                Write-Verbose "Invoking AI summarization..."
                $ChangeLogSummary = Invoke-PSUAiPrompt -Prompt ($prompt | Out-String)

                Write-Verbose "Fetching module metadata..."
                $psd1Path = Get-PSUModule -ScriptPath $changelogPath | Select-Object -ExpandProperty ManifestPath
                $psDataFile = Import-PowerShellDataFile -Path $psd1Path
                $currentChangelog = (Get-Content -Path $changelogPath -Raw).Trim()

                if ($currentChangelog.StartsWith("## [$($psDataFile.ModuleVersion)]")) {
                    Write-Host "Already found existing changelog entry for version $($psDataFile.ModuleVersion)" -ForegroundColor Green
                } else {

                    $entry = "## [$($psDataFile.ModuleVersion)] - $(Get-OrdinalDate)`n$ChangeLogSummary`n"
                    $newChangelog = $entry + $currentChangelog
                    Set-Content -Path $changelogPath -Value $newChangelog -Encoding UTF8

                    Write-Host "CHANGELOG.md updated successfully for $ModuleName." -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Error "Failed to update changelog for $ModuleName. Error: $_"
        }
    }
}
