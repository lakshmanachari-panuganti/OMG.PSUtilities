## [1.0.2] - 6th August 2026
### Fixed
- `Invoke-OMGBuildModule` (Public): the generated public loader line in built `.psm1` files no longer swallows a missing `Public` folder with `-ErrorAction SilentlyContinue`, so a genuinely broken module still surfaces a diagnostic instead of importing silently with zero exported commands. Only the private loader line tolerates a missing `Private` folder.

## [1.0.1] - 27th July 2026
### Changed
- **BREAKING** `Initialize-OMGEnvironment` (Public) and `Config/settings.json`: the required environment variable `API_KEY_GEMINI` is renamed to `GEMINI_API_KEY`, following the rename in `OMG.PSUtilities.AI` 1.0.43. Environments provisioned against the old name will be reported as missing until the variable is renamed.
