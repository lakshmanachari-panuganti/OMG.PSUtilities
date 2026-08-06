# GitHub Copilot instructions for OMG.PSUtilities

## Project overview

OMG.PSUtilities is a portfolio of independently versioned PowerShell modules
published to PowerShell Gallery, plus a meta-module that installs the whole set.

| Module | Purpose |
| --- | --- |
| `OMG.PSUtilities.Core` | General automation, reporting, credentials, workstation utilities |
| `OMG.PSUtilities.AzureDevOps` | Azure DevOps REST API automation |
| `OMG.PSUtilities.AI` | AI provider and prompt automation |
| `OMG.PSUtilities.AzureCore` | Azure and Kubernetes governance utilities |
| `OMG.PSUtilities.ActiveDirectory` | Active Directory analysis |
| `OMG.PSUtilities.ServiceNow` | ServiceNow integration boundary (placeholder) |
| `OMG.PSUtilities.VSphere` | VMware integration boundary (placeholder) |
| `OMG.PSUtilities` | Meta-module, no commands of its own |
| `OMG.DevTools` | Repository tooling, never published |

Command counts change often. Read the manifest `FunctionsToExport` rather than
trusting any number written in documentation.

See [Architecture](../docs/ARCHITECTURE.md), [CI/CD](../docs/CI-CD.md), and
[Contributing](../CONTRIBUTING.md).

---

## Module structure

```text
OMG.PSUtilities.ModuleName/
|-- Public/                 Exported commands, one command per file
|-- Private/                Internal helpers, never exported
|-- ModuleName.psm1         Loader and explicit exports
|-- ModuleName.psd1         Package metadata and dependencies
|-- README.md
`-- CHANGELOG.md
```

`.psm1` and `.psd1` exports are generated. After adding or removing a file under
`Public/`, regenerate them with `Invoke-OMGBuildModule` (`omgbuild`) from
`OMG.DevTools`, or `Reset-OMGModuleManifests` from
`Module Developer Tools\functions\`. Never hand-edit the export lists and leave
them out of sync with the folder; `build\Test-Repository.ps1` fails when they
drift.

Files ending in `--wip.ps1` are excluded from loading and from release artifacts.

---

## Naming

- Azure DevOps module: `Verb-PSUADONoun`, for example `Get-PSUADOWorkItem`.
- Every other module: `Verb-PSUNoun`, for example `Export-PSUExcel`.
- Private helpers use descriptive names, for example `Get-PSUAdoAuthHeader`.
- Use approved verbs only (`Get-Verb`).
- No emojis in function code or comment-based help.

---

## Comment-based help

Every public command has comment-based help with `.SYNOPSIS`, `.DESCRIPTION`,
`.PARAMETER` for each parameter, at least one `.EXAMPLE`, `.OUTPUTS`, `.NOTES`,
and `.LINK`. Validation fails without `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`,
`.OUTPUTS`, and `.NOTES`.

Most files place the help block inside the function, immediately after the
opening brace, indented four spaces. Match the file you are editing.

```powershell
function Get-PSUADONoun {
    <#
    .SYNOPSIS
        One-line summary of what the command does.

    .DESCRIPTION
        Detailed explanation of the behaviour.

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        Get-PSUADONoun -Project "psutilities"

        Describes what the example does.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 15th October 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    #>
```

---

## Parameter design

Order parameters as: mandatory business parameters, then optional business
parameters, then `Organization`, then `PAT` last. Put each attribute on its own
line and leave a blank line between parameters.

```powershell
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Project,

    [Parameter()]
    [string]$Title,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Organization = $env:ORGANIZATION,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PAT = $env:PAT
)
```

Set the environment defaults once per machine:

```powershell
Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<your-organization>'
Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<your-pat>'
```

---

## Validation and setup

All setup and runtime validation goes in `begin`, never in `process`. Azure
DevOps commands use the shared private helpers so that the verbose output and
the error messages stay identical across the module:

```powershell
begin {
    Write-PSUAdoParameterTrace -Invocation $MyInvocation -BoundParameters $PSBoundParameters
    Confirm-PSUAdoConnectionParameter -Organization $Organization -PAT $PAT

    $headers = Get-PSUAdoAuthHeader -PAT $PAT
}
```

`ValidateNotNullOrEmpty` does not check parameter default values, which is why
`Confirm-PSUAdoConnectionParameter` re-checks the environment-backed defaults at
runtime. Never write the PAT to any stream unmasked;
`Write-PSUAdoParameterTrace` handles the masking.

Use `begin`/`process`/`end` so commands work in a pipeline. Return
`[PSCustomObject]` with a `PSTypeName` so callers can format and filter the
output. Surface failures with `$PSCmdlet.ThrowTerminatingError($_)`.

---

## Formatting

K&R braces, four-space indentation:

```powershell
if ($condition) {
    # code
} elseif ($otherCondition) {
    # code
} else {
    # code
}

try {
    # code
} catch {
    # error handling
}
```

`PSScriptAnalyzerSettings.psd1` enforces brace placement, indentation, and the
alias ban. `.vscode/settings.json` configures the formatter to match.

---

## Adding a command

1. Create `Public/Verb-PSUNoun.ps1`, one command per file.
2. Follow the patterns above; copy the closest existing command in the module.
3. Regenerate the manifest and module file (`omgbuild`).
4. Add a CHANGELOG entry and increase `ModuleVersion` in the manifest.
5. Run the quality gate:

   ```powershell
   .\build\Test-Repository.ps1 -IncludeScriptAnalyzer
   Invoke-Pester -Path .\tests -Output Detailed
   .\build\Build-Modules.ps1 -Clean
   ```

CI runs the same three commands. A merge to `main` publishes only the module
versions that are newer than PowerShell Gallery, so an unchanged version is
silently skipped rather than failing.

---

## Live Azure DevOps tests

`.github\Instructions-OMG.PSUtilities.AzureDevOps\` holds manual tests that call
a real organization. They are not part of pull-request validation. Start with
`Test-PreFlightValidation.ps1`, then `Run-MasterTest.ps1`. Their JSON and HTML
output is ignored by `.gitignore` and must not be committed.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `The default value for the 'ORGANIZATION' environment variable is not set` | `$env:ORGANIZATION` missing and no `-Organization` supplied | `Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>'` |
| `The default value for the 'PAT' environment variable is not set` | `$env:PAT` missing and no `-PAT` supplied | `Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<pat>'` |
| New command not exported | Manifest not regenerated | Run `omgbuild`, then re-import the module |
| Command loads but is missing from `Get-Command` | File name ends in `--wip.ps1` | Rename without the suffix and regenerate |
| Validation fails on missing help | A required help keyword is absent | Add `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.OUTPUTS`, `.NOTES` |
| Azure DevOps command not found from a Core command | `OMG.PSUtilities.AzureDevOps` not installed | `Install-Module -Name OMG.PSUtilities.AzureDevOps -Scope CurrentUser` |

Quick environment check:

```powershell
'ORGANIZATION', 'PAT' | ForEach-Object {
    $value = [Environment]::GetEnvironmentVariable($_)
    "{0} = {1}" -f $_, $(if ($value) { '<set>' } else { '<NOT SET>' })
}

Import-Module .\OMG.PSUtilities.AzureDevOps\OMG.PSUtilities.AzureDevOps.psd1 -Force
Get-Command -Module OMG.PSUtilities.AzureDevOps | Measure-Object | Select-Object -ExpandProperty Count
```

---

When in doubt, open the closest existing command in the target module and follow
it exactly. Consistency with the surrounding code beats any rule written here.
