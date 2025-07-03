# Changelog

All notable changes to the OMG.PSUtilities module will be documented in this file.

## [1.0.14] - 2025-07-04
### Added
- `Invoke-PSUPromtAI`: 🤖 Invokes an AI-powered prompt and returns the response!

## [1.0.13] - 2025-07-03
### Added
- `Export-PSUExcel`: 📊 Converts an array of objects to a styled Excel file with advanced formatting, backup, and pipeline support.
- `Find-PSUFilesContainingText`: 🔍 Searches files for a specific text string.
- `Get-PSUAzToken`: 🔐 Retrieves an Azure access token for a specified resource.
- `Get-PSUConnectedWifiInfo`: 📶 Returns only the connected Wi-Fi's SSID, signal strength, private IPv4 address, band, and public IP address.
- `Get-PSUInstalledSoftware`: 🗃️ Lists installed software on the system, with optional filtering.
- `Get-PSUUserSession`: 👤 Lists currently logged-in users and their sessions.
- `New-PSUHTMLReport`: 📝 Creates an HTML report as a PowerShell object.
- `Remove-PSUUserSession`: 🚪 Logs off selected user sessions by session ID.
- `Send-PSUHTMLReport`: 📧 Sends HTML reports via email.
- `Send-PSUTeamsMessage`: 💬 Sends a message to a Microsoft Teams channel via webhook.
- `Set-PSUUserEnvironmentVariable`: ⚙️ Sets or updates a user environment variable.
- `Test-PSUAzConnection`: 🌩️ Checks if an active Azure session exists.
- `Test-PSUInternetConnection`: 🌍 Tests general internet connectivity.
- `Uninstall-PSUInstalledSoftware`: 🗑️ Uninstalls software objects piped in from Get-PSUInstalledSoftware.
- Improved comment-based help and parameter documentation for all new functions.
- Added LICENSE file with MIT License.

## [1.0.0] - 2025-07-03
### Added
- Initial release of OMG.PSUtilities module.