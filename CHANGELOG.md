# Changelog

All notable changes to the OMG.PSUtilities module will be documented in this file.

## [1.0.0] - 2025-07-03
### Added
- Initial release of OMG.PSUtilities module.
- Added the following functions:
  - `ConvertTo-PSUExcelFile`: 📊 Converts an array of objects to a styled Excel file.
  - `Find-PSUFilesContainingText`: 🔍 Searches files for a specific text string.
  - `Get-PSUAzToken`: 🔐 Retrieves an Azure access token for a specified resource.
  - `New-PSUHTMLReport`: 📝 Creates an HTML report as a PowerShell object.
  - `Send-PSUHTMLReport`: 📧 Sends HTML reports via email.
  - `Set-PSUUserEnvironmentVariable`: ⚙️ Sets or updates a user environment variable.
  - `Test-PSUAzConnection`: 🌩️ Checks if an active Azure session exists.
  - `Test-PSUInternetConnection`: 🌍 Tests general internet connectivity.
- Added comment-based help content (synopsis, description, parameters, examples, notes) to all public functions.
- Updated README.md to use function synopses as descriptions and prefixed each with a relevant emoji.
- Added LICENSE file with