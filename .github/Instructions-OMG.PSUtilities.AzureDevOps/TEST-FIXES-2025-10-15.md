# Test Suite Fixes - October 15, 2025

## 📊 Test Results Analysis

**Test Run**: TestResults-20251015-173819.json  
**Total Tests**: 26  
**Passed**: 19  
**Failed**: 7  
**Success Rate**: 73%

---

## ❌ Issues Found and Fixed

### 1. ✅ FIXED: Get-PSUADORepoBranchList - Parameter Name Error
**Error**: `404 (Not Found)`  
**Root Cause**: Test was using `-Repository` parameter instead of `-RepositoryName`  
**Fix**: Changed parameter name to `-RepositoryName` in test script

```powershell
# BEFORE:
$branches = Get-PSUADORepoBranchList -Project $projectName -Repository $repositoryName

# AFTER:
$branches = Get-PSUADORepoBranchList -Project $projectName -RepositoryName $repositoryName
```

---

### 2. ✅ FIXED: New-PSUADOPullRequest - Branch Format Validation
**Error**: `Cannot validate argument on parameter 'SourceBranch'. SourceBranch must be in the format 'refs/heads/branch-name'.`  
**Root Cause**: Test was passing branch name without `refs/heads/` prefix  
**Fix**: Added proper branch ref format

```powershell
# BEFORE:
-SourceBranch $defaultBranch `
-TargetBranch $defaultBranch `

# AFTER:
-SourceBranch "refs/heads/$defaultBranch" `
-TargetBranch "refs/heads/$defaultBranch" `
```

---

### 3. ✅ FIXED: Get-PSUADOPullRequest - Ambiguous Parameter Name
**Error**: `Parameter cannot be processed because the parameter name 'Repository' is ambiguous. Possible matches include: -RepositoryId -RepositoryName.`  
**Root Cause**: Function has two parameters (`-RepositoryId` and `-RepositoryName`), test used `-Repository`  
**Fix**: Changed to use specific parameter name

```powershell
# BEFORE:
$pullRequests = Get-PSUADOPullRequest -Project $projectName -Repository $repositoryName

# AFTER:
$pullRequests = Get-PSUADOPullRequest -Project $projectName -RepositoryName $repositoryName
```

---

### 4. ✅ FIXED: Get-PSUADOPullRequestInventory - Invalid Parameter
**Error**: `A parameter cannot be found that matches parameter name 'Project'.`  
**Root Cause**: This function doesn't accept a `-Project` parameter (it scans all projects)  
**Fix**: Removed the `-Project` parameter from test call

```powershell
# BEFORE:
$prInventory = Get-PSUADOPullRequestInventory -Project $projectName

# AFTER:
$prInventory = Get-PSUADOPullRequestInventory
```

---

### 5. ✅ FIXED: New-PSUADOBug - Wrong Parameter Name
**Error**: `A parameter cannot be found that matches parameter name 'ReproSteps'.`  
**Root Cause**: Test used abbreviated parameter name `-ReproSteps` instead of full name `-ReproductionSteps`  
**Fix**: Used correct parameter name and added `-Description` (mandatory)

```powershell
# BEFORE:
$newBug = New-PSUADOBug `
    -Project $projectName `
    -Title "Test Bug..." `
    -ReproSteps "1. Run automated test..." `

# AFTER:
$newBug = New-PSUADOBug `
    -Project $projectName `
    -Title "Test Bug..." `
    -Description "This is a test bug created by the automated test suite" `
    -ReproductionSteps "1. Run automated test..." `
```

---

### 6. ✅ FIXED: Set-PSUADOTask - Invalid State Value
**Error**: `The argument "Active" does not belong to the set "To Do,In Progress,Done,Removed" specified by the ValidateSet attribute.`  
**Root Cause**: Test used "Active" which is not a valid Task state  
**Valid States**: `'To Do'`, `'In Progress'`, `'Done'`, `'Removed'`  
**Fix**: Changed to use valid state

```powershell
# BEFORE:
-State "Active" `

# AFTER:
-State "In Progress" `
```

---

### 7. ⚠️ INVESTIGATING: Set-PSUADOVariableGroup - Update Verification
**Error**: `Name not updated correctly` and `Description not updated correctly`  
**Root Cause**: Unknown - function call succeeds but returned values don't match expected  
**Status**: Requires further investigation  

**Possible Causes**:
1. Azure DevOps API may not be updating these fields
2. Response may not include updated fields immediately
3. May require re-fetching the variable group to see updates

**Current Test Code**:
```powershell
$updatedGroup = Set-PSUADOVariableGroup `
    -VariableGroupId $testVariableGroupId `
    -VariableGroupName "$testVarGroupName-Updated" `
    -Description "Updated description from test suite" `
    -Project $projectName `
    -Verbose:$VerboseOutput

# Verification checks
if ($updatedGroup.Name -eq "$testVarGroupName-Updated") {
    # FAILS - Name doesn't match
}
if ($updatedGroup.Description -eq "Updated description from test suite") {
    # FAILS - Description doesn't match
}
```

**Next Steps**:
- Add verbose output to see actual returned values
- Check if Azure DevOps API returns updated values immediately
- Consider fetching the variable group again to verify updates

---

## 📈 Expected Results After Fixes

| Test | Before | After | Status |
|------|--------|-------|--------|
| Get-PSUADORepoBranchList | ❌ Failed | ✅ Should Pass | Fixed |
| New-PSUADOPullRequest | ❌ Failed | ⚠️ May Skip* | Fixed |
| Get-PSUADOPullRequest | ❌ Failed | ✅ Should Pass | Fixed |
| Get-PSUADOPullRequestInventory | ❌ Failed | ✅ Should Pass | Fixed |
| New-PSUADOBug | ❌ Failed | ✅ Should Pass | Fixed |
| Set-PSUADOTask | ❌ Failed | ✅ Should Pass | Fixed |
| Set-PSUADOVariableGroup (Name) | ❌ Failed | ⚠️ Investigating | Needs Analysis |
| Set-PSUADOVariableGroup (Description) | ❌ Failed | ⚠️ Investigating | Needs Analysis |

*May skip if branches cannot be merged (same source/target)

---

## 🎯 Summary

### Fixed Issues: 6/8 (75%)
- ✅ Parameter name corrections (3 tests)
- ✅ Parameter format corrections (1 test)
- ✅ Missing mandatory parameters (1 test)
- ✅ Invalid enum values (1 test)

### Remaining Issues: 2/8 (25%)
- ⚠️ Set-PSUADOVariableGroup validation (requires investigation)

### Expected New Success Rate
- **Current**: 73% (19/26)
- **After Fixes**: ~85-90% (22-23/26 estimated)
- **Perfect Score**: 96% (25/26) if VariableGroup test passes

---

## 📝 Files Modified

### Test Script
- `Test-AzureDevOps-Comprehensive.ps1`
  - Line ~164: Fixed Get-PSUADORepoBranchList parameter
  - Line ~365: Fixed New-PSUADOPullRequest branch format
  - Line ~390: Fixed Get-PSUADOPullRequest parameter  
  - Line ~407: Fixed Get-PSUADOPullRequestInventory (removed Project param)
  - Line ~520: Fixed New-PSUADOBug parameter name and added Description
  - Line ~540: Fixed Set-PSUADOTask state value

---

## 🔄 Next Actions

1. **Run Tests Again**: Execute full test suite to verify fixes
   ```powershell
   .\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive -VerboseOutput -ExportReport
   ```

2. **Investigate VariableGroup Issue**: 
   - Run with `-VerboseOutput` to see actual returned values
   - Check Azure DevOps portal to verify if updates are actually applied
   - Consider API response timing issues

3. **Update Documentation**: Update test documentation with findings

---

**Analysis Date**: October 15, 2025  
**Analyst**: GitHub Copilot  
**Status**: 6 of 8 issues fixed, 2 under investigation
