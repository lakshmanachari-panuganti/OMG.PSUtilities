# OMG.PSUtilities.AzureDevOps

Interact with Azure DevOps APIs, pipelines, repos, and work items.

> Module version: 1.0.8 | Last updated: 19th August 2025

## 📋 Available Functions
| Function                        | Description                              |
|---------------------------------|----------------------------------------------|
| `Approve-PSUADOPullRequest` | Approves a pull request in Azure DevOps using REST API |
| `Complete-PSUADOPullRequest` | Completes (merges) a pull request in Azure DevOps using REST API |
| `Get-PSUADOPipeline` | Retrieves Azure DevOps pipelines for a specified project or by pipeline ID |
| `Get-PSUADOPipelineBuild` | Get details about a specific Azure DevOps pipeline build |
| `Get-PSUADOPipelineLatestRun` | Gets the latest Azure DevOps pipeline run information using pipeline ID or URL |
| `Get-PSUADOProjectList` | Retrieves the list of Azure DevOps projects within the specified organization |
| `Get-PSUADOPullRequest` | Retrieves pull requests from Azure DevOps repositories within a project |
| `Get-PSUADOPullRequestInventory` | Retrieves all active pull requests from accessible Azure DevOps repositories across all projects in the organization |
| `Get-PSUADORepoBranchList` | Retrieves a list of branches for a specified Azure DevOps repository |
| `Get-PSUADORepositories` | Retrieves all repositories from Azure DevOps for a given organization and project |
| `Get-PSUADOVariableGroupInventory` | Retrieves an inventory of Azure DevOps variable groups across projects |
| `New-PSUADOBug` | Creates a new bug work item in Azure DevOps |
| `New-PSUADOPullRequest` | Creates a pull request in Azure DevOps using REST API |
| `New-PSUADOSpike` | Creates a new spike work item in Azure DevOps |
| `New-PSUADOTask` | Creates a new task work item in Azure DevOps and optionally links it to a parent work item |
| `New-PSUADOUserStory` | Creates a new user story in Azure DevOps |

## 📦 Installation

```powershell
Install-Module -Name OMG.PSUtilities.AzureDevOps -Scope CurrentUser -Repository PSGallery
```

## 📖 Usage Examples

### Pipeline Operations
```powershell
# Get pipeline information
Get-PSUADOPipeline -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -PAT $token

# Get latest pipeline run
Get-PSUADOPipelineLatestRun -PipelineId 123 -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -PAT $token

# Get pipeline build details
Get-PSUADOPipelineBuild -BuildId 456 -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -PAT $token
```

### Project and Repository Management
```powershell
# List all projects
Get-PSUADOProjectList -Organization "OmgItSolutions" -PAT $token

# Get repositories
Get-PSUADORepositories -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -PAT $token

# List repository branches
Get-PSUADORepoBranchList -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -Repository "myrepo" -PAT $token
```

### Pull Request Management
```powershell
# Get pull request details
Get-PSUADOPullRequest -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -Repository "myrepo" -PAT $token

# Get pull request inventory
Get-PSUADOPullRequestInventory -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -PAT $token
```

### Variable Groups
```powershell
# Get variable group inventory
Get-PSUADOVariableGroupInventory -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -PAT $token
```

## 🔐 Authentication

All functions require a Personal Access Token (PAT) for Azure DevOps authentication. You can:

1. Pass it directly via the `-PAT` parameter
2. Set it as an environment variable: `$env:PAT = "your-token-here"`

## 🔗 Links

- [GitHub Repository](https://github.com/lakshmanachari-panuganti/OMG.PSUtilities)
- [PowerShell Gallery](https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps)
- [Azure DevOps REST API Documentation](https://docs.microsoft.com/en-us/rest/api/azure/devops/)

## 📝 Requirements

- PowerShell 5.1 or higher
- Azure DevOps Personal Access Token
- Network access to Azure DevOps

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.