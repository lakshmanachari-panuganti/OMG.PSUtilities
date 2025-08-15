# OMG.PSUtilities.AzureDevOps

Interact with Azure DevOps APIs, pipelines, repos, and work items.

> Module version: 1.0.5 | Last updated: 2025-08-11

## 📋 Available Functions
| Function                        | Description                              |
|---------------------------------|----------------------------------------------|
| `New-PSUADOBug` | Creates a new Azure DevOps work item of type "Bug". Use this function to log and track software defects within your project. |
| `New-PSUADOPullRequest` | Initiates a new pull request in Azure DevOps. This function helps automate the process of code review and merging changes between branches. |
| `New-PSUADOSpike` | Creates a new "Spike" work item in Azure DevOps. Use this function to document research tasks or investigations required to resolve uncertainties in your project. |
| `New-PSUADOTask` | Adds a new "Task" work item to Azure DevOps. This function is used to break down user stories or bugs into actionable development tasks. |
| `New-PSUADOUserStory` | Generates a new "User Story" work item in Azure DevOps. Use this function to capture requirements or features from the end-user perspective. |
| `Get-PSUADOPipeline` | Retrieves Azure DevOps pipeline information and details |
| `Get-PSUADOPipelineBuild` | Gets details about specific Azure DevOps pipeline builds |
| `Get-PSUADOPipelineLatestRun` | Retrieves the latest run information for Azure DevOps pipelines |
| `Get-PSUADOProjectList` | Lists all projects in an Azure DevOps organization |
| `Get-PSUADOPullRequest` | Gets information about Azure DevOps pull requests |
| `Get-PSUADOPullRequestInventory` | Provides an inventory of pull requests across repositories |
| `Get-PSUADORepoBranchList` | Lists all branches in Azure DevOps repositories |
| `Get-PSUADORepositories` | Retrieves a list of repositories in Azure DevOps projects |
| `Get-PSUADOVariableGroupInventory` | Gets an inventory of variable groups across Azure DevOps projects |

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