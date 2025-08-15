# OMG.PSUtilities.AzureCore

Core Azure-related scripting, including identity and subscription management.

> Module version: 1.0.2 | Last updated: 2025-08-11

## 📋 Available Functions

| Function                              | Description                                 |
|----------------------------------------|---------------------------------------------|
| `Get-PSUAzAccountAccessInSubscriptions` | Retrieves account access details across Azure subscriptions |
| `Get-PSUk8sPodLabel`                    | Gets labels for Kubernetes pods                             |
| `Get-PSUAssignmentPrincipalId`          | Private. Resolves principal IDs for assignments             |
| `Get-PSUBatchDirectoryObjects`          | Private. Fetches directory objects in batches               |
| `Get-PSUGraphUser`                      | Private. Retrieves user information from Microsoft Graph    |
| `Get-PSURoleDefDetails`                 | Private. Gets details of role definitions                   |
| `Get-PSUTransitiveGroups`               | Private. Finds all transitive group memberships             |
| `Parse-PSUScopePath`                    | Private. Parses Azure scope paths                           |
| `Resolve-PSUPrincipalDisplayFromCache`  | Private. Resolves principal display names from cache        |
| `Test-AzCliLogin`                       | Private. Tests Azure CLI login status                       |
| `Get-PSUAzAccountAccessInSubscriptions2--wip` | Work in progress. Next-gen account access retrieval  |


| `Get-PSUAksWorkloadIdentityInventory`  | Retrieves AKS workload identity inventory   |
| `Get-PSUAzToken`                       | Retrieves an Azure access token             |
| `Test-PSUAzConnection`                 | Tests Azure connection                      |

## 📦 Installation

```powershell
Install-Module -Name OMG.PSUtilities.AzureCore -Scope CurrentUser -Repository PSGallery
```

## 📖 Usage Examples

```powershell
# Get AKS workload identity inventory
Get-PSUAksWorkloadIdentityInventory -SubscriptionId "xxxx-xxxx-xxxx-xxxx"

# Get Azure access token
Get-PSUAzToken -Resource "https://management.azure.com/"

# Test Azure connection
Test-PSUAzConnection -SubscriptionId "xxxx-xxxx-xxxx-xxxx"
```

## 🔗 Links

- [GitHub Repository](https://github.com/lakshmanachari-panuganti)
- [PowerShell Gallery](https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureCore)
- [LinkedIn](https://www.linkedin.com/in/lakshmanachari-panuganti/)

## 📝 Requirements

- PowerShell 5.1 or higher
- Azure PowerShell modules
- Appropriate Azure permissions

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the