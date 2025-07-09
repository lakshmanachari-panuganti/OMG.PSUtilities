# OMG.PSUtilities

A PowerShell module providing reusable utility functions for file, text, Azure, reporting, environment, and system operations.

## ✨ Features

| Function                          | Description                                                                 |
|------------------------------------|-----------------------------------------------------------------------------|
| `Start-PSUAiChat`                        | 💬 Interactive AI chatbot using Google's Generative Language API           |
| `Invoke-PSUPromtAI`                | 🤖 Invokes an AI-powered prompt and returns the response.                   |
| `Export-PSUExcel`                  | 📊 Exports an array of objects to a styled Excel file with advanced formatting, backup, and pipeline support. |
| `Find-PSUFilesContainingText`      | 🔍 Searches files for a specific text string.                               |
| `Get-PSUAzToken`                   | 🔐 Retrieves an Azure access token for a specified resource.                |
| `Get-PSUConnectedWifiInfo`         | 📶 Returns only the connected Wi-Fi's SSID, signal strength, private IPv4 address, band, and public IP address. |
| `Get-PSUInstalledSoftware`         | 🗃️ Lists installed software on the system, with optional filtering.         |
| `Get-PSUUserSession`               | 👤 Lists currently logged-in users and their sessions.                      |
| `New-PSUHTMLReport`                | 📝 Creates an HTML report as a PowerShell object.                           |
| `Remove-PSUUserSession`            | 🚪 Logs off selected user sessions by session ID.                           |
| `Send-PSUHTMLReport`               | 📧 Sends HTML reports via email.                                            |
| `Send-PSUTeamsMessage`             | 💬 Sends a message to a Microsoft Teams channel via webhook.                |
| `Set-PSUUserEnvironmentVariable`   | ⚙️ Sets or updates a user environment variable.                             |
| `Test-PSUAzConnection`             | 🌩️ Checks if an active Azure session exists.                                |
| `Test-PSUInternetConnection`       | 🌍 Tests general internet connectivity.                                     |
| `Uninstall-PSUInstalledSoftware`   | 🗑️ Uninstalls software objects piped in from Get-PSUInstalledSoftware.      |

---
## Installation

```powershell
# Install from the PowerShell Gallery
Install-Module -Name OMG.PSUtilities -Repository PSGallery -Scope CurrentUser

```

## Usage

### Find-PSUFilesContainingText

Search for files containing a specific string:

```powershell
Find-PSUFilesContainingText -SearchPath 'C:\Projects' -SearchText 'TODO'
```

#### Parameters

- `-SearchPath` (Required): Directory to search.
- `-SearchText` (Required): Text to search for in files.
- `-FileExtension`: Only search files with this extension (e.g., `ps1`).
- `-ExcludeExtensions`: Array of file extensions to exclude (default: `exe`, `dll`, `msi`, etc.).
- `-NoRecurse`: If specified, search only the top-level directory.

#### Example

```powershell
# Search recursively for 'password' in all .ps1 files, excluding binaries
Find-PSUFilesContainingText -SearchPath 'C:\Scripts' -SearchText 'password' -FileExtension 'ps1'
```

### Other Functions

Refer to the function help for usage examples:

```powershell
Get-Help Export-PSUExcel -Full
Get-Help Get-PSUAzToken -Full
Get-Help New-PSUHTMLReport -Full
Get-Help Send-PSUHTMLReport -Full
Get-Help Set-PSUUserEnvironmentVariable -Full
Get-Help Test-PSUAzConnection -Full
Get-Help Test-PSUInternetConnection -Full
```

---

## Contributing

Pull requests and suggestions are welcome!

## License

[MIT](LICENSE)

## Author

Lakshmanachari Panuganti

## Project

[https://github.com/lakshmanachari-panuganti/OMG.PSUtilities](https://github.com/lakshmanachari-panuganti/OMG.PSUtilities)