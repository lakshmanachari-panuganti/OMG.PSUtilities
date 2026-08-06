# OMG.DevTools

Development tools for building, publishing, and managing the OMG PowerShell
modules. This module is repository tooling: it is validated by CI but is not
published to PowerShell Gallery and is not part of the `OMG.PSUtilities`
meta-module.

## Commands

| Command | Alias | Purpose |
| --- | --- | --- |
| `Get-OMGModule` | `omgmod` | Lists the OMG modules in the repository, with a short-lived cache. |
| `Initialize-OMGEnvironment` | `omgenv` | Sets up and validates the required environment variables. |
| `Invoke-OMGBuildModule` | `omgbuild` | Regenerates the manifest and module file, then imports the module locally. |
| `Invoke-OMGPublishModule` | `omgpublish` | Version-bumps, changelogs, commits, and publishes changed modules. |
| `Invoke-OMGUpdateModule` | `omgupdate` | Updates installed modules from PowerShell Gallery. |

## Environment

| Variable | Used by | Purpose |
| --- | --- | --- |
| `BASE_MODULE_PATH` | all commands | Repository root that holds the module folders. |
| `API_KEY_PSGALLERY` | `Invoke-OMGPublishModule` | PowerShell Gallery API key. |

Run `Initialize-OMGEnvironment` once to configure them.

## Notes

`Invoke-OMGPublishModule` lazy-loads the helper functions in
`Module Developer Tools\functions\` from `BASE_MODULE_PATH`, so that folder must
be present alongside the module folders.

Automated releases go through `.github/workflows/Publish-Modules.yml`. Use
`Invoke-OMGPublishModule` for local and manual publishing only.
