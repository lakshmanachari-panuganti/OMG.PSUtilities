## Changelog

## [1.0.1] - 6th August 2026
### Fixed
- Importing the module no longer writes "Cannot find path ... \Private\" to the console. The empty `Private` folder was removed and the loader now tolerates its absence.

## [1.0.0] - 2025-07-16
- Initial scaffolding for OMG.PSUtilities.ServiceNow
- OMG.PSUtilities.ServiceNow.psd1 : Added a dummy function (New-OMGPSUtilitiesServiceNow) for testing.
- OMG.PSUtilities.ServiceNow.psm1 : Added the code to load the private and public functions into the session, and further export public functions.
