# OMG.PSUtilities.Core

General purpose PowerShell utilities and system-level tools.

> Module version: 1.0.4 | Last updated: 2025-08-11

## 📋 Available Functions

| Function | Description |
|----------|-------------|
| `Export-PSUExcel` | Exports PowerShell objects to Excel files with formatting and styling options |
| `Find-PSUFilesContainingText` | Searches for files containing specific text patterns across directories |
| `Get-PSUConnectedWifiInfo` | Retrieves information about currently connected WiFi networks |
| `Get-PSUFunctionCommentBasedHelp` | Extracts specific help sections (like .SYNOPSIS or .EXAMPLE) from PowerShell scripts for automated documentation |
| `Get-PSUGitFileChangeMetadata` | Gets metadata about file changes in a Git repository |
| `Get-PSUInstalledSoftware` | Retrieves a list of installed software on the system |
| `Get-PSUUserEnvironmentVariable` | Gets user-specific environment variables |
| `Get-PSUUserSession` | Retrieves information about active user sessions |
| `New-PSUHTMLReport` | Creates HTML reports from PowerShell data |
| `Remove-PSUUserEnvironmentVariable` | Removes user-specific environment variables |
| `Remove-PSUUserSession` | Terminates user sessions |
| `Resolve-PSUGitMergeConflict` | Helps resolve Git merge conflicts (Work in Progress) |
| `Send-PSUHTMLReport` | Sends HTML reports via email or other methods |
| `Send-PSUTeamsMessage` | Sends messages to Microsoft Teams channels |
| `Set-PSUUserEnvironmentVariable` | Sets user-specific environment variables |
| `Test-PSUInternetConnection` | Tests internet connectivity and network status |
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