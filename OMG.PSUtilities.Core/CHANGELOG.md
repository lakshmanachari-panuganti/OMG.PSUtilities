## [1.0.27] - 17th August 2026
### Security
- `Unlock-PSUTerraformStateAWS` (Public): redact ambient `AWS_SESSION_TOKEN` values from Terraform failure output in addition to access keys and secret keys.

### Tests
- Extended ambient AWS credential redaction coverage to include session tokens.

## [1.0.26] - 17th August 2026
### Fixed
- `Unlock-PSUTerraformStateAWS` (Public): redact AWS credentials from Terraform failure output on the default (no explicit `-AccessKey`/`-SecretKey`) path too, where ambient environment credentials could previously leak into thrown/logged errors unredacted.
- `Unlock-PSUTerraformStateAWS` (Public): treat a zero-length `SecureString` (e.g. an empty `Read-Host -AsSecureString` response) the same as an omitted credential instead of routing it through the explicit-credential path.

### Tests
- Replaced a non-discriminating verbose-stream assertion with a `Write-Host` argument check that actually fails if a credential value reaches console output.

## [1.0.25] - 16th August 2026
### Changed
- **Breaking:** `Unlock-PSUTerraformStateAWS` (Public): `-AccessKey` and `-SecretKey` now require `SecureString` values instead of plain `[string]`; callers passing plaintext strings will fail parameter binding.

### Security
- `Unlock-PSUTerraformStateAWS` (Public): require `SecureString` AWS credentials, convert them to temporarily-scoped process environment variables that are restored in `finally` after the Terraform operation completes, clear unmanaged conversion buffers immediately, and redact backend configuration and credentials from Terraform failures regardless of whether explicit credentials were supplied.

### Documentation
- Document secure interactive credential acquisition with `Read-Host -AsSecureString`.

### Tests
- Added focused SecureString parameter, acquisition guidance, native-boundary conversion, argv/console-output isolation, environment restoration, and error-redaction regressions.

## [1.0.24] - 16th August 2026
### Fixed
- `New-PSUGithubPullRequest` (Public): enable approval-gated auto-merge through GitHub's `enablePullRequestAutoMerge` GraphQL mutation instead of immediately merging through the REST endpoint.
- `Get-PSUGitFileChangeMetadata` (Public): report untracked files without staging them or otherwise changing the Git index.

### Tests
- Added focused GraphQL contract, `-WhatIf`, and Git index safety regressions.

## [1.0.23] - 15th August 2026
### Added
- `Complete-PSUGithubPullRequest` (Public): merge open GitHub pull requests with merge, squash, or rebase and optionally delete the source branch after a confirmed merge.
- `tests/OMG.PSUtilities.Core.Tests.ps1`: focused coverage for provider dispatch, dependency guidance, `-WhatIf`, manifest version integrity, and Terraform credential isolation.

### Fixed
- `Approve-PSUPullRequest` and `Complete-PSUPullRequest` (Public): resolve optional provider commands before invocation and return actionable module installation guidance instead of raw command-not-found failures.
- `New-PSUGithubPullRequest`, `New-PSUOutlookMeeting`, and `Unlock-PSUTerraformStateAWS` (Public): honor `ShouldProcess`; `-WhatIf` no longer performs external mutations.
- `Update-OMGModuleVersion` (Public): update only the top-level manifest version without changing nested dependency versions.

### Security
- `Unlock-PSUTerraformStateAWS` (Public): pass AWS credentials through temporarily scoped environment variables instead of Terraform command-line arguments, restore prior values in `finally`, and redact credentials from Terraform failures.

## [1.0.22] - 6th August 2026
### Fixed
- Renamed `Public/Resolve-PSUGitMergeConflict.ps1-----wip` to `Public/Resolve-PSUGitMergeConflict--wip.ps1` so `build/Build-Modules.ps1`'s `*--wip.ps1` exclusion actually matches it. The old name was being packaged into published Core builds; this bump is required to ship the corrected package since `Publish-Modules.yml` skips publishing when the local version is not greater than the gallery version.

## [1.0.21] - 27th July 2026
### Documentation
- `Get-PSUUserEnvironmentVariable` (Public): updated the pipeline example to use `GEMINI_API_KEY`, following the environment variable rename in `OMG.PSUtilities.AI` 1.0.43.

## [1.0.20] - 26th July 2026
### Security
- Reduced plaintext credential exposure when retrieving credentials from Windows Credential Manager.
- Added `ShouldProcess` support to `Set-PSUCredentialToManager` while preserving its existing parameter contract.

### Documentation
- Completed missing public command output documentation.

## [1.0.19] - 31st December 2025
### Changed
- Added support for untracked files in `Get-PSUGitFileChangeMetadata` (Public): auto-stages by default as "New", marks as "Untracked" with `-ExcludeUntrackedFiles`.
- Enhanced documentation in `Get-PSUGitFileChangeMetadata.ps1` with new parameter description and example for `-ExcludeUntrackedFiles`.
- Added `-ExcludeUntrackedFiles` switch parameter to `Get-PSUGitFileChangeMetadata`.
## [1.0.18] - 27th December 2025
### Added
- New `Get-PSUPublicIP` (Public): Retrieves the public IP address of the current machine using DNS lookup (OpenDNS) and parallel HTTP requests to multiple endpoints, with caching capabilities and configurable timeout.
## [1.0.17] - 17th December 2025
### Added
- `Get-PSUPublicIP` (Public): Retrieves the public IP address of the current machine using DNS and HTTP methods with caching options.

### Changed
- Corrected a typo in `Update-OMGModuleVersion` where a special character was replaced with a standard dash in a `Write-Warning` message.
## [1.0.16] - 11th December 2025
```markdown
### Added

### Changed
- Cleaned up formatting: removed trailing whitespace, normalized blank lines, and refined comment indentation in `Get-PSUGitFileChangeMetadata.ps1`.
- Cleaned up formatting: removed trailing whitespace and blank lines in `New-PSUGithubPullRequest.ps1`.
```
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
