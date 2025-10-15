# Azure DevOps Module - Parameter Validation & Ordering Standard

## Quick Reference

### ✅ Correct Pattern
```powershell
param (
    # 1. Business-specific mandatory parameters
    [Parameter(Mandatory)]
    [string]$Project,

    # 2. Business-specific optional parameters
    [Parameter()]
    [string]$Description,

    # 3. Organization parameter (SECOND TO LAST)
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Organization = $env:ORGANIZATION,

    # 4. PAT parameter (ALWAYS LAST)
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PAT = $env:PAT
)

process {
    try {
        # Display parameters
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

        # Validate PAT (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
        if (-not $PAT) {
            throw "The default value for the 'PAT' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<pat>' or provide via -PAT parameter."
        }

        # Continue with function logic...
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
```

---

## Overview
This document describes the standardized validation pattern implemented across all functions in the `OMG.PSUtilities.AzureDevOps` module for the `Organization` and `PAT` (Personal Access Token) parameters.

## Background
PowerShell's `[ValidateNotNullOrEmpty()]` attribute **does not validate default parameter values**. It only validates values that are explicitly passed by the user. This means that if a parameter has a default value from an environment variable (e.g., `$env:ORGANIZATION` or `$env:PAT`), and that environment variable is not set or is empty, the validation attribute will not catch it.

## The Problem
```powershell
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Organization = $env:ORGANIZATION  # If $env:ORGANIZATION is null, no error is thrown!
)
```

If `$env:ORGANIZATION` is not set, `$Organization` will be `$null`, but `ValidateNotNullOrEmpty()` won't catch it because the user didn't explicitly pass a value.

## The Solution
Add runtime validation immediately after parameter display in the `process` block:

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

        # Validate PAT (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
        if (-not $PAT) {
            throw "The default value for the 'PAT' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<pat>' or provide via -PAT parameter."
        }

        # Continue with function logic...
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
```

## Implementation Guidelines

### 1. Parameter Definition
Always define Organization and PAT parameters with default values from environment variables:

```powershell
[Parameter()]
[ValidateNotNullOrEmpty()]
[string]$Organization = $env:ORGANIZATION,

[Parameter()]
[ValidateNotNullOrEmpty()]
[string]$PAT = $env:PAT
```

**IMPORTANT: Parameter Ordering**
- `$Organization` and `$PAT` parameters **MUST** be placed at the **END** of the parameter block
- This ensures consistency across all functions in the module
- Place them after all mandatory and optional business-specific parameters
- Always in this order: Organization first, then PAT last

**Example of correct parameter ordering:**
```powershell
param (
    # Business-specific mandatory parameters first
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Project,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryId,

    # Business-specific optional parameters
    [Parameter()]
    [string]$BranchName,

    # Organization parameter (second to last)
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Organization = $env:ORGANIZATION,

    # PAT parameter (always last)
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PAT = $env:PAT
)
```

### 2. Validation Placement
Place the validation block:
- **After** parameter display (verbose logging)
- **Before** any API calls or business logic
- **Inside** the `process` block
- **Within** the try-catch block

### 3. Error Messages
Use clear, actionable error messages that:
- Explain what's missing
- Provide the exact command to fix it
- Mention both environment variable and parameter options

### 4. Comment Style
Use consistent comments that explain **why** the validation is needed:

```powershell
# Validate Organization (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
```

## Functions Updated
All 26 functions in the `OMG.PSUtilities.AzureDevOps` module have been updated with this pattern:

### Get-* Functions (9)
- `Get-PSUADOPipeline`
- `Get-PSUADOPipelineBuild`
- `Get-PSUADOPipelineLatestRun`
- `Get-PSUADOProjectList`
- `Get-PSUADOPullRequest`
- `Get-PSUADOPullRequestInventory`
- `Get-PSUADORepoBranchList`
- `Get-PSUADORepositories`
- `Get-PSUADOVariableGroupInventory`
- `Get-PSUADOWorkItem`

### New-* Functions (7)
- `New-PSUADOBug`
- `New-PSUADOPullRequest`
- `New-PSUADOSpike`
- `New-PSUADOTask`
- `New-PSUADOUserStory`
- `New-PSUADOVariable`
- `New-PSUADOVariableGroup`

### Set-* Functions (6)
- `Set-PSUADOBug`
- `Set-PSUADOSpike`
- `Set-PSUADOTask`
- `Set-PSUADOUserStory`
- `Set-PSUADOVariable`
- `Set-PSUADOVariableGroup`

### Other Functions (4)
- `Approve-PSUADOPullRequest`
- `Complete-PSUADOPullRequest`
- `Invoke-PSUADORepoClone`

## Testing the Validation

### Test 1: Environment Variable Not Set
```powershell
# Clear environment variable
Remove-Item Env:\ORGANIZATION -ErrorAction SilentlyContinue

# Try to call function without passing parameter
Get-PSUADOProjectList

# Expected Result:
# Error: "The default value for the 'ORGANIZATION' environment variable is not set.
# Set it using: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>' 
# or provide via -Organization parameter."
```

### Test 2: Environment Variable Set
```powershell
# Set environment variable
Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value 'myorg'
Set-PSUUserEnvironmentVariable -Name 'PAT' -Value 'my_token'

# Call function without parameters (should work)
Get-PSUADOProjectList

# Expected Result: Success
```

### Test 3: Explicit Parameter
```powershell
# Pass parameter explicitly (overrides environment variable)
Get-PSUADOProjectList -Organization 'different_org' -PAT 'different_token'

# Expected Result: Success with different org
```

## Benefits

1. **Early Detection**: Catches missing configuration before making API calls
2. **Clear Guidance**: Error messages tell users exactly how to fix the problem
3. **Consistent Experience**: All functions behave the same way
4. **Better Debugging**: Users know immediately if environment variables are misconfigured
5. **Prevents Confusion**: No silent failures or cryptic API errors

## Parameter Ordering Standard

### Required Order
All functions in the `OMG.PSUtilities.AzureDevOps` module **MUST** follow this parameter ordering:

1. **Business-specific mandatory parameters** (e.g., Project, RepositoryId, WorkItemId)
2. **Business-specific optional parameters** (e.g., BranchName, Description, Tags)
3. **Organization parameter** (second to last position)
4. **PAT parameter** (always in the last position)

### Rationale
- **Consistency**: Makes all functions predictable and easier to learn
- **Tab Completion**: PowerShell's tab completion presents parameters in definition order
- **Discoverability**: Users encounter business parameters before authentication parameters
- **Readability**: Separates business logic from infrastructure concerns
- **Maintainability**: Easy to spot when new functions don't follow the pattern

### Examples

#### ✅ CORRECT - Proper Parameter Order
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

#### ❌ INCORRECT - Wrong Parameter Order
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

### Verification Checklist
Before committing new or modified functions, verify:
- [ ] Organization parameter is second to last
- [ ] PAT parameter is last
- [ ] Both parameters use `$env:ORGANIZATION` and `$env:PAT` as defaults
- [ ] Both parameters have `[ValidateNotNullOrEmpty()]` attribute
- [ ] Runtime validation is present in the process block

## Related Functions

- `Set-PSUUserEnvironmentVariable`: Helper function to set user-level environment variables
- `Get-PSUAdoAuthHeader`: Creates authentication headers using PAT

## Version History

- **October 15, 2025**: Initial implementation across all 26 Azure DevOps module functions
- Applied to `OMG.PSUtilities.AzureDevOps` module v1.0.9+

## References

- [PowerShell ValidateNotNullOrEmpty Documentation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters)
- [Azure DevOps REST API Authentication](https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/authentication-guidance)

---

## Summary Checklist for New Functions

When creating or modifying functions in `OMG.PSUtilities.AzureDevOps`, ensure:

### Parameter Block
- [ ] Organization parameter is **second to last** in the parameter block
- [ ] PAT parameter is **always last** in the parameter block
- [ ] Both use environment variable defaults: `$env:ORGANIZATION` and `$env:PAT`
- [ ] Both have `[ValidateNotNullOrEmpty()]` attribute
- [ ] Both are optional parameters: `[Parameter()]` (not Mandatory)

### Process Block
- [ ] Parameter display code includes PAT masking logic
- [ ] Organization validation appears immediately after parameter display
- [ ] PAT validation appears immediately after Organization validation
- [ ] Both validations use the standardized error message format
- [ ] Comments explain why validation is needed (ValidateNotNullOrEmpty limitation)
- [ ] All code is within try-catch block with `$PSCmdlet.ThrowTerminatingError($_)`

### Error Messages
- [ ] Clear explanation of what's missing
- [ ] Exact command to set the environment variable
- [ ] Mentions both environment variable and parameter options

### Testing
- [ ] Test with environment variables not set (should throw clear error)
- [ ] Test with environment variables set (should work)
- [ ] Test with explicit parameters (should override environment variables)

---

**Author**: Lakshmanachari Panuganti  
**Date**: October 15, 2025  
**Module**: OMG.PSUtilities.AzureDevOps  
**Repository**: https://github.com/lakshmanachari-panuganti/OMG.PSUtilities

**Status**: ✅ All 26 functions updated and verified
