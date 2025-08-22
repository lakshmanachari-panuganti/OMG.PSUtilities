## [1.0.10] - 23rd August 2025
### Added
- `Invoke-PSUAiPrompt.ps1`: Public function to route prompts to the selected AI provider (`AzureOpenAi`, `GeminiAi`, or `PerplexityAi`) with support for JSON response.
- `Set-PSUDefaultAiEngine.ps1`: Public function to set and persist the default AI engine for module use.
- `Update-PSUChangeLog.ps1`: Public function that leverages AI to generate and prepend a professional changelog entry based on `.ps1` file diffs.

### Changed
- `New-PSUAiPoweredPullRequest.ps1`: Now prompts the user to update `ChangeLog.md` with changes and invokes `Update-PSUChangeLog` if confirmed.

## [1.0.9] - 2025-08-19
### Changed
- Updated all public functions to comply with OMG.PSUtilities.StyleGuide.md standards
- Standardized comment-based help with ordinal date format (DDth month YYYY)
- Added comprehensive .OUTPUTS sections to all functions
- Corrected .LINK section ordering (GitHub → LinkedIn → PowerShell Gallery → Microsoft Docs)
- Enhanced documentation consistency and professional presentation across all functions

## [1.0.8] - 2025-08-15

- Default values for `SourceBranch` and `TargetBranch` parameters in `Invoke-PSUPullRequestCreation.ps1` using git commands.


## [1.0.7] - 2025-08-11
### Changed
- Minor modifications along with version bump and metadata updates.

## [1.0.6] - 2025-08-05
### Added
- New-PSUAiPoweredPullRequest (Public): Creates a new pull request with AI-generated summary.
- Invoke-PSUPullRequestCreation (Private): Internal logic for creating pull requests.

## [1.0.5] - 2025-07-30
### Added
- Get-PSUAiPoweredGitChangeSummary (Public): Summarizes Git changes using AI.
- Invoke-PSUGitCommit (Public): Commits changes to Git repository.
- Invoke-PSUPromptOnAzureOpenAi (Public): Sends prompt to Azure OpenAI and returns response.
- Invoke-SafeGitCheckout (Private): Safely checks out a Git branch.

## [1.0.1] - 2025-07-20
### Added
- Start-PSUGeminiChat (Public): Starts an interactive Gemini AI chat session.
- Invoke-PSUPromptOnGeminiAi (Public): Sends prompt to Gemini AI and returns response.
- Invoke-PSUPromptOnPerplexityAi (Public): Sends prompt to Perplexity AI and returns response.
- Convert-PSUMarkdownToHtml (Private): Converts Markdown text to HTML.
- Convert-PSUPullRequestSummaryToHtml (Private): Converts pull request summary to HTML.

## [1.0.0] - 2025-07-10
### Added
- Initial scaffolding for OMG.PSUtilities.AI.
