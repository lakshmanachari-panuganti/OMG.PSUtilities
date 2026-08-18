# OMG.PSUtilities

[![Validate PowerShell Modules](https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/actions/workflows/Validate.yml/badge.svg)](https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/actions/workflows/Validate.yml)
[![Publish PowerShell Modules](https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/actions/workflows/Publish-Modules.yml/badge.svg)](https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/actions/workflows/Publish-Modules.yml)

A modular PowerShell automation portfolio for Azure, Azure DevOps, AI, Active
Directory, reporting, and enterprise operations.

The complete meta-module requires PowerShell 7.0 or later. Individual modules
declare their own minimum PowerShell versions.

## Modules

| Module | Purpose | Public commands |
| --- | --- | ---: |
| `OMG.PSUtilities.Core` | General automation, reporting, credentials, and workstation utilities | 29 |
| `OMG.PSUtilities.AzureDevOps` | Azure DevOps REST API automation | 28 |
| `OMG.PSUtilities.AI` | AI provider and prompt automation | 12 |
| `OMG.PSUtilities.AzureCore` | Azure and Kubernetes governance utilities | 4 |
| `OMG.PSUtilities.ActiveDirectory` | Active Directory analysis | 1 |
| `OMG.PSUtilities.ServiceNow` | ServiceNow integration boundary | 1 |
| `OMG.PSUtilities.VSphere` | VMware integration boundary | 1 |
| `OMG.PSUtilities` | Meta-module that installs the complete portfolio | 0 |

## Installation

Install the complete portfolio:

```powershell
Install-Module -Name OMG.PSUtilities -Scope CurrentUser -Repository PSGallery
```

Install only the domain you need:

```powershell
Install-Module -Name OMG.PSUtilities.AzureDevOps -Scope CurrentUser -Repository PSGallery
```

## Quality gates

The same commands run locally and in GitHub Actions:

```powershell
.\build\Test-Repository.ps1 -IncludeScriptAnalyzer
Invoke-Pester -Path .\tests -Output Detailed
.\build\Build-Modules.ps1 -Clean
```

Pull requests must pass validation before merge. A merge to `main` builds clean
artifacts and publishes only module versions newer than PowerShell Gallery.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [CI/CD and releases](docs/CI-CD.md)
- [Azure integration testing](docs/AZURE-TESTING.md)
- [Contributing](CONTRIBUTING.md)

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for the full text.

Copyright (c) 2025-2026 Lakshmanachari Panuganti.
