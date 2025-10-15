# CHANGELOG

## [1.0.9] - 15th October 2025
### Fixed
- **CRITICAL**: Fixed 18 functions with duplicate validation code in process{} blocks
  - Removed performance-degrading duplicate validations that ran per pipeline item
  - Corrected begin{}/process{} separation of concerns
  - Functions affected: Get-PSUADOProjectList, Get-PSUADORepositories, Get-PSUADORepoBranchList, Get-PSUADOWorkItem, New-PSUADOBug, New-PSUADOSpike, New-PSUADOTask, New-PSUADOUserStory, New-PSUADOVariable, New-PSUADOVariableGroup, Set-PSUADOBug, Set-PSUADOSpike, Set-PSUADOTask, Set-PSUADOUserStory, Set-PSUADOVariable, Set-PSUADOVariableGroup, New-PSUADOPullRequest, Invoke-PSUADORepoClone
- **CRITICAL**: Fixed syntax error in Get-PSUADOPullRequest.ps1 (duplicate try block causing parse error)
- **MEDIUM**: Added 4 missing functions to module manifest FunctionsToExport
  - New-PSUADOVariable
  - New-PSUADOVariableGroup
  - Set-PSUADOVariable
  - Set-PSUADOVariableGroup

### Changed
- Standardized code formatting to K&R brace style across all 26 functions
- Implemented `} else {` on same line convention throughout codebase
- Enhanced error handling consistency across all functions
- Improved parameter ordering compliance verification

### Added
- Format-AllPowerShellFiles.ps1 for automated code formatting with whitespace cleanup
- Trailing whitespace removal in code formatting process
- Excessive blank line removal (max 2 consecutive blank lines)
- .vscode/settings.json with PowerShell formatting rules
- BUG-FIX-SUMMARY-2025-01-15.md - Detailed bug analysis and fix documentation
- COMPREHENSIVE-REVIEW-2025-01-15.md - Complete module quality assessment
- COMPREHENSIVE-REVIEW-2025-01-15-FINAL.md - Final review after all fixes

### Documentation
- Enhanced Instructions-Validation-Pattern.md with:
  - Code Formatting Standard section with K&R brace style rules
  - Common Migration Mistakes section documenting duplicate code pattern
  - Enhanced verification checklist with formatting checks
  - Bug prevention guidelines
- Updated README.md with all 26 functions organized by category
- Added comprehensive usage examples for work items, variables, and variable groups

### Performance
- Eliminated duplicate validation overhead in pipeline processing
- Single-run validation in begin{} instead of per-item in process{}
- Optimized header creation (once per pipeline vs per item)

## [1.0.8] - 2025-08-19
### Changed
- Updated all public functions to comply with OMG.PSUtilities.StyleGuide.md standards
- Standardized comment-based help with ordinal date format (DDth month YYYY)
- Added comprehensive .OUTPUTS sections to all functions
- Corrected .LINK section ordering (GitHub → LinkedIn → PowerShell Gallery → Microsoft Docs)
- Enhanced documentation consistency and professional presentation across all Azure DevOps functions

## [1.0.7] - 2025-08-16
### Bug fix
`New-PSUADOPullRequest`: a minor Bug fixed for this function.

## [1.0.6] - 2025-08-15
### Added

`New-PSUADOBug`: Creates a new Azure DevOps work item of type "Bug". Use this function to log and track software defects within your project.

`New-PSUADOPullRequest`: Initiates a new pull request in Azure DevOps. This function helps automate the process of code review and merging changes between branches.

`New-PSUADOSpike`: Creates a new "Spike" work item in Azure DevOps. Use this function to document research tasks or investigations required to resolve uncertainties in your project.

`New-PSUADOTask`: Adds a new "Task" work item to Azure DevOps. This function is used to break down user stories or bugs into actionable development tasks.

`New-PSUADOUserStory`: Generates a new "User Story" work item in Azure DevOps. Use this function to capture requirements or features from the end-user perspective.


- Added these functions to `FunctionsToExport` and public functions.
- Filtering to exclude files ending with `--wip.ps1` when retrieving public and private functions.
- Functions to create work items in Azure DevOps.

### Changed
- Refactored `Get-PSUADOPullRequest` to allow retrieving pull requests from a specific repository or all repositories in a project. Added parameters for `RepositoryId`, `RepositoryName`, and `State`.
- Modified `Get-PSUADORepositories` to rename the `ProjectName` property to `Project`.

## [1.0.5] - 2025-08-11
### Added
- **Get-PSUADOPipeline**: Retrieves Azure DevOps pipeline information and details
- **Get-PSUADOPipelineBuild**: Gets details about specific Azure DevOps pipeline builds  
- **Get-PSUADOPipelineLatestRun**: Retrieves the latest run information for Azure DevOps pipelines
- **Get-PSUADOProjectList**: Lists all projects in an Azure DevOps organization
- **Get-PSUADOPullRequest**: Gets information about Azure DevOps pull requests
- **Get-PSUADOPullRequestInventory**: Provides an inventory of pull requests across repositories
- **Get-PSUADORepoBranchList**: Lists all branches in Azure DevOps repositories
- **Get-PSUADORepositories**: Retrieves a list of repositories in Azure DevOps projects
- **Get-PSUADOVariableGroupInventory**: Gets an inventory of variable groups across Azure DevOps projects

### Private Functions
- **ConvertTo-CapitalizedObject**: Internal utility for object property capitalization
- **Get-PSUAdoAuthHeader**: Internal utility for Azure DevOps authentication header generation

### Notes
- Initial release of OMG.PSUtilities.AzureDevOps module
- Comprehensive Azure DevOps REST API integration
- Support for pipelines, repositories, pull requests, and variable groups
- Built-in authentication handling with PAT support
