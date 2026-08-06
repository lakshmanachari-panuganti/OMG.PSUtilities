# OMG.PSUtilities.AzureDevOps - live test suite

These scripts run the Azure DevOps module against a real organization. They are
manual tools; pull-request validation uses `build\Test-Repository.ps1` and the
Pester suite under `tests\` instead.

## Quick start

```powershell
# Validate the environment first
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Test-PreFlightValidation.ps1

# Smoke test
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Quick

# Full run with an HTML report
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive -VerboseOutput -ExportReport
```

## Contents

| File | Purpose |
| --- | --- |
| `Run-MasterTest.ps1` | Orchestrator. Start here. |
| `Test-PreFlightValidation.ps1` | Environment validation checks |
| `Test-AzureDevOps-Comprehensive.ps1` | Core test engine |
| `Debug-SetPSUADOVariable.ps1` | Debug tool for variable operations |
| `Format-AllPowerShellFiles.ps1` | Bulk reformat helper |
| `QUICK-REFERENCE.md` | One-page command reference |
| `TEST-ARCHITECTURE.md` | Flow diagrams and component layout |
| `Instructions-Validation-Pattern.md` | Authoritative validation and parameter pattern |
| `Test-AzureDevOps-Comprehensive-README.md` | Detailed usage and troubleshooting |

## Prerequisites

1. PowerShell 7.0 or later.
2. Environment variables:

   ```powershell
   Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<your-organization>'
   Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<your-pat>'
   ```

3. A PAT with Code (read and write), Work Items (read and write), and Variable
   Groups (manage) permissions.
4. A test project and repository that the PAT can reach.

## Output

Runs write `TestResults-<timestamp>.json` and `TestReport-<timestamp>.html` next
to the scripts. Both patterns are ignored by `.gitignore`; do not commit them.

## Troubleshooting

1. Confirm `ORGANIZATION` and `PAT` are set in the current session.
2. Confirm the PAT scopes above.
3. Confirm the test repository is reachable from the Azure DevOps portal.
4. Re-run with `-VerboseOutput` and read `Test-AzureDevOps-Comprehensive-README.md`.
