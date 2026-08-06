# OMG.PSUtilities - internal tools

Standalone maintenance scripts. They are not packaged with any module and are not
run by CI. The day-to-day build and publish workflow lives in the `OMG.DevTools`
module and in `Module Developer Tools\functions\`; these scripts cover one-off
maintenance instead.

## Scripts

| Script | Purpose |
| --- | --- |
| `New-OMGModuleStructure.ps1` | Creates a new module folder layout with Plaster, README, and CHANGELOG. |
| `Invoke-AutoBuildAndVersionChangedModules.ps1` | Builds and version-bumps every module with git changes. |
| `Move-OMGFunctionsToModules.ps1` | Moves function files between modules. |
| `Export-PSUFunctionalSummary.ps1` | Exports a functional summary of the exported commands. |
| `Run-PSUAzureDevOpsFunctionalTests.ps1` | Runs the Azure DevOps functional tests against a live organization. |
| `Test-UpdatedFunctions.ps1` | Imports and smoke-tests the functions changed in the working tree. |

## Reference documents

- `PowerShell-Function-Consistency-Check-Prompt.md`
- `OMG-PSUtilities-Consistency-Analysis-Report.md`
