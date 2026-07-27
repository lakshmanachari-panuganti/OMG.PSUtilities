## [1.0.1] - 27th July 2026
### Changed
- **BREAKING** `Initialize-OMGEnvironment` (Public) and `Config/settings.json`: the required environment variable `API_KEY_GEMINI` is renamed to `GEMINI_API_KEY`, following the rename in `OMG.PSUtilities.AI` 1.0.43. Environments provisioned against the old name will be reported as missing until the variable is renamed.
