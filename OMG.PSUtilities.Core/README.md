# OMG.PSUtilities.Core

General purpose PowerShell utilities and system-level tools.

> Module version: 1.0.8 | Last updated: 19th August 2025

## 📋 Available Functions

| Function | Description |
|----------|-------------|
| `Approve-PSUGithubPullRequest` | Approves a pull request in GitHub using REST API |
| `Approve-PSUPullRequest` | Approves a pull request in GitHub or Azure DevOps automatically based on git remote |
| `Complete-PSUPullRequest` | Completes (merges) a pull request in GitHub or Azure DevOps automatically based on git remote |
| `Export-PSUExcel` | Converts an array of objects to a styled Excel file |
| `Find-PSUFilesContainingText` | Searches files for a specific text string |
| `Get-PSUConnectedWifiInfo` | Gets details of the currently connected Wi-Fi network |
| `Get-PSUFunctionCommentBasedHelp` | Pulls out a specific help section (like .SYNOPSIS or .EXAMPLE) from a PowerShell script, useful for reading documentation automatically |
| `Get-PSUGitFileChangeMetadata` | Gets metadata about file changes between two Git branches |
| `Get-PSUInstalledSoftware` | Lists installed software on the system |
| `Get-PSUUserEnvironmentVariable` | Gets one or more user environment variables |
| `Get-PSUUserSession` | Retrieves information about active user sessions |
| `New-PSUGithubPullRequest` | Creates a pull request in GitHub using REST API |
| `New-PSUHTMLReport` | Creates an HTML report as PowerShell object |
| `Remove-PSUUserEnvironmentVariable` | Removes one or more user environment variables |
| `Remove-PSUUserSession` | Logs off selected user sessions |
| `Resolve-PSUGitMergeConflict` | Helps resolve Git merge conflicts (Work in Progress) |
| `Send-PSUHTMLReport` | Sends HTML reports that are created with New-PSUHTMLReport function |
| `Send-PSUTeamsMessage` | Sends a message to a Microsoft Teams channel via webhook |
| `Set-PSUUserEnvironmentVariable` | Sets or updates a user environment variable |
| `Test-PSUInternetConnection` | Tests general internet connectivity |
| `Uninstall-PSUInstalledSoftware` | Removes installed software from the system |

## 📦 Installation

```powershell
Install-Module -Name OMG.PSUtilities.Core -Scope CurrentUser -Repository PSGallery
```

## 📖 Usage Examples

### File and Text Operations
```powershell
# Search for text in files
Find-PSUFilesContainingText -SearchText "function" -Path "C:\Scripts"

# Export data to Excel
$data | Export-PSUExcel -FilePath "C:\Reports\MyReport.xlsx"
```

### Git Operations
```powershell
# Get Git file change metadata
Get-PSUGitFileChangeMetadata -RepositoryPath "C:\MyRepo"

# Resolve Git merge conflicts
Resolve-PSUGitMergeConflict -ConflictFile "myfile.txt"
```

### System Information
```powershell
# Get installed software
Get-PSUInstalledSoftware | Where-Object Name -like "*Office*"

# Check WiFi connection
Get-PSUConnectedWifiInfo

# Test internet connection
Test-PSUInternetConnection
```

### Environment Variables
```powershell
# Set user environment variable
Set-PSUUserEnvironmentVariable -Name "MyVar" -Value "MyValue"

# Get user environment variable
Get-PSUUserEnvironmentVariable -Name "MyVar"

# Remove user environment variable
Remove-PSUUserEnvironmentVariable -Name "MyVar"
```

### User Sessions
```powershell
# Get active user sessions
Get-PSUUserSession

# Remove user session
Remove-PSUUserSession -SessionId 2
```

### Reporting and Communication
```powershell
# Create HTML report
New-PSUHTMLReport -Data $myData -Title "System Report"

# Send HTML report
Send-PSUHTMLReport -ReportPath "C:\Reports\report.html" -EmailTo "admin@company.com"

# Send Teams message
Send-PSUTeamsMessage -WebhookUrl $teamsUrl -Message "Deployment completed successfully"
```

### Documentation
```powershell
# Get function help documentation
Get-PSUFunctionCommentBasedHelp -FunctionPath "C:\Scripts\MyFunction.ps1" -HelpType SYNOPSIS
```

### Software Management
```powershell
# Uninstall software
Uninstall-PSUInstalledSoftware -SoftwareName "Adobe Reader"
```

## 🔗 Links

- [GitHub Repository](https://github.com/lakshmanachari-panuganti/OMG.PSUtilities)
- [PowerShell Gallery](https://www.powershellgallery.com/packages/OMG.PSUtilities.Core)
- [Documentation](https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/wiki)

## 📝 Requirements

- PowerShell 5.1 or higher
- Windows PowerShell or PowerShell Core

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.