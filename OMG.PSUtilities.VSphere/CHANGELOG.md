## [1.0.4] - 18th August 2026
### Removed
- Retired from automated publication. `OMG.PSUtilities.VSphere` is no longer in the publish
  workflow's module list, so it is never built for or pushed to the PowerShell Gallery again.

### Changed
- Marked the module explicitly unsupported in its manifest description and README. The sole
  exported command has always been a placeholder that throws `NotImplementedException`; no
  functionality has ever shipped. The source directory is retained only as incubation history.
- Rewrote the historical `Sensitive-Test-Pack` entries, which claimed a critical credential
  breach requiring immediate rotation. The repository's own history does not support that claim;
  see the note under 1.0.0.
- Applied the MIT license metadata approved in `docs/decisions/0.5-licensing-selection.md`, so
  the module carries an explicit legal state instead of a contradictory one.

### Note
- The existing Gallery version must also be **unlisted** on powershellgallery.com. That is an
  account-level action and cannot be performed from this repository.

## [1.0.3] - 6th August 2026
### Fixed
- Importing the module no longer writes "Cannot find path ... \Private\" to the console. The module has no `Private` folder, and the loader now tolerates that.

## [1.0.2] - 9th December 2025

## [1.0.1] - 21st November 2025
### Added
- `Public/Sensitive-Test-Pack/`: a set of deliberately fake files, including `Deploy-Config.ps1`,
  `.env`, `secrets.tfvars`, `appsettings.json` and a pipeline definition, used as fixtures to
  exercise the repository's secret-detection tooling.

## [1.0.0] - 21st November 2025
### Added
- Initial scaffolding for the module.

### Note on the former "Sensitive-Test-Pack" entries
Earlier revisions of this changelog described the test pack as a critical credential breach and
instructed readers to rotate exposed credentials immediately. That narrative was not supported by
the repository's own history and has been corrected. What the record actually shows:

- The files were added by commit `7cabe8f`, whose message states they are dummy secrets added to
  test the pipeline for leakage.
- They lived in a directory named `Sensitive-Test-Pack`, alongside other decoy files.
- The values were self-evident placeholders such as `adminUser`, `MySecretPassword123` and an API
  key literally containing `DUMMYKEY`.
- They were removed by commit `7b603cc` and are absent from tracked source.

No real credential was published by this module, and there is nothing to rotate. The original
wording is preserved in Git history rather than restated here, because repeating an unverified
breach claim in shipped release notes is itself a problem.
## Changelog
- Initial scaffolding for OMG.PSUtilities.VSphere

## [1.0.0] - 2025-07-16
- OMG.PSUtilities.VSphere.psd1 : Added dummy function ('New-OMGPSUtilitiesVSphere') for testing.
- OMG.PSUtilities.VSphere.psm1 : Added the code to load the private and public functions into the session, and further export public functions.
