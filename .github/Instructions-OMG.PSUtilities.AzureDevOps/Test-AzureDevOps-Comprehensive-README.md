# Comprehensive Test Suite - Quick Reference Guide

## 📋 Overview
This comprehensive test suite validates all 26 functions in the OMG.PSUtilities.AzureDevOps module against your Test-Repo1 repository.

## 🎯 Test Target
- **Organization**: Lakshmanachari (from `$env:ORGANIZATION`)
- **Project**: OMG.PSUtilities
- **Repository**: Test-Repo1
- **URL**: https://dev.azure.com/Lakshmanachari/OMG.PSUtilities/_git/Test-Repo1

## 🚀 How to Run

### Basic Execution
```powershell
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Test-AzureDevOps-Comprehensive.ps1
```

### With Verbose Output
```powershell
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Test-AzureDevOps-Comprehensive.ps1 -VerboseOutput
```

### Keep Test Resources (Skip Cleanup)
```powershell
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Test-AzureDevOps-Comprehensive.ps1 -SkipCleanup
```

### Full Verbose with Cleanup Disabled
```powershell
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Test-AzureDevOps-Comprehensive.ps1 -VerboseOutput -SkipCleanup
```

## 📊 Test Sections

### Section 0: Pre-Flight Checks ✈️
- Environment variable validation
- Module import
- Function listing

### Section 1: Project & Repository Functions 📁
1. **Get-PSUADOProjectList** - List all projects
2. **Get-PSUADORepositories** - Find Test-Repo1
3. **Get-PSUADORepoBranchList** - List branches

### Section 2: Variable Group Functions 🔐
4. **New-PSUADOVariableGroup** - Create test variable group
5. **New-PSUADOVariable** - Add variables (regular & secret)
6. **Set-PSUADOVariable** - Update and add variables
7. **Set-PSUADOVariableGroup** - Update group properties
8. **Get-PSUADOVariableGroupInventory** - List all variable groups

### Section 3: Pull Request Functions 🔀
9. **New-PSUADOPullRequest** - Create test PR
10. **Get-PSUADOPullRequest** - List pull requests
11. **Get-PSUADOPullRequestInventory** - PR inventory
12. **Approve-PSUADOPullRequest** - Approve the test PR
13. **Complete-PSUADOPullRequest** - Complete the test PR

### Section 4: Work Item Functions 📝
14. **New-PSUADOUserStory** - Create user story
15. **New-PSUADOTask** - Create task (linked to user story)
16. **New-PSUADOBug** - Create bug
17. **Set-PSUADOTask** - Update task state
18. **Set-PSUADOBug** - Update bug state
19. **Set-PSUADOSpike** - (Skipped - requires existing spike)

### Section 5: Pipeline Functions ⚙️
20. **Get-PSUADOPipeline** - List pipelines
21. **Get-PSUADOPipelineLatestRun** - Get latest pipeline run
22. **Get-PSUADOPipelineBuild** - List builds

### Section 6: Cleanup 🧹
- Lists created resources for manual cleanup if needed

### Section 7: Summary 📈
- Success/failure counts
- Duration
- Results exported to JSON

## 🎨 Output Features

### Color-Coded Results
- ✅ **Green**: Successful tests
- ❌ **Red**: Failed tests
- ⚠️ **Yellow**: Warnings
- ℹ️ **Cyan**: Information
- 📊 **Gray**: Details

### Test Result Object
The script returns a summary object:
```powershell
$results = .\.github\Instructions-OMG.PSUtilities.AzureDevOps\Test-AzureDevOps-Comprehensive.ps1

$results.TotalTests    # Total number of tests
$results.Passed        # Number of passed tests
$results.Failed        # Number of failed tests
$results.SuccessRate   # Percentage
$results.Duration      # TimeSpan object
$results.ResultsFile   # Path to JSON results
$results.TestResults   # Detailed array of all test results
```

## 📦 Test Resources Created

The test suite creates the following resources in your Azure DevOps:

1. **Variable Group** (timestamped name)
   - 4-5 variables (including secret variables)
   
2. **Work Items**
   - 1 User Story
   - 1 Task (linked to user story)
   - 1 Bug
   
3. **Pull Request** (if branches allow)
   - Attempted from default branch
   - Approved and completed

## 🧪 Expected Results

### All Tests Should Pass ✅
- **26+ individual tests** across all function categories
- Some tests may be "Skipped" (counted as success) if:
  - No pipelines exist in the project
  - Branches cannot be merged for PR
  - No suitable work items for updates

### Acceptable Skips
- Pull Request creation (if branches are identical)
- Pipeline tests (if no pipelines configured)
- Set-PSUADOSpike (requires existing spike work item)

## 🔍 Troubleshooting

### Test Fails: "Organization is required"
```powershell
Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value 'Lakshmanachari'
```

### Test Fails: PAT Authentication
```powershell
# Ensure PAT has correct permissions:
# - Code (Read, Write)
# - Work Items (Read, Write, Manage)
# - Variable Groups (Read, Create, Manage)
# - Build (Read, Execute)
```

### Test Fails: Repository Not Found
- Verify repository name is exactly "Test-Repo1"
- Check repository exists in OMG.PSUtilities project
- Ensure PAT has access to the repository

## 📄 Results Export

Results are automatically exported to:
```
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\TestResults-YYYYMMDD-HHMMSS.json
```

View results:
```powershell
Get-Content .\.github\Instructions-OMG.PSUtilities.AzureDevOps\TestResults-*.json | ConvertFrom-Json | 
    Select-Object TestName, Success, Message | Format-Table -AutoSize
```

## 🎯 Success Criteria

### ✅ Excellent (100% Pass Rate)
All tests pass, all functions working correctly

### ✅ Good (90-99% Pass Rate)
Minor expected failures (PR creation, etc.)

### ⚠️ Needs Attention (70-89% Pass Rate)
Some functions have issues, review failed tests

### ❌ Critical (<70% Pass Rate)
Major issues, module needs debugging

## 🔄 Manual Cleanup

If you ran with `-SkipCleanup`, manually clean up:

### Variable Groups
```powershell
# View in portal:
https://dev.azure.com/Lakshmanachari/OMG.PSUtilities/_library?itemType=VariableGroups

# Filter by name starting with "TestVarGroup-"
```

### Work Items
```powershell
# Close work items in Azure DevOps
# Don't delete - just close/remove them
```

## 💡 Tips

1. **First Run**: Use `-VerboseOutput` to see detailed information
2. **Regular Testing**: Run without flags for clean summary
3. **Debugging**: Use `-SkipCleanup -VerboseOutput` to inspect resources
4. **CI/CD**: Integrate into your pipeline for continuous validation

## 📞 Support

If tests fail unexpectedly:
1. Check the detailed error messages
2. Review the exported JSON results file
3. Verify Azure DevOps permissions
4. Ensure Test-Repo1 exists and is accessible
5. Check that environment variables are set correctly

---

**Happy Testing!** ☕🚀
