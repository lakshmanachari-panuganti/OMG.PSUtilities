# CHANGELOG

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