## [1.0.15] - 1st November 2025
### Added
- Added `LastModified` property to the `PSCredential` object returned by `Get-PSUCredentialFromManager.ps1`.

### Changed
- Added `-Clipboard` parameter to `Get-PSUCredentialFromManager.ps1` to allow copying the password to the clipboard.
- Updated `Get-PSUCredentialFromManager.ps1` to return a `PSCredential` object with added `LastModified` property.
- Added `PSU.CredentialManager.Credential` to the `PSTypeNames` of the credential object in `Get-PSUCredentialFromManager.ps1`.
- Added alias `fetchcred` for `Get-PSUCredentialFromManager.ps1`.
- Added alias `listcred` for `Get-PSUCredentialManagerInventory.ps1`.
- Added alias `setcred` for `Set-PSUCredentialToManager.ps1`.

## [1.0.14] - 31st October 2025
### Added
- `Get-PSUCredentialFromManager`: Retrieves a credential (username, password, comment) from Windows Credential Manager by target name. Works in any logon session using Windows API.
- `Get-PSUCredentialManagerInventory`: Lists all credential target names stored in Windows Credential Manager. Useful for inventory and audit.
- `Set-PSUCredentialToManager`: Stores a credential (username, password, comment) in Windows Credential Manager using Windows API. Supports both explicit username/password and `[PSCredential]` input. Works in any logon session.
- `Remove-PSUCredentialFromManager`: Deletes a credential from Windows Credential Manager by target name. Implements `-Confirm` with high impact for safe deletion.
## [1.0.13] - 26th October 2025
### Added
- `Send-PSUNotificationEmail--wip.ps1`: Initial implementation of `Send-PSUNotificationEmail` for sending richly formatted HTML email notifications, including pipeline failure details, dynamic tables, and action buttons.
- Support in `Get-PSUUserSession.ps1` for querying user sessions on remote computers using the `ComputerName` and `Credential` parameters.
- Support in `Remove-PSUUserSession.ps1` for logging off user sessions on remote computers via `ComputerName` and `Credential` parameters.
- New parameters (`ComputerName`, `Credential`) and enhanced documentation for `Get-PSUUserSession.ps1` and `Remove-PSUUserSession.ps1`.

### Changed
- `Get-PSUUserSession.ps1`: Output objects now include a `ComputerName` property for both local and remote queries.
- `Get-PSUUserSession.ps1`: Improved documentation with clearer parameter descriptions, examples, and more detailed notes.
- `Remove-PSUUserSession.ps1`: Enhanced logic to handle local vs. remote session logoff, including user feedback and error handling per computer.
- `Remove-PSUUserSession.ps1`: Improved parameter validation and updated documentation for clarity and consistency.
- Updated `.NOTES` and `.LINK` sections in both `Get-PSUUserSession.ps1` and `Remove-PSUUserSession.ps1` for documentation consistency.
## [1.0.12] - 19th October 2025
### Added
- New `Update-OMGModuleVersion` (Public) function to increment the version of a specified PowerShell module by Major, Minor, or Patch.

### Changed
- Updated module's `.psd1` manifest file and `plasterManifest.xml` file.

## [1.0.11] - 17th October 2025
### Added
- New `Update-OMGModuleVersion` (Public) cmdlet to update module version in `.psd1` and `plasterManifest.xml` files.

### Changed
- The `Update-OMGModuleVersion` cmdlet now validates module path and `.psd1` file existence.
- The `Update-OMGModuleVersion` cmdlet now updates the version in `plasterManifest.xml` if it exists.
- Improved error handling and output messages in `Update-OMGModuleVersion`.

## [1.0.10] - 8th October 2025

## [1.0.9] - 23rd August 2025
### Added
- `Get-PSUModule.ps1`: Introduces the `Get-PSUModule` function to detect a module by searching for `.psd1` or `.psm1` files up the directory tree. Returns module metadata (name, version, paths) for dynamic introspection and automation. Supports starting search from either `ScriptRoot` or a specific `ScriptPath`.

### Changed
- None

## [1.0.8] - 2025-08-19
### Changed
- Updated all 17+ public functions to comply with OMG.PSUtilities.StyleGuide.md standards
- Standardized comment-based help with ordinal date format (DDth month YYYY)
- Added comprehensive .OUTPUTS sections to all functions
- Corrected .LINK section ordering (GitHub → LinkedIn → PowerShell Gallery → Microsoft Docs)
- Enhanced documentation consistency and professional presentation across all Core module functions
- Functions updated include: Export-PSUExcel, Find-PSUFilesContainingText, Get-PSUConnectedWifiInfo, Get-PSUFunctionCommentBasedHelp, Get-PSUGitFileChangeMetadata, Get-PSUInstalledSoftware, Get-PSUUserEnvironmentVariable, Get-PSUUserSession, New-PSUHTMLReport, Remove-PSUUserEnvironmentVariable, Remove-PSUUserSession, Send-PSUHTMLReport, Send-PSUTeamsMessage, Set-PSUUserEnvironmentVariable, Test-PSUInternetConnection, Uninstall-PSUInstalledSoftware, and Resolve-PSUGitMergeConflict

## [1.0.7] - 2025-08-11
### Added
- **Send-PSUTeamsMessage**: Sends messages to Microsoft Teams channels via webhook integration
- **Test-PSUInternetConnection**: Tests internet connectivity and network status with detailed diagnostics

### Enhanced
- **Export-PSUExcel**: Improved performance and added support for custom styling options
- **Send-PSUHTMLReport**: Enhanced email delivery with attachment support

## [1.0.6] - 2025-08-05
### Added
- **New-PSUHTMLReport**: Creates professional HTML reports from PowerShell data with customizable templates
- **Send-PSUHTMLReport**: Sends HTML reports via email with embedded styling and attachments

### Fixed
- **Get-PSUUserSession**: Resolved issue with session enumeration on Windows 11
- **Remove-PSUUserSession**: Fixed permission handling for non-administrator users

## [1.0.5] - 2025-07-28
### Added
- **Get-PSUUserSession**: Retrieves information about active user sessions on local and remote systems
- **Remove-PSUUserSession**: Terminates user sessions with proper error handling
- **Get-PSUConnectedWifiInfo**: Gets detailed information about currently connected WiFi networks
- **Uninstall-PSUInstalledSoftware**: Removes installed software with validation and rollback capabilities

### Enhanced
- **Get-PSUInstalledSoftware**: Added filtering options and improved performance for large software inventories

## [1.0.4] - 2025-07-22
### Added
- **Export-PSUExcel**: Exports PowerShell objects to Excel files with advanced formatting and styling
- **Get-PSUInstalledSoftware**: Retrieves comprehensive list of installed software from multiple sources
- **Get-PSUUserEnvironmentVariable**: Gets user-specific environment variables with scope filtering
- **Set-PSUUserEnvironmentVariable**: Sets user environment variables with validation
- **Remove-PSUUserEnvironmentVariable**: Removes user environment variables safely

### Enhanced
- **Find-PSUFilesContainingText**: Improved search performance and added regex support
- **Get-PSUGitFileChangeMetadata**: Enhanced Git integration with better error handling

### Work in Progress
- **Resolve-PSUGitMergeConflict**: Initial implementation for automated Git merge conflict resolution (WIP)

## [1.0.3] - 2025-07-17
### Changed
- **Get-PSUFunctionCommentBasedHelp**: Renamed from Get-PSUFunctionHelpInfo.ps1 for better clarity
- **Get-PSUGitRepositoryChanges**: Fixed minor bug in file change detection

### Added
- **Find-PSUFilesContainingText**: Searches for files containing specific text patterns across directories
- **Get-PSUGitFileChangeMetadata**: Gets detailed metadata about file changes in Git repositories

## [1.0.0] - 2025-07-16
### Added
- Initial scaffolding for OMG.PSUtilities.Core module
- Basic module structure and build system
- Core utility functions foundation
