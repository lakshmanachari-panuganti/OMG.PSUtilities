# CHANGELOG

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