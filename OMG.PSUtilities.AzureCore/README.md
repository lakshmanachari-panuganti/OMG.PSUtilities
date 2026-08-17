# OMG.PSUtilities.AzureCore

Core Azure-related scripting, including identity and subscription management.

> Module version: 1.1.0 | Last updated: 26th July 2026

## 📋 Available Functions

| Function                | Description                                                                    |
|-------------------------|--------------------------------------------------------------------------------|
| `Get-PSUAzToken`        | Retrieves an Azure access token for a specified resource                       |
| `Get-PSUk8sPodLabel`    | Gets pod labels from AKS clusters in parallel with minimal kubectl overhead    |
| `Test-PSUAzConnection`  | Checks if an active Azure session exists                                       |

## 📦 Installation

```powershell
Install-Module -Name OMG.PSUtilities.AzureCore -Scope CurrentUser -Repository PSGallery
```

## 📖 Usage Examples

```powershell
# Get Azure access token for management API
Get-PSUAzToken -Resource "https://management.azure.com/"

# Get Azure access token for Microsoft Graph
Get-PSUAzToken -Resource "https://graph.microsoft.com/"

# Test Azure connection
Test-PSUAzConnection

# Get pod labels from all AKS clusters
Get-PSUk8sPodLabel

# Get pod labels from production clusters only
Get-PSUk8sPodLabel -ClusterFilter "*prod*" -ThrottleLimit 15
```

## 🔗 Links

- [GitHub Repository](https://github.com/lakshmanachari-panuganti)
- [PowerShell Gallery](https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureCore)
- [LinkedIn](https://www.linkedin.com/in/lakshmanachari-panuganti/)

## 📝 Requirements

- PowerShell 7.0 or higher (PowerShell 7 / Core edition only; Windows PowerShell 5.1 is not supported)
- `OMG.PSUtilities.Core` and `Az.Accounts` — required, installed automatically with this module
- Appropriate Azure permissions

Optional, needed only by specific commands and reported with actionable guidance when absent:

| Dependency | Required by |
| --- | --- |
| `Microsoft.Graph.*` | `Invoke-PSUAzureAppRegAudit` |
| `kubectl` | `Get-PSUk8sPodLabel` |
| `ThreadJob` | `Get-PSUk8sPodLabel` |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License. See [LICENSE](../LICENSE) for the full text.