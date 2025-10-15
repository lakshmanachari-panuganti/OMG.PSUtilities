# OMG.PSUtilities.AzureDevOps

Interact with Azure DevOps APIs, pipelines, repos, and work items.

> Module version: 1.0.9 | Last updated: 15th October 2025

## 📋 Available Functions (26 Total)

### Pull Request Management
| Function                        | Description                              |
|---------------------------------|----------------------------------------------|
| `Approve-PSUADOPullRequest` | Approves a pull request in Azure DevOps using REST API |
| `Complete-PSUADOPullRequest` | Completes (merges) a pull request in Azure DevOps using REST API |
| `Get-PSUADOPullRequest` | Retrieves pull requests from Azure DevOps repositories within a project |
| `Get-PSUADOPullRequestInventory` | Retrieves all active pull requests from accessible Azure DevOps repositories across all projects in the organization |
| `New-PSUADOPullRequest` | Creates a pull request in Azure DevOps using REST API |

### Pipeline Operations
| Function                        | Description                              |
|---------------------------------|----------------------------------------------|
| `Get-PSUADOPipeline` | Retrieves Azure DevOps pipelines for a specified project or by pipeline ID |
| `Get-PSUADOPipelineBuild` | Get details about a specific Azure DevOps pipeline build |
| `Get-PSUADOPipelineLatestRun` | Gets the latest Azure DevOps pipeline run information using pipeline ID or URL |

### Project & Repository Management
| Function                        | Description                              |
|---------------------------------|----------------------------------------------|
| `Get-PSUADOProjectList` | Retrieves the list of Azure DevOps projects within the specified organization |
| `Get-PSUADORepoBranchList` | Retrieves a list of branches for a specified Azure DevOps repository |
| `Get-PSUADORepositories` | Retrieves all repositories from Azure DevOps for a given organization and project |
| `Invoke-PSUADORepoClone` | Clones an Azure DevOps repository to a local directory |

### Work Item Management
| Function                        | Description                              |
|---------------------------------|----------------------------------------------|
| `Get-PSUADOWorkItem` | Retrieves work item details from Azure DevOps by work item ID |
| `New-PSUADOBug` | Creates a new bug work item in Azure DevOps |
| `New-PSUADOSpike` | Creates a new spike work item in Azure DevOps |
| `New-PSUADOTask` | Creates a new task work item in Azure DevOps and optionally links it to a parent work item |
| `New-PSUADOUserStory` | Creates a new user story in Azure DevOps |
| `Set-PSUADOBug` | Updates an existing bug work item in Azure DevOps |
| `Set-PSUADOSpike` | Updates an existing spike work item in Azure DevOps |
| `Set-PSUADOTask` | Updates an existing task work item in Azure DevOps |
| `Set-PSUADOUserStory` | Updates an existing user story work item in Azure DevOps |

### Variable & Variable Group Management
| Function                        | Description                              |
|---------------------------------|----------------------------------------------|
| `Get-PSUADOVariableGroupInventory` | Retrieves an inventory of Azure DevOps variable groups across projects |
| `New-PSUADOVariable` | Creates a new variable in an Azure DevOps variable group |
| `New-PSUADOVariableGroup` | Creates a new variable group in Azure DevOps |
| `Set-PSUADOVariable` | Updates an existing variable in an Azure DevOps variable group |
| `Set-PSUADOVariableGroup` | Updates an existing variable group in Azure DevOps |

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

# Clone a repository
Invoke-PSUADORepoClone -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -Repository "myrepo" -DestinationPath "C:\Code\myrepo" -PAT $token
```

### Pull Request Management
```powershell
# Get pull request details
Get-PSUADOPullRequest -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -Repository "myrepo" -PAT $token

# Create a pull request
New-PSUADOPullRequest -SourceBranch "feature/my-feature" -TargetBranch "main" -Title "Add new feature" -Description "Detailed description" -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -Repository "myrepo" -PAT $token

# Approve a pull request
Approve-PSUADOPullRequest -PullRequestId 123 -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -Repository "myrepo" -PAT $token

# Complete (merge) a pull request
Complete-PSUADOPullRequest -PullRequestId 123 -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -Repository "myrepo" -PAT $token

# Get pull request inventory
Get-PSUADOPullRequestInventory -Organization "OmgItSolutions" -PAT $token
```

### Work Item Management
```powershell
# Get work item details
Get-PSUADOWorkItem -WorkItemId 12345 -Organization "OmgItSolutions" -PAT $token

# Create work items
New-PSUADOBug -Title "Bug title" -Description "Bug description" -Project "MyProject" -Organization "OmgItSolutions" -PAT $token
New-PSUADOTask -Title "Task title" -Description "Task description" -Project "MyProject" -Organization "OmgItSolutions" -PAT $token
New-PSUADOUserStory -Title "User story" -Description "Story description" -Project "MyProject" -Organization "OmgItSolutions" -PAT $token
New-PSUADOSpike -Title "Spike title" -Description "Research description" -Project "MyProject" -Organization "OmgItSolutions" -PAT $token

# Update work items
Set-PSUADOBug -WorkItemId 12345 -Title "Updated bug title" -State "Active" -Organization "OmgItSolutions" -PAT $token
Set-PSUADOTask -WorkItemId 12346 -Title "Updated task" -State "Closed" -Organization "OmgItSolutions" -PAT $token
Set-PSUADOUserStory -WorkItemId 12347 -Title "Updated story" -State "Resolved" -Organization "OmgItSolutions" -PAT $token
```

### Variable & Variable Group Management
```powershell
# Get variable group inventory
Get-PSUADOVariableGroupInventory -Organization "OmgItSolutions" -Project "PSUtilities Azure DevOps" -PAT $token

# Create variable group
New-PSUADOVariableGroup -Name "MyVarGroup" -Description "Group description" -Project "MyProject" -Organization "OmgItSolutions" -PAT $token

# Create variable in a group
New-PSUADOVariable -GroupName "MyVarGroup" -Name "MyVariable" -Value "MyValue" -Project "MyProject" -Organization "OmgItSolutions" -PAT $token

# Update variable
Set-PSUADOVariable -GroupName "MyVarGroup" -Name "MyVariable" -Value "UpdatedValue" -Project "MyProject" -Organization "OmgItSolutions" -PAT $token

# Update variable group
Set-PSUADOVariableGroup -GroupName "MyVarGroup" -Description "Updated description" -Project "MyProject" -Organization "OmgItSolutions" -PAT $token
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