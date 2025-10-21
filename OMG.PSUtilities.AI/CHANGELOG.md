## [1.0.22] - 21st October 2025
### Changed
- Updated commit message formatting guidelines in `Invoke-PSUGitCommit.ps1` to clarify that the response should not start or end with triple backticks or code block formatting.
- Added explicit instructions in `Invoke-PSUGitCommit.ps1` to exclude markdown formatting and explanations from commit message outputs.
## [1.0.21] - 21st October 2025
### Added
- Added the `PAT` parameter to `New-PSUAiPoweredPullRequest` to allow specifying a Personal Access Token for Azure DevOps authentication. Default value is `$env:PAT`.

### Changed
- Updated the prompt given to the AI to generate more meaningful titles for pull requests.
- Modified the AI prompt to suggest specific headings within the pull request description, such as "Feature/Change 1".
- Refactored Azure DevOps pull request creation to parse the organization and project name from the remote URL.
- Enhanced Azure DevOps pull request creation logic to include parameters for `RepositoryName`, `Project`, and `Organization`.

## [1.0.20] - 20th October 2025
### Added
- Added `[ValidateNotNullOrEmpty()]` validation to the `BaseBranch` and `FeatureBranch` parameters in `New-PSUAiPoweredPullRequest.ps1`.
- Improved prompt construction in `New-PSUAiPoweredPullRequest.ps1` to explicitly render PR template content if provided.
- Enhanced user interaction flow in `New-PSUAiPoweredPullRequest.ps1` by repeating the prompt until a valid choice is entered.
- Added stricter error handling for missing keys in AI response within `New-PSUAiPoweredPullRequest.ps1`.
- Trimmed remote URL value before provider matching in both submit and draft PR logic in `New-PSUAiPoweredPullRequest.ps1`.

### Changed
- Updated `New-PSUAiPoweredPullRequest.ps1` to use generic “AI assistance” instead of “Gemini AI”.
- Improved warning message in `Update-PSUChangeLog.ps1` to prefix with module name for better context.
- Refined PR template handling in `New-PSUAiPoweredPullRequest.ps1` to ensure template is used only if the path is specified and valid.
- Changed logic in `New-PSUAiPoweredPullRequest.ps1` so PR template usage and verbose messaging are more robust.
- Adjusted clipboard copy logic in `New-PSUAiPoweredPullRequest.ps1` to only copy the title and description together.
- Refactored user choice prompt and processing in `New-PSUAiPoweredPullRequest.ps1` for clarity and correctness.
- Improved provider detection in `New-PSUAiPoweredPullRequest.ps1` to use trimmed remote URLs consistently.
## [1.0.19] - 20th October 2025
### Added
- Support for `-ReturnJsonResponse` switch in `Invoke-PSUPromptOnPerplexityAi` to enforce JSON-only responses with strict formatting rules and examples included in the prompt.

### Changed
- Enhanced prompt construction in `Invoke-PSUPromptOnPerplexityAi` to instruct the Perplexity API to return a single, valid JSON object without any surrounding text, commentary, or markdown formatting.
- Improved error handling in `Invoke-PSUPromptOnPerplexityAi` to throw an error if no content is received from the Perplexity API.
## [1.0.18] - 20th October 2025
### Changed
- Modified default value assignment for `BaseBranch` parameter in `Get-PSUAiPoweredGitChangeSummary.ps1` to suppress error output and correctly extract the branch name by replacing the prefix `refs/remotes/origin/` instead of relying on `Split-Path` alone.
## [1.0.17] - 19th October 2025
### Changed
- Updated `Invoke-PSUAiPrompt` to include parameter validation, verbose logging, and improved error handling.
- Added comprehensive comment-based help to `Invoke-PSUAiPrompt` including .SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE, .OUTPUTS, and .NOTES sections.
- Updated `Update-PSUChangeLog` to include parameter descriptions, .OUTPUTS, and .NOTES sections in the comment-based help.
- Changed `Update-PSUModuleVersion` to `Update-OMGModuleVersion` in `Update-PSUChangeLog`.

## [1.0.16] - 19th October 2025
### Added
- Added parameter display output in `New-PSUAiPoweredPullRequest.ps1` for `FeatureBranch`, `BaseBranch`, `PullRequestTemplatePath`, and `CompleteOnApproval` to improve user feedback.

### Changed
- Removed the `ApiKeyGemini` parameter and related environment variable usage from `Get-PSUAiPoweredGitChangeSummary.ps1`.
- Replaced calls from `Invoke-PSUPromptOnGeminiAi` to the new generic `Invoke-PSUAiPrompt` in `Get-PSUAiPoweredGitChangeSummary.ps1`, `Invoke-PSUGitCommit.ps1`, and `New-PSUAiPoweredPullRequest.ps1` to generalize AI prompt invocation.
- Updated default branch retrieval syntax in `New-PSUAiPoweredPullRequest.ps1` to use regex replacement for cleaner base branch name.
- Replaced `PullRequestTemplate` parameter with `PullRequestTemplatePath` in `New-PSUAiPoweredPullRequest.ps1` for clarity and consistency.
- Removed all references to Gemini AI-specific API keys and usage from public functions to decouple from specific AI service.
- Enhanced `New-PSUAiPoweredPullRequest.ps1` to optionally update `ChangeLog.md` and commit changes before generating the pull request summary using AI.
- Adjusted internal logic in `New-PSUAiPoweredPullRequest.ps1` to test and read the pull request template file from the new `PullRequestTemplatePath` parameter.
## [1.0.15] - 19th October 2025
### Added
- Added parameter display output for `FeatureBranch`, `BaseBranch`, `PullRequestTemplatePath`, and `CompleteOnApproval` in `New-PSUAiPoweredPullRequest.ps1`.

### Changed
- Replaced all calls to `Invoke-PSUPromptOnGeminiAi` with the new `Invoke-PSUAiPrompt` in `Get-PSUAiPoweredGitChangeSummary.ps1`, `Invoke-PSUGitCommit.ps1`, and `New-PSUAiPoweredPullRequest.ps1`.
- Updated the default value calculation of `BaseBranch` in `New-PSUAiPoweredPullRequest.ps1` to correctly extract the branch name using a regex replace.
- Renamed parameter from `PullRequestTemplate` to `PullRequestTemplatePath` in `New-PSUAiPoweredPullRequest.ps1` and updated all references accordingly.
- Simplified parameter requirements in `Invoke-PSUGitCommit.ps1` by removing environment variable dependency `$env:API_KEY_GEMINI`.
- Improved commit message generation in `Invoke-PSUGitCommit.ps1` to use `Invoke-PSUAiPrompt` without requiring an API key argument.
- Enhanced error handling and JSON parsing consistency in AI prompt responses across affected scripts.
## [1.0.14] - 17th October 2025
### Changed
- Added `Start-Sleep -Seconds 3` to `New-PSUAiPoweredPullRequest` to ensure the changelog update completes before proceeding.

## [1.0.13] - 17th October 2025
### Added
- Parameter `AllGitChanges` to `Update-PSUChangeLog` to include all Git changes, including non-PowerShell files.

### Changed
- Modified `Update-PSUChangeLog` to process multiple modules based on Git changes.
- Updated `Update-PSUChangeLog` to detect module changes and prompt the user for confirmation before updating the changelog for each module.
- Updated `Update-PSUChangeLog` to check if a changelog entry already exists for the current module version and prompt to bump the module version.
- Refactored `Update-PSUChangeLog` to improve error handling and logging.
- Modified `New-PSUAiPoweredPullRequest` to call `Invoke-PSUGitCommit` if the user chooses to update the changelog.
- Changed the `ModuleName` parameter in `Update-PSUChangeLog` to be optional.

## [1.0.12] - 16th October 2025
### Added
- `Write-ColorOutput` (Private): Outputs a message with specified color to the console.
- `Write-ErrorMsg` (Private): Displays an error message in red color.
- `Write-Info` (Private): Displays an informational message in yellow color.
- `Write-Step` (Private): Displays a step header message in cyan color.
- `Write-Success` (Private): Displays a success message in green color.
- `Set-PSUAzureOpenAIEnvironment` (Public): Automated Azure OpenAI Service setup and environment variable configuration.

## [1.0.11] - 8th October 2025
### Changes:
- `Set-PSUAzureOpenAIEnvironment`: This function was added to set the environment configuration for **Azure OpenAI** interactions. This likely configures the necessary environment variables

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
