# Azure DevOps Module - Standards & Patterns

**Module**: OMG.PSUtilities.AzureDevOps  
**Version**: 1.0.9+  
**Status**: ✅ All 22 exported functions migrated and validated  
**Last Updated**: January 2025

---

## Table of Contents
1. [Quick Reference](#quick-reference)
2. [Parameter Ordering Standard](#parameter-ordering-standard)
3. [Validation Pattern](#validation-pattern)
4. [Performance Pattern (begin/process)](#performance-pattern)
5. [Testing Guide](#testing-guide)
6. [Migration Status](#migration-status)

---

## Quick Reference

### Complete Function Template
```powershell
function Verb-PSUADONoun {
    param (
        # Business parameters (mandatory first, optional second)
        [Parameter(Mandatory)]
        [string]$Project,

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

    begin {
        # 1. Display parameters (mask PAT)
        Write-Verbose "Parameters:"
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            if ($param.Key -eq 'PAT') {
                $maskedPAT = if ($param.Value -and $param.Value.Length -ge 3) { 
                    $param.Value.Substring(0, 3) + "********" 
                } else { "***" }
                Write-Verbose "  $($param.Key): $maskedPAT"
            } else {
                Write-Verbose "  $($param.Key): $($param.Value)"
            }
        }

        # Validate Organization (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
        if (-not $Organization) {
            throw "The default value for the 'ORGANIZATION' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>' or provide via -Organization parameter."
        }

        # Validate PAT (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
        if (-not $PAT) {
            throw "The default value for the 'PAT' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<pat>' or provide via -PAT parameter."
        }

        # 4. Create authentication headers once
        $headers = Get-PSUAdoAuthHeader -PAT $PAT
    }

    process {
        try {
            # Business logic here
            $uri = "https://dev.azure.com/$Organization/$Project/_apis/..."
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            return $response
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
```

---


## Parameter Ordering Standard

### Rules
All Azure DevOps functions **MUST** follow this parameter order:

1. **Mandatory business parameters** (e.g., Project, RepositoryId, WorkItemId)
2. **Optional business parameters** (e.g., BranchName, Description, Tags)
3. **Organization** (second-to-last position)
4. **PAT** (last position)

### Why This Matters
- **Consistency**: Predictable interface across all 22 functions
- **Discoverability**: Tab completion shows business parameters first
- **Separation of Concerns**: Business logic separated from infrastructure
- **Maintainability**: Deviations are immediately obvious

### Examples

#### ✅ Correct
```powershell
param (
    [Parameter(Mandatory)]
    [string]$Project,

    [Parameter(Mandatory)]
    [int]$WorkItemId,

    [Parameter()]
    [string]$Title,

    [Parameter()]
    [string]$Organization = $env:ORGANIZATION,

    [Parameter()]
    [string]$PAT = $env:PAT
)
```

#### ❌ Incorrect
```powershell
param (
    [Parameter()]
    [string]$Organization = $env:ORGANIZATION,  # ❌ Too early

    [Parameter(Mandatory)]
    [string]$Project,

    [Parameter()]
    [string]$PAT = $env:PAT,  # ❌ Not last

    [Parameter(Mandatory)]
    [int]$WorkItemId
)
```

---

## Validation Pattern

### The Problem
PowerShell's `[ValidateNotNullOrEmpty()]` attribute **does not validate default parameter values**:

```powershell
param (
    [ValidateNotNullOrEmpty()]
    [string]$Organization = $env:ORGANIZATION  # If $env:ORGANIZATION is null, NO ERROR!
)
```

If `$env:ORGANIZATION` is not set, `$Organization` will be `$null`, but the validator won't catch it because the user didn't explicitly pass a value.

### The Solution
Add runtime validation in the `begin{}` block:

```powershell
process {
    try {
        # Display parameters (for verbose logging)
        Write-Verbose "Parameters:"
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            if ($param.Key -eq 'PAT') {
                $maskedPAT = if ($param.Value -and $param.Value.Length -ge 3) { 
                    $param.Value.Substring(0, 3) + "********" 
                } else { 
                    "***" 
                }
                Write-Verbose "  $($param.Key): $maskedPAT"
            } else {
                Write-Verbose "  $($param.Key): $($param.Value)"
            }
        }

        # Validate Organization (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
        if (-not $Organization) {
            throw "The default value for the 'ORGANIZATION' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>' or provide via -Organization parameter."
        }

    # Validate PAT
    if (-not $PAT) {
        throw "The default value for the 'PAT' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<pat>' or provide via -PAT parameter."
    }
}
```

### Why This Works
- ✅ Validates actual runtime values (including defaults from environment variables)
- ✅ Fails fast before any API calls
- ✅ Provides clear, actionable error messages
- ✅ Consistent behavior across all functions

---

## Performance Pattern

### begin{} + process{} Structure

**Purpose**: Optimize for pipeline input by running validation and setup once, not per item.

#### How It Works
- **begin{}**: Runs **once** before processing any pipeline input
  - Parameter display
  - Organization/PAT validation
  - Authentication header creation
  
- **process{}**: Runs **once per pipeline item**
  - Business logic only
  - API calls using headers from begin{}

#### Performance Impact

```powershell
# Without begin{} (inefficient)
'proj1','proj2','proj3' | Get-PSUADOExample
# Validates Organization 3 times ❌
# Validates PAT 3 times ❌
# Creates headers 3 times ❌

# With begin{} (efficient)
'proj1','proj2','proj3' | Get-PSUADOExample
# Validates Organization 1 time ✅
# Validates PAT 1 time ✅
# Creates headers 1 time ✅
```

#### Pattern

```powershell
begin {
    # Setup (runs once)
    Write-Verbose "Parameters: ..."
    if (-not $Organization) { throw "..." }
    if (-not $PAT) { throw "..." }
    $headers = Get-PSUAdoAuthHeader -PAT $PAT
}

process {
    try {
        # Business logic (runs per pipeline item)
        $uri = "https://dev.azure.com/$Organization/..."
        $response = Invoke-RestMethod -Uri $uri -Headers $headers
        return $response
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
```

### Benefits
- ⚡ **Performance**: Validation and setup run once, not per pipeline item
- 🎯 **Early Failure**: Catches errors before processing any data
- 🔄 **Pipeline Optimized**: Designed for efficient pipeline processing
- 📊 **Clean Separation**: Setup in begin{}, business logic in process{}

### ⚠️ CRITICAL: Common Migration Mistake

**DO NOT duplicate code in process{}!**

During migration from single-block to begin{}/process{} pattern, a common error is to **copy validation code to begin{} without removing it from process{}**. This defeats the entire purpose of the pattern.

#### ❌ WRONG (Duplicated Code)
```powershell
begin {
    # Validation in begin{} ✅
    if (-not $Organization) { throw "..." }
    if (-not $PAT) { throw "..." }
    $headers = Get-PSUAdoAuthHeader -PAT $PAT
}

process {
    try {
        # DUPLICATE validation in process{} ❌❌❌
        if (-not $Organization) { throw "..." }
        if (-not $PAT) { throw "..." }
        $headers = Get-PSUAdoAuthHeader -PAT $PAT  # ❌ Created again!
        
        # Business logic
        $uri = "https://dev.azure.com/$Organization/..."
        $response = Invoke-RestMethod -Uri $uri -Headers $headers
    }
    catch { $PSCmdlet.ThrowTerminatingError($_) }
}
```

**Why This Is Critical:**
- 🐛 Validation runs per pipeline item (defeats performance optimization)
- 🐛 Headers created multiple times (wasteful)
- 🐛 Violates begin{}/process{} separation of concerns
- 🐛 Code duplication increases maintenance burden

#### ✅ CORRECT (No Duplication)
```powershell
begin {
    # ALL validation and setup here ✅
    if (-not $Organization) { throw "..." }
    if (-not $PAT) { throw "..." }
    $headers = Get-PSUAdoAuthHeader -PAT $PAT
}

process {
    try {
        # ONLY business logic here ✅
        # NO validation, NO header creation
        $uri = "https://dev.azure.com/$Organization/..."
        $response = Invoke-RestMethod -Uri $uri -Headers $headers
    }
    catch { $PSCmdlet.ThrowTerminatingError($_) }
}
```

**Migration Checklist:**
- [ ] Move parameter display to begin{}
- [ ] Move Organization validation to begin{}
- [ ] Move PAT validation to begin{}
- [ ] Move $headers creation to begin{}
- [ ] **DELETE all of the above from process{}** ⚠️
- [ ] Verify process{} contains ONLY business logic

**Bug History:**
- **October 2025**: All 22 functions correctly implemented with begin{}/process{}
- **January 2025**: Bug discovered - 18 of 22 functions had duplicate validation in process{}
- **January 2025**: All 18 functions fixed - duplicate code removed from process{}

---


## Testing Guide

### Test 1: Missing Environment Variable
```powershell
# Clear environment variables
Remove-Item Env:\ORGANIZATION -ErrorAction SilentlyContinue
Remove-Item Env:\PAT -ErrorAction SilentlyContinue

# Attempt to call function
Get-PSUADOProjectList

# Expected: Clear error with instructions
# "The default value for the 'ORGANIZATION' environment variable is not set.
# Set it using: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>' 
# or provide via -Organization parameter."
```

### Test 2: Environment Variables Set
```powershell
# Configure environment
Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value 'myorg'
Set-PSUUserEnvironmentVariable -Name 'PAT' -Value 'my_token'

# Call without parameters
Get-PSUADOProjectList

# Expected: Success
```

### Test 3: Explicit Parameters
```powershell
# Override environment variables
Get-PSUADOProjectList -Organization 'different_org' -PAT 'different_token'

# Expected: Success with specified values
```

### Test 4: Pipeline Input (Performance Test)
```powershell
# Test that validation runs only once
'proj1','proj2','proj3' | Get-PSUADORepositories -Verbose

# Expected: 
# - Parameter display shows once (from begin{})
# - Validation messages appear once
# - Business logic runs 3 times (from process{})
```

---

## Migration Status

### ✅ Completed: All 22 Exported Functions

All functions in `OMG.PSUtilities.AzureDevOps` have been migrated to the standardized pattern:

**Get-* Functions (10)**
- Get-PSUADOPipeline
- Get-PSUADOPipelineBuild
- Get-PSUADOPipelineLatestRun
- Get-PSUADOProjectList
- Get-PSUADOPullRequest
- Get-PSUADOPullRequestInventory
- Get-PSUADORepoBranchList
- Get-PSUADORepositories
- Get-PSUADOVariableGroupInventory
- Get-PSUADOWorkItem

**New-* Functions (5)**
- New-PSUADOBug
- New-PSUADOPullRequest
- New-PSUADOSpike
- New-PSUADOTask
- New-PSUADOUserStory

**Set-* Functions (4)**
- Set-PSUADOBug
- Set-PSUADOSpike
- Set-PSUADOTask
- Set-PSUADOUserStory

**Other Functions (3)**
- Approve-PSUADOPullRequest
- Complete-PSUADOPullRequest
- Invoke-PSUADORepoClone

### Implementation Checklist

When creating or modifying Azure DevOps functions, verify:

#### Parameter Block
- [ ] Mandatory business parameters first
- [ ] Optional business parameters second
- [ ] Organization parameter second-to-last
- [ ] PAT parameter last
- [ ] Both use `$env:ORGANIZATION` and `$env:PAT` defaults
- [ ] Both have `[ValidateNotNullOrEmpty()]` attribute

#### begin{} Block
- [ ] Parameter display with PAT masking
- [ ] Organization validation
- [ ] PAT validation
- [ ] Authentication header creation (`$headers`)
- [ ] **VERIFY: All setup code exists ONLY in begin{}, not duplicated in process{}**

#### process{} Block
- [ ] try-catch wrapper with `$PSCmdlet.ThrowTerminatingError($_)`
- [ ] Business logic only (no validation or setup)
- [ ] **VERIFY: NO parameter display code**
- [ ] **VERIFY: NO Organization validation**
- [ ] **VERIFY: NO PAT validation**
- [ ] **VERIFY: NO $headers creation (use $headers from begin{})**
- [ ] Uses `$headers` from begin{} block
- [ ] Returns appropriate results

#### Testing
- [ ] Test with missing environment variables (should fail with clear message)
- [ ] Test with environment variables set (should succeed)
- [ ] Test with explicit parameters (should override environment)
- [ ] Test with pipeline input (validation should run once)

---

## Benefits Summary

### Validation Pattern
- ✅ **Early Detection**: Catches configuration issues before API calls
- ✅ **Clear Guidance**: Error messages include exact fix commands
- ✅ **Consistent Behavior**: All functions validate the same way
- ✅ **Better UX**: No confusing API errors due to missing auth

### Parameter Ordering
- ✅ **Predictability**: Same order across all 22 functions
- ✅ **Discoverability**: Tab completion presents business params first
- ✅ **Maintainability**: Easy to spot non-conforming functions
- ✅ **Separation**: Business logic separated from infrastructure

### Performance Pattern (begin/process)
- ✅ **Efficiency**: Validation runs once, not per pipeline item
- ✅ **Speed**: Headers created once for entire pipeline
- ✅ **Early Failure**: Errors before processing any data
- ✅ **Clean Code**: Clear separation of concerns

---

## Related Resources

### Helper Functions
- `Set-PSUUserEnvironmentVariable`: Configure user-level environment variables
- `Get-PSUAdoAuthHeader`: Create authentication headers from PAT

### Documentation
- [PowerShell Advanced Parameters](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters)
- [Azure DevOps REST API Authentication](https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/authentication-guidance)
- [PowerShell begin/process/end Blocks](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_methods)

---

## Version History

| Date | Change |
|------|--------|
| October 2025 | Initial validation pattern implemented |
| October 2025 | Migration to begin{}/process{} pattern completed for all 22 functions |
| January 2025 | **BUG FIX**: Discovered and fixed critical bug - 18 functions had duplicate validation code in process{} block |
| January 2025 | Documentation enhanced with "Common Migration Mistake" section and verification checklist |
| January 2025 | Documentation optimized and restructured with Table of Contents |

---

**Author**: Lakshmanachari Panuganti  
**Repository**: https://github.com/lakshmanachari-panuganti/OMG.PSUtilities  
**Module**: OMG.PSUtilities.AzureDevOps v1.0.9+
