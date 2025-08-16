# CHANGELOG

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