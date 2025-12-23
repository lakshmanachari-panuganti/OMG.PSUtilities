## [1.0.19] - 24th December 2025
### Added
- `Get-PSUADOVariableGroup` (Public): Retrieves Azure DevOps Variable Groups for a specified project, or by Variable Group ID or Name.

### Changed
- `Get-PSUADORepositories`: Updated `Install-Module` command in help documentation to include `-Repository PSGallery`.
- `Set-PSUADOVariableGroup` (Public): Refactored to accept pipeline input from `Get-PSUADOVariableGroup` for updating variable group metadata and variables.
- `Set-PSUADOVariableGroup`: Updated parameter set to use `InputObject` for a more object-oriented approach, streamlining updates.

### Removed
- Removed `Set-PSUADOVariable` cmdlet, which was used to update individual variables within a Variable Group.
## [1.0.18] - 26th October 2025
### Added
- `Invoke-PSUADOPipeline.ps1`: Public function `Invoke-PSUADOPipeline` to trigger an Azure DevOps pipeline by pipeline ID and branch.
- Support for specifying `Project`, `PipelineId`, optional `Branch`, `Organization`, and `PAT` parameters.
- Returns pipeline run details as a `[PSCustomObject]` including run ID, status, and web URL.
- Verbose output for parameter logging with sensitive data masking for `PAT`.
- Throws errors if required `Organization` or `PAT` are missing.
- Utilizes Azure DevOps REST API (`_apis/pipelines/{id}/runs`) for execution.
- Option to set `Organization` and `PAT` using `Set-PSUUserEnvironmentVariable`.

### Changed
- No changed entries.
## [1.0.17] - 20th October 2025
### Added

- Added `[ValidateNotNullOrEmpty()]` parameter validation for both `$SourceBranch` and `$TargetBranch` in `New-PSUADOPullRequest` to prevent empty branch values.

### Changed

- Removed an extraneous closing brace (`}`) from the verbose parameter output logic in `New-PSUADOPullRequest`.
- Improved parameter validation for `$TargetBranch` to handle cases where the remote HEAD reference is not available, ensuring the function is more robust in various Git states.

### Fixed

- Fixed potential null reference issue in parameter output logic by removing a misplaced closing brace.
## [1.0.16] - 20th October 2025
### Added
- Added `[ValidateNotNullOrEmpty()]` attribute to the `SourceBranch` parameter in `New-PSUADOPullRequest.ps1`.
- Added `[ValidateNotNullOrEmpty()]` attribute to the `TargetBranch` parameter in `New-PSUADOPullRequest.ps1`.

### Changed
- Removed an extraneous closing brace in the parameter validation loop in `New-PSUADOPullRequest.ps1`.
- Improved parameter validation logic by ensuring environment variable defaults for `SourceBranch` and `TargetBranch` are validated explicitly in `New-PSUADOPullRequest.ps1`.
## [1.0.15] - 19th October 2025
### Changed
- The `SourceBranch` and `TargetBranch` parameters in `New-PSUADOPullRequest` now default to the current Git branch and the remote HEAD branch, respectively.
- Added validation to ensure `SourceBranch` and `TargetBranch` are in the available Git branches.

## [1.0.14] - 19th October 2025
### Added
- Added validation of `SourceBranch` and `TargetBranch` against the available local git branches, ensuring they exist before creating the pull request.
- Added automatic conversion of simple branch names (e.g., `feature-x`) to full ref format (`refs/heads/feature-x`) before request creation.
- Added informative console output displaying pull request details such as source branch, target branch, repository identifier, title, and description.

### Changed
- Changed `SourceBranch` and `TargetBranch` parameter descriptions to accept branch names without the `refs/heads/` prefix (e.g., `feature/enhance-ui`, `main`).
- Removed strict validation requiring branch names to be in the `refs/heads/branch-name` format.
- Updated example default branch values to branch names without the `refs/heads/` prefix.
- Standardized branch naming internally to use the full ref format only after validating branch existence.
## [1.0.13] - 19th October 2025
### Added
- Added validation for `SourceBranch` and `TargetBranch` to accept branch names without the `refs/heads/` prefix.
- Added logic to retrieve available git branches and validate that provided branch names exist in the repository.
- Added automatic conversion of branch names to the full `refs/heads/branch-name` format before creating the pull request.
- Added informative `Write-Host` output to display pull request creation details including source branch, target branch, repository, title, and description.

### Changed
- Changed the `SourceBranch` and `TargetBranch` parameter documentation to reflect acceptance of branch names without the full ref prefix.
- Removed the `ValidateScript` checks enforcing branch names to start with `refs/heads/`.
- Updated example default values for `SourceBranch` and `TargetBranch` to use simple branch names (e.g., `"feature-x"` instead of `"refs/heads/feature-x"`).
## [1.0.12] - 17th October 2025
### Changed
- Changed validation for `$PullRequestId` parameter in `Approve-PSUADOPullRequest.ps1` and `Complete-PSUADOPullRequest.ps1` to use `ValidateRange` attribute.
- Changed validation for `$Id` parameter in `Get-PSUADOPipeline.ps1`, `Get-PSUADOWorkItem.ps1`, `New-PSUADOVariable.ps1`, `Set-PSUADOBug.ps1`, `Set-PSUADOSpike.ps1`, `Set-PSUADOTask.ps1`, `Set-PSUADOUserStory.ps1` and `Set-PSUADOVariableGroup.ps1` to use `ValidateRange` attribute.
- Added `ValidateNotNullOrEmpty` attribute to `$Project` parameter in `Get-PSUADORepositories.ps1`.
- Added `ValidateNotNullOrEmpty` attribute to `$Title`, `$Description`, `$ReproSteps`, `$State`, `$Severity`, `$AssignedTo`, `$AreaPath`, and `$IterationPath`, `$Tags` parameters in `Set-PSUADOBug.ps1`.
- Added validation for `$State` parameter in `Set-PSUADOBug.ps1` to check against available states.
- Changed `op` from `add` to `replace` for all parameters in `Set-PSUADOBug.ps1`.
- Added `ValidateNotNullOrEmpty` attribute to `$Title`, `$Description`, `$State`, `$AssignedTo`, `$AreaPath`, `$IterationPath`, `$Tags` and `$AcceptanceCriteria` parameters in `Set-PSUADOSpike.ps1`.
- Added validation for `$State` parameter in `Set-PSUADOSpike.ps1` to check against available states.
- Changed `op` from `add` to `replace` for all parameters in `Set-PSUADOSpike.ps1`.
- Added `ValidateNotNullOrEmpty` attribute to `$Title`, `$Description`, `$State`, `$Activity`, `$AssignedTo`, `$AreaPath`, and `$IterationPath`, `$Tags` parameters in `Set-PSUADOTask.ps1`.
- Added validation for `$State` parameter in `Set-PSUADOTask.ps1` to check against available states.
- Changed `op` from `add` to `replace` for all parameters in `Set-PSUADOTask.ps1`.
- Added `ValidateNotNullOrEmpty` attribute to `$Title`, `$Description`, `$State`, `$AssignedTo`, `$AreaPath`, `$IterationPath`, `$Tags` and `$AcceptanceCriteria` parameters in `Set-PSUADOUserStory.ps1`.
- Added `ValidateNotNullOrEmpty` attribute to `$VariableGroupName` parameter in `Set-PSUADOVariableGroup.ps1`.

## [1.0.11] - 16th October 2025
### Added
- Added `State` parameter to `New-PSUADOUserStory.ps1` to set the initial state of the user story.

### Changed
- Updated `New-PSUADOUserStory.ps1` and `Set-PSUADOUserStory.ps1` to include validation for the `State` parameter against available states.
- Updated `Set-PSUADOUserStory.ps1` to remove the `ValidateSet` attribute from the `State` parameter.

## [1.0.10] - 16th October 2025
### Added
- New `Get-PSUADOWorkItem.ps1` (Public): Retrieves a work item from Azure DevOps.
- New `Get-PSUADOWorkItemStates.ps1` (Public): Retrieves all available states for Azure DevOps work item types in a project.
- New `Invoke-PSUADORepoClone.ps1` (Public): Clones all repositories from an Azure DevOps project to a local directory.
- New `New-PSUADOBug.ps1` (Public): Creates a new bug work item in Azure DevOps.
- New `New-PSUADOSpike.ps1` (Public): Creates a new spike work item in Azure DevOps.
- New `New-PSUADOTask.ps1` (Public): Creates a new task work item in Azure DevOps.
- New `New-PSUADOVariable.ps1` (Public): Adds a variable to an existing Azure DevOps Variable Group.
- New `New-PSUADOVariableGroup.ps1` (Public): Creates a new Azure DevOps Variable Group.
- New `Set-PSUADOBug.ps1` (Public): Updates an existing bug in Azure DevOps.
- New `Set-PSUADOSpike.ps1` (Public): Updates an existing spike work item in Azure DevOps.
- New `Set-PSUADOTask.ps1` (Public): Updates an existing task in Azure DevOps.
- New `Set-PSUADOVariable.ps1` (Public): Updates an existing variable in an Azure DevOps Variable Group.
- New `Set-PSUADOVariableGroup.ps1` (Public): Updates an existing Azure DevOps Variable Group.

### Changed
- Updated `ConvertTo-CapitalizedObject.ps1` (Private) to ensure the function block is properly terminated.
- Improved error handling in `Get-PSUAdoAuthHeader.ps1` (Private) when the Azure DevOps PAT is missing.
- Made `Project` and `Repository` parameters mandatory in `Approve-PSUADOPullRequest.ps1` (Public).
- Replaced auto-detection logic for `Organization`, `Project`, and `Repository` with mandatory parameters in `Approve-PSUADOPullRequest.ps1` (Public).
- Addressed issue where profile APIs are hosted under `vssps.dev.azure.com` to `Approve-PSUADOPullRequest.ps1` (Public).
- Made `Project` and `Repository` parameters mandatory in `Complete-PSUADOPullRequest.ps1` (Public).
- Replaced auto-detection logic for `Organization`, `Project`, and `Repository` with mandatory parameters in `Complete-PSUADOPullRequest.ps1` (Public).
- Enhanced completion logic with source commit id in `Complete-PSUADOPullRequest.ps1` (Public).
- Added default value for the `Organization` parameter in `Get-PSUADOPipeline.ps1` (Public) to use `$env:ORGANIZATION`.
- Made the `Project` parameter mandatory in `Get-PSUADOPipeline.ps1` (Public).
- Added default value for the `Organization` parameter in `Get-PSUADOPipelineBuild.ps1` (Public) to use `$env:ORGANIZATION`.
- Added default value for the `Organization` parameter in `Get-PSUADOPipelineLatestRun.ps1` (Public) to use `$env:ORGANIZATION`.
- Added default value for the `Organization` parameter in `Get-PSUADOProjectList.ps1` (Public) to use `$env:ORGANIZATION`.
- Added default value for the `Organization` parameter in `Get-PSUADOPullRequest.ps1` (Public) to use `$env:ORGANIZATION`.
- Made the `Project` parameter mandatory in `Get-PSUADOPullRequest.ps1` (Public).
- Added default value for the `Organization` parameter in `Get-PSUADOPullRequestInventory.ps1` (Public) to use `$env:ORGANIZATION`.
- Made the `Project` parameter mandatory in `Get-PSUADORepoBranchList.ps1` (Public).
- Made `RepositoryId` and `RepositoryName` mandatory and created parameter sets in `Get-PSUADORepoBranchList.ps1` (Public).
- Added default value for the `Organization` parameter in `Get-PSUADORepositories.ps1` (Public) to use `$env:ORGANIZATION`.
- Added default value for the `Organization` parameter in `Get-PSUADOVariableGroupInventory.ps1` (Public) to use `$env:ORGANIZATION`.
- Added default value for the `Organization` parameter in `New-PSUADOBug.ps1` (Public) to use `$env:ORGANIZATION`.
- Made the `Project` parameter mandatory in `New-PSUADOBug.ps1` (Public).
- Added default value for the `Organization` parameter in `New-PSUADOPullRequest.ps1` (Public) to use `$env:ORGANIZATION`.
- Replaced auto-detection logic for `Organization`, `Project`, and `Repository` with mandatory parameters in `New-PSUADOPullRequest.ps1` (Public).
- Added default value for the `Organization` parameter in `New-PSUADOSpike.ps1` (Public) to use `$env:ORGANIZATION`.
- Made the `Project` parameter mandatory in `New-PSUADOSpike.ps1` (Public).
- Added default value for the `Organization` parameter in `New-PSUADOTask.ps1` (Public) to use `$env:ORGANIZATION`.
- Made the `Project` parameter mandatory in `New-PSUADOTask.ps1` (Public).
- Added default value for the `Organization` parameter in `New-PSUADOUserStory.ps1` (Public) to use `$env:ORGANIZATION`.
- Made the `Project` parameter mandatory in `New-PSUADOUserStory.ps1` (Public).

### Removed
- Removed `Set-PSUADOEnvVariable--wip.ps1` (Public) since this was work in progress and not finalized.

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
