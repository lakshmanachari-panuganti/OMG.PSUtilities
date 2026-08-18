## Changelog

## [Unreleased - retired, will not ship] - 18th August 2026
The manifest version stays at 1.0.1, matching the Gallery, so this module can never publish
again. These changes exist in source only and are recorded here for the record.

### Removed
- Retired from automated publication. `OMG.PSUtilities.ServiceNow` is no longer in the publish
  workflow's module list, so it is never built for or pushed to the PowerShell Gallery again.

### Changed
- Marked the module explicitly unsupported in its manifest description and README. The sole
  exported command has always been a placeholder that throws `NotImplementedException`; no
  functionality has ever shipped. The source directory is retained only as incubation history.
- Applied the MIT license metadata approved in `docs/decisions/0.5-licensing-selection.md`, so
  the module carries an explicit legal state instead of a contradictory one.

### Note
- The existing Gallery version must also be **unlisted** on powershellgallery.com. That is an
  account-level action and cannot be performed from this repository.

## [1.0.1] - 6th August 2026
### Fixed
- Importing the module no longer writes "Cannot find path ... \Private\" to the console. The empty `Private` folder was removed and the loader now tolerates its absence.

## [1.0.0] - 2025-07-16
- Initial scaffolding for OMG.PSUtilities.ServiceNow
- OMG.PSUtilities.ServiceNow.psd1 : Added a dummy function (New-OMGPSUtilitiesServiceNow) for testing.
- OMG.PSUtilities.ServiceNow.psm1 : Added the code to load the private and public functions into the session, and further export public functions.
