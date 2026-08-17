## Changelog

## [1.1.0] - 2026-08-18
### Fixed
- `Find-PSUADServiceAccountMisuse` (Public): resolve `Get-ADUser` and `Get-WinEvent` before
  doing any work. Without the Active Directory RSAT module, or on a non-Windows host, the
  command previously failed with `CommandNotFoundException` partway through instead of saying
  what was missing. Neither dependency is declared in the manifest because neither is
  installable from the Gallery.

### Added
- `CompatiblePSEditions = @('Desktop', 'Core')`, set from tested imports on Windows PowerShell
  5.1 and PowerShell 7.
- Regression tests for both dependency guards, including that no event-log query is attempted
  when a prerequisite is missing.

### Changed
- Applied the MIT license metadata approved in `docs/decisions/0.5-licensing-selection.md`:
  `Copyright`, `LicenseUri`, `ProjectUri`, and `Tags`.
- Indented the manifest consistently so metadata edits do not resurface baselined analyzer
  warnings.

## [1.0.6] - 2026-08-15
### Fixed
- Made service-account risk scoring return one deterministic score and level.
- Omitted null credentials from event-log queries and preserved query failures while treating no matching events as an empty result.

## [1.0.5] - 6th August 2026
### Fixed
- Importing the module no longer writes "Cannot find path ... \Private\" to the console. The module has no `Private` folder, and the loader now tolerates that.

## [1.0.4] - 2025-08-19
### Changed
- Updated Find-PSUADServiceAccountMisuse function to comply with OMG.PSUtilities.StyleGuide.md standards
- Standardized comment-based help with ordinal date format (DDth month YYYY)
- Added comprehensive .OUTPUTS section to the function
- Corrected .LINK section ordering (GitHub → LinkedIn → PowerShell Gallery → Microsoft Docs)
- Enhanced documentation consistency and professional presentation

## [1.0.1] - 2025-07-27
### Added
- Find-PSUADServiceAccountMisuse (Public): Finds potential misuse of service accounts in AD.

## [1.0.0] - 2025-07-16
- Initial scaffolding for OMG.PSUtilities.ActiveDirectory.
- OMG.PSUtilities.ActiveDirectory.psd1 : Exported a dummy function for testing.
- OMG.PSUtilities.ActiveDirectory.psm1 : Added the code to load the private and public functions into the session, and further