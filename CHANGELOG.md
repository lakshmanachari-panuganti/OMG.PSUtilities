# CHANGELOG

## [1.0.19] - 2025-07-15
- Initiated development from the ground up to create the first release of a wrapper module for:
  - OMG.PSUtilities.ActiveDirectory
  - OMG.PSUtilities.VSphere
  - OMG.PSUtilities.AI
  - OMG.PSUtilities.AzureCore
  - OMG.PSUtilities.AzureDevOps
  - OMG.PSUtilities.ServiceNow
  - OMG.PSUtilities.Core

## [1.0.18] - 2025-07-05
Resolved a bugs and renamed Ask-PSUAi --> Start-PSUAiChat

## [1.0.17] - 2025-07-05
Resolved few bugs!

## [1.0.15] - 2025-07-05
### Added
- `Start-PSUAiChat`: 💬 Interactive Gemini 2.0 Flash chatbot using Google's Generative Language API. 
Opens a PowerShell-based chat session with Gemini AI.

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