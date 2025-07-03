# OMG.PSUtilities

A PowerShell module providing reusable utility functions for file, text, Azure, reporting, and environment operations.

## ✨ Features

| Function                          | Description                                                                 |
|-----------------------------------|-----------------------------------------------------------------------------|
| `ConvertTo-PSUExcelFile`          | 📊 Converts an array of objects to a styled Excel file.                     |
| `Find-PSUFilesContainingText`     | 🔍 Searches files for a specific text string.                               |
| `Get-PSUAzToken`                  | 🔐 Retrieves an Azure access token for a specified resource.                |
| `New-PSUHTMLReport`               | 📝 Creates an HTML report as a PowerShell object.                           |
| `Send-PSUHTMLReport`              | 📧 Sends HTML reports via email.                                            |
| `Set-PSUUserEnvironmentVariable`  | ⚙️ Sets or updates a user environment variable.                             |
| `Test-PSUAzConnection`            | 🌩️ Checks if an active Azure session exists.                                |
| `Test-PSUInternetConnection`      | 🌍 Tests general internet connectivity.                                     |

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
Get-Help ConvertTo-PSUExcelFile -Full
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