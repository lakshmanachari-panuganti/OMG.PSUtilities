# OMG.PSUtilities

A PowerShell module providing reusable utility functions for file, text, Azure, reporting, and environment operations.

## Features

- **ConvertTo-PSUExcelFile**  
  Converts data to an Excel file.

- **Find-PSUFilesContainingText**  
  Search for files containing specific text, with options to filter by extension, exclude certain file types, and control recursion.

- **Get-PSUAzToken**  
  Retrieves an Azure authentication token.

- **New-PSUHTMLReport**  
  Generates an HTML report from data.

- **Send-PSUHTMLReport**  
  Sends an HTML report via email.

- **Set-PSUUserEnvironmentVariable**  
  Sets a user environment variable.

- **Test-PSUAzConnection**  
  Tests connectivity to Azure.

- **Test-PSUInternetConnection**  
  Tests general internet connectivity.

## Installation

```powershell
# Install from the PowerShell Gallery
Install-Module -Name OMG.PSUtilities

# Or clone/download this repository and import the module
Import-Module "$Path\OMG.PSUtilities.psm1"
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