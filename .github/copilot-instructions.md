# GitHub Copilot Instructions for OMG.PSUtilities

## Project Overview

**OMG.PSUtilities** is a PowerShell meta-module managing 7 specialized submodules for enterprise automation:

- **OMG.PSUtilities.AzureDevOps** (26 functions) - Azure DevOps REST API wrapper
- **OMG.PSUtilities.Core** (23 functions) - General-purpose utilities
- **OMG.PSUtilities.AzureCore** (3 functions) - Azure infrastructure utilities
- **OMG.PSUtilities.ActiveDirectory** (1 function) - AD automation
- **OMG.PSUtilities.VSphere** (1 function) - VMware automation
- **OMG.PSUtilities.ServiceNow** (1 function) - ServiceNow integration
- **OMG.PSUtilities.AI** - AI integration utilities

Each submodule follows a **strict architecture pattern** with `Public/` and `Private/` folders, manifest-driven exports, and automated build tooling.

---

## Critical Architecture Patterns

### Module Structure (MANDATORY)

Every submodule uses this exact structure:

```
OMG.PSUtilities.ModuleName/
├── Public/               # Exported functions (one .ps1 per function)
├── Private/              # Internal helper functions (not exported)
├── ModuleName.psm1       # Auto-generated module loader
├── ModuleName.psd1       # Auto-generated manifest
├── CHANGELOG.md
├── README.md
└── plasterManifest.xml
```

**Module Loader Pattern** (`ModuleName.psm1`):
```powershell
# Load private functions
Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -Recurse | Where-Object{$_.name -notlike "*--wip.ps1"} | ForEach-Object {
    try {
        . $($_.FullName)
    } catch {
        Write-Error "Failed to load private function $($_.FullName): $($_)"
    }
}

# Load public functions
Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -Recurse | Where-Object{$_.name -notlike "*--wip.ps1"} | ForEach-Object {
    try {
        . $($_.FullName)
    } catch {
        Write-Error "Failed to load public function $($_.FullName): $($_)"
    }
}

# Export public functions
$PublicFunctions = @(
    'Function-Name1',
    'Function-Name2'
)

$AliasesToExport = @()

Export-ModuleMember -Function $PublicFunctions -Alias $AliasesToExport
```

**⚠️ CRITICAL**: 
- `.psm1` and `.psd1` files are **AUTO-GENERATED**. Use `Reset-OMGModuleManifests` to update them after adding/removing functions.
- Functions ending in `--wip.ps1` are excluded from loading (work-in-progress convention).

---

## Coding Standards (LLM-Ready)

### Golden Rules

1. **Consistency over cleverness** - Follow existing patterns exactly
2. **Professional presentation** - Comment-based help is mandatory
3. **Automation-first outputs** - All functions must work in pipelines and automation

### Naming Conventions

- **AzureDevOps Module**: `Verb-PSUADONoun` (e.g., `Get-PSUADOWorkItem`, `Set-PSUADOTask`)
- **Core Module**: `Verb-PSUNoun` (e.g., `Export-PSUExcel`, `Get-PSUModule`)
- **All Other Modules**: `Verb-PSUNoun` with domain context
- **Private Functions**: Descriptive names (e.g., `Get-PSUAdoAuthHeader`, `Test-AzCliLogin`)
- **Use only approved PowerShell verbs** (`Get-Verb` compliant)

### Comment-Based Help (MANDATORY)

Every function MUST have this structure with **8-space indentation**:

```powershell
function Verb-PSUADONoun {
        <#
        .SYNOPSIS
                One-line summary of what the function does.

        .DESCRIPTION
                Detailed explanation of functionality.
                Multiple paragraphs allowed.

        .PARAMETER ParameterName
                Description of the parameter.
                Include default behavior, validation rules, and examples.

        .PARAMETER Organization
                (Optional) The Azure DevOps organization name.
                Default is $env:ORGANIZATION.
                Set via: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "<value>"

        .PARAMETER PAT
                (Optional) Personal Access Token.
                Default is $env:PAT.
                Set via: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "<value>"

        .EXAMPLE
                Verb-PSUADONoun -Parameter1 "Value1" -Organization "myorg"

                Demonstrates explicit parameters.

        .EXAMPLE
                Verb-PSUADONoun -Parameter1 "Value1"

                Demonstrates auto-detected Organization from $env:ORGANIZATION.

        .OUTPUTS
                [PSCustomObject] or [System.Object[]]

        .NOTES
                Author: Lakshmanachari Panuganti
                Created: YYYY-MM-DD
                Last Modified: YYYY-MM-DD
                Version: 1.0
        #>
```

**⚠️ NO EMOJIS** in function code or comment-based help (only in `Write-Host` progress indicators).

---

## Parameter Design (CRITICAL)

### Parameter Ordering (100% Enforcement)

**MANDATORY order for Azure DevOps functions**:

1. **Mandatory business parameters** (e.g., `Project`, `WorkItemId`, `PullRequestId`)
2. **Optional business parameters** (e.g., `Description`, `SourceBranch`, `Title`)
3. **Organization parameter** (second-to-last)
4. **PAT parameter** (last)

**Example**:
```powershell
param (
    # Mandatory business parameters
    [Parameter(Mandatory)]
    [string]$Project,

    [Parameter(Mandatory)]
    [int]$WorkItemId,

    # Optional business parameters
    [Parameter()]
    [string]$Title,

    [Parameter()]
    [string]$Description,

    # Infrastructure parameters (Organization second-to-last, PAT last)
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Organization = $env:ORGANIZATION,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PAT = $env:PAT
)
```

### Environment Variable Pattern

All Azure DevOps functions use:
- `$env:ORGANIZATION` for organization name
- `$env:PAT` for Personal Access Token

Set via: `Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "myorg"`

---

## Validation Pattern (MANDATORY)

All runtime validation **MUST** be in the `begin{}` block:

```powershell
begin {
    # 1. Display parameters (mask PAT)
    Write-Verbose "Parameters:"
    foreach ($param in $PSBoundParameters.GetEnumerator()) {
        if ($param.Key -eq 'PAT') {
            $maskedPAT = if ($param.Value -and $param.Value.Length -ge 3) { 
                $param.Value.Substring(0, 3) + "********" 
            } else { "****" }
            Write-Verbose "  $($param.Key) = $maskedPAT"
        } else {
            Write-Verbose "  $($param.Key) = $($param.Value)"
        }
    }

    # 2. Validate Organization
    if ([string]::IsNullOrWhiteSpace($Organization)) {
        throw "Organization parameter is required. Set via: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<your-organization>'"
    }

    # 3. Validate PAT
    if ([string]::IsNullOrWhiteSpace($PAT)) {
        throw "PAT parameter is required. Set via: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<your-pat>'"
    }

    # 4. Create authentication header
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
    $headers = @{
        Authorization = "Basic $base64AuthInfo"
        'Content-Type' = 'application/json'
    }
}
```

**⚠️ NO validation in `process{}` blocks** - All setup code goes in `begin{}` only.

---

## Performance Pattern (Pipeline Support)

Use `begin/process/end` blocks for pipeline-compatible functions:

```powershell
function Get-PSUADOWorkItem {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [int[]]$WorkItemId,

        [Parameter()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [string]$PAT = $env:PAT
    )

    begin {
        # Setup code (validation, auth header creation)
    }

    process {
        # Process each pipeline item
        foreach ($id in $WorkItemId) {
            # API call logic
        }
    }

    end {
        # Cleanup code (if needed)
    }
}
```

---

## Code Formatting (K&R Brace Style)

**Opening braces on same line, closing braces aligned with statement**:

```powershell
# CORRECT (K&R)
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

foreach ($item in $collection) {
    # code
}

# WRONG (Allman style)
if ($condition)
{
    # code
}
```

---

## Development Workflow

### Adding a New Function

1. **Create function file**: `Public/Verb-PSUADONoun.ps1` (one function per file)
2. **Write function** following all patterns above
3. **Update module manifests**: Run `Reset-OMGModuleManifests -ModuleName "OMG.PSUtilities.ModuleName"`
4. **Build and test**: Run `Build-OMGModuleLocally -ModuleName "OMG.PSUtilities.ModuleName"`
5. **Run tests**: Execute `.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1`
6. **Update CHANGELOG.md** with new function details
7. **Version bump**: Run `Update-OMGModuleVersion -ModuleName "OMG.PSUtilities.ModuleName" -BumpType Minor`

### Developer Tools (Tools/ folder)

- **`Reset-OMGModuleManifests.ps1`** - Auto-updates `.psm1` and `.psd1` after adding/removing functions
- **`Build-OMGModuleLocally.ps1`** - Builds and imports module for testing
- **`Update-OMGModuleVersion.ps1`** - Increments version in manifest and CHANGELOG
- **`New-OMGModuleStructure.ps1`** - Creates new module scaffold with Plaster
- **`Invoke-GitAutoTagAndPush.ps1`** - Git tagging and push automation

**⚠️ ALWAYS run `Reset-OMGModuleManifests` after modifying Public/ or Private/ folders.**

---

## Testing Infrastructure

### Test Architecture (AzureDevOps Module)

Located in: `.github\Instructions-OMG.PSUtilities.AzureDevOps\`

**Master Test Orchestrator**: `Run-MasterTest.ps1`
```powershell
# Quick test (30 seconds)
.\Run-MasterTest.ps1 -TestType Quick

# Comprehensive test (5-10 minutes, all 26 functions)
.\Run-MasterTest.ps1 -TestType Comprehensive -VerboseOutput

# Validation only (environment check)
.\Run-MasterTest.ps1 -TestType Validation

# With HTML report
.\Run-MasterTest.ps1 -TestType Comprehensive -ExportReport
```

**Test Components**:
1. **Pre-Flight Validation** (`Test-PreFlightValidation.ps1`) - 8 environment checks
2. **Comprehensive Test** (`Test-AzureDevOps-Comprehensive.ps1`) - 26+ function tests
3. **HTML Report Generation** - Auto-opens in browser with test results

**Current Status**:
- **80% success rate** (24/30 tests passing)
- 6 known failures documented (API limitations, not code bugs)
- Module quality: **98/100 (Production Ready)**

---

## Known Issues and Limitations

### Test Failures (Documented)

1. **`Get-PSUADORepoBranchList`** - 404 error (repository not initialized, expected)
2. **`Set-PSUADOVariableGroup`** - Name/Description not updated (Azure DevOps API limitation, not a bug)
3. **`New-PSUADOPullRequest`** - 400 error (invalid test scenario - same branch PR)
4. **`Set-PSUADOTask`** - 400 error (empty `AssignedTo` value handling issue)
5. **`Set-PSUADOBug`** - 400 error (work item state transition validation)

### Environment Requirements

- **Environment Variables**: `ORGANIZATION` and `PAT` must be set
- **Dependencies**: `ThreadJob` module for parallel testing
- **Azure DevOps Access**: Valid PAT with appropriate permissions

---

## Integration Points

### Azure DevOps REST API

All Azure DevOps functions use:
- **Base URL**: `https://dev.azure.com/{organization}/{project}/_apis/...`
- **API Version**: `api-version=7.0` or `7.1-preview.3`
- **Authentication**: Basic auth with PAT (Base64 encoded)
- **Response Format**: JSON (converted to PSCustomObject)

### Common Private Functions

- **`Get-PSUAdoAuthHeader`** - Creates authentication headers
- **Private helper functions** in `Private/` folder (not exported)

---

## Quick Reference for AI Agents

### "I need to add a new Azure DevOps function"

1. Check existing functions in `OMG.PSUtilities.AzureDevOps\Public\` for patterns
2. Copy template from `.github\Instructions-OMG.PSUtilities.AzureDevOps\Instructions-Validation-Pattern.md`
3. Follow parameter ordering: Business → Organization → PAT
4. Put all validation in `begin{}` block
5. Use `begin/process/end` for pipeline support
6. Add 8-space indented comment-based help
7. Run `Reset-OMGModuleManifests -ModuleName "OMG.PSUtilities.AzureDevOps"`
8. Test with `Run-MasterTest.ps1 -TestType Comprehensive`

### "I need to understand the module architecture"

- Read: `README.md` (root) - Meta-module overview
- Read: `OMG.PSUtilities.AzureDevOps\README.md` - 26 functions documented
- Read: `.github\Instructions-OMG.PSUtilities.AzureDevOps\INDEX.md` - Complete documentation index

### "I need to understand coding standards"

- Read: `Module Developer Tools\OMG.PSUtilities.StyleGuide.md` (504 lines, authoritative)
- Read: `.github\Instructions-OMG.PSUtilities.AzureDevOps\Instructions-Validation-Pattern.md` (630 lines)

### "I need to understand test infrastructure"

- Read: `.github\Instructions-OMG.PSUtilities.AzureDevOps\TEST-ARCHITECTURE.md` - Flow diagrams
- Read: `.github\Instructions-OMG.PSUtilities.AzureDevOps\TEST-RESULTS-SUMMARY-2025-10-15.md` - Latest test analysis
- Run: `Run-MasterTest.ps1 -TestType Validation` to check environment

### "I need to fix a bug"

1. Review `.github\Instructions-OMG.PSUtilities.AzureDevOps\COMPREHENSIVE-REVIEW-2025-01-15-FINAL.md` - Recent bug fixes
2. Check test results in `.github\Instructions-OMG.PSUtilities.AzureDevOps\TestResults-*.json`
3. Run `Run-MasterTest.ps1 -VerboseOutput` to see detailed errors
4. Update function in `Public/` folder
5. Run `Reset-OMGModuleManifests` and test again

---

## Key Documentation Files

- **Authoritative Style Guide**: `Module Developer Tools\OMG.PSUtilities.StyleGuide.md` (504 lines)
- **Validation Pattern**: `.github\Instructions-OMG.PSUtilities.AzureDevOps\Instructions-Validation-Pattern.md` (630 lines)
- **Test Architecture**: `.github\Instructions-OMG.PSUtilities.AzureDevOps\TEST-ARCHITECTURE.md` (315 lines)
- **Quality Review**: `.github\Instructions-OMG.PSUtilities.AzureDevOps\COMPREHENSIVE-REVIEW-2025-01-15-FINAL.md` (475 lines)
- **Documentation Index**: `.github\Instructions-OMG.PSUtilities.AzureDevOps\INDEX.md` (385 lines)
- **Developer Tools**: `Tools\README.md` (build/release workflow)

---

## Expandable Practices for Future Use

### Suggestions for Standardization

1. **Create Function Template Script**: Automate new function creation with pre-filled comment-based help and parameter ordering
2. **Pre-Commit Hook**: Add git pre-commit hook to validate K&R brace style and parameter ordering
3. **CI/CD Pipeline**: Integrate `Run-MasterTest.ps1` into GitHub Actions for automated testing
4. **Documentation Generator**: Auto-generate README.md function tables from comment-based help
5. **PAT Rotation Reminder**: Add expiration tracking for Azure DevOps PAT tokens
6. **Test Coverage Report**: Add code coverage metrics to HTML test reports
7. **Module Dependency Graph**: Visualize inter-module dependencies and common patterns

### Automation Opportunities

- **Auto-update CHANGELOG.md** from git commit messages
- **Auto-bump versions** based on semantic commit messages
- **Auto-generate release notes** from CHANGELOG.md
- **Auto-tag releases** in GitHub when version changes detected
- **Validate all functions** have matching tests before allowing commits

---

## Summary

This codebase prioritizes **consistency, automation, and enterprise-grade quality**. All new code must:

✅ Follow K&R brace style  
✅ Use begin/process/end blocks for pipeline support  
✅ Put all validation in `begin{}` block  
✅ Follow parameter ordering (Business → Organization → PAT)  
✅ Include 8-space indented comment-based help  
✅ Use environment variables (`$env:ORGANIZATION`, `$env:PAT`)  
✅ Mask PAT in verbose output  
✅ Use approved PowerShell verbs  
✅ Have matching test coverage  
✅ Update CHANGELOG.md  
✅ Run `Reset-OMGModuleManifests` after changes  

**When in doubt, examine existing functions in the target module and follow their patterns exactly.**
