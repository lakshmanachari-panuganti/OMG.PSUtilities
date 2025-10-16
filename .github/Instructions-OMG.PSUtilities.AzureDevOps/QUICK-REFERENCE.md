# ═══════════════════════════════════════════════════════════════════════════
# 🎯 QUICK REFERENCE CARD - Test Suite Commands
# ═══════════════════════════════════════════════════════════════════════════

## 📍 YOU ARE HERE
Location: C:\repos\OMG.PSUtilities
Target: https://dev.azure.com/Lakshmanachari/OMG.PSUtilities/_git/Test-Repo1

## ⚡ QUICK START (Copy & Paste)

# 1. Validate everything is ready
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Test-PreFlightValidation.ps1

# 2. Run full test suite with report
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive -VerboseOutput -ExportReport

# 3. Check results
Get-Content .\.github\Instructions-OMG.PSUtilities.AzureDevOps\TestResults-*.json | ConvertFrom-Json | Select-Object TestName, Success, Message | Format-Table -AutoSize

## 📋 ALL AVAILABLE COMMANDS

### Validation Only
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Test-PreFlightValidation.ps1

### Quick Smoke Test (30 seconds)
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Quick

### Full Comprehensive Test (5-10 minutes)
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive

### With Verbose Output
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive -VerboseOutput

### With HTML Report
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive -ExportReport

### Keep Test Resources
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive -SkipCleanup

### Debug Mode (All Options)
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive -VerboseOutput -SkipCleanup -ExportReport

### Skip Validation (Not Recommended)
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive -SkipValidation

## 🔍 VIEW RESULTS

### View Latest JSON Results
Get-Content (Get-ChildItem .\.github\Instructions-OMG.PSUtilities.AzureDevOps\TestResults-*.json | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName | ConvertFrom-Json | Format-List

### View All Test Names and Status
(Get-Content .\.github\Instructions-OMG.PSUtilities.AzureDevOps\TestResults-*.json | ConvertFrom-Json | Sort-Object -Unique TestName).TestName

### Count Passed/Failed
$results = Get-Content .\.github\Instructions-OMG.PSUtilities.AzureDevOps\TestResults-*.json | ConvertFrom-Json
"Passed: $(($results | Where-Object {$_.Success -eq $true}).Count)"
"Failed: $(($results | Where-Object {$_.Success -eq $false}).Count)"

### Open Latest HTML Report
Start-Process (Get-ChildItem .\.github\Instructions-OMG.PSUtilities.AzureDevOps\TestReport-*.html | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

## 🧪 TEST WHAT'S BEING VALIDATED

26+ Functions Tested:
├─ Project & Repository (3)
│  ├─ Get-PSUADOProjectList
│  ├─ Get-PSUADORepositories
│  └─ Get-PSUADORepoBranchList
│
├─ Variable Groups (5)
│  ├─ New-PSUADOVariableGroup
│  ├─ New-PSUADOVariable
│  ├─ Set-PSUADOVariable
│  ├─ Set-PSUADOVariableGroup
│  └─ Get-PSUADOVariableGroupInventory
│
├─ Pull Requests (5)
│  ├─ New-PSUADOPullRequest
│  ├─ Get-PSUADOPullRequest
│  ├─ Get-PSUADOPullRequestInventory
│  ├─ Approve-PSUADOPullRequest
│  └─ Complete-PSUADOPullRequest
│
├─ Work Items (6)
│  ├─ New-PSUADOUserStory
│  ├─ New-PSUADOTask
│  ├─ New-PSUADOBug
│  ├─ Set-PSUADOTask
│  ├─ Set-PSUADOBug
│  └─ Set-PSUADOSpike
│
└─ Pipelines (3)
   ├─ Get-PSUADOPipeline
   ├─ Get-PSUADOPipelineLatestRun
   └─ Get-PSUADOPipelineBuild

## 🎯 SUCCESS CRITERIA

100%    = Excellent (All tests pass)
90-99%  = Good (Expected skips for PR, pipelines)
70-89%  = Review (Some issues need attention)
<70%    = Critical (Major problems)

## 🧹 CLEANUP

### List Test Resources Created
Get-ChildItem .\.github\Instructions-OMG.PSUtilities.AzureDevOps\TestResults-*.json | ForEach-Object {
    $data = Get-Content $_.FullName | ConvertFrom-Json
    $data | Where-Object {$_.Data -and $_.Data.Id} | Select-Object TestName, @{N='ResourceId';E={$_.Data.Id}}
}

### Clean Old Test Results
Remove-Item .\.github\Instructions-OMG.PSUtilities.AzureDevOps\TestResults-*.json -WhatIf
Remove-Item .\.github\Instructions-OMG.PSUtilities.AzureDevOps\TestReport-*.html -WhatIf

### Remove Test Resources from Azure DevOps
# Navigate to:
# Variable Groups: https://dev.azure.com/Lakshmanachari/OMG.PSUtilities/_library?itemType=VariableGroups
# Work Items: https://dev.azure.com/Lakshmanachari/OMG.PSUtilities/_workitems

## ⚠️ TROUBLESHOOTING

### If Tests Fail
1. .\.github\Instructions-OMG.PSUtilities.AzureDevOps\Test-PreFlightValidation.ps1
2. Check $env:ORGANIZATION = "Lakshmanachari"
3. Check $env:PAT is valid and not expired
4. Verify PAT permissions: Code (R/W), Work Items (R/W), Variable Groups (Manage)

### If Environment Not Set
Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value 'Lakshmanachari'
Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<your_token>'

### View Environment
"Organization: $env:ORGANIZATION"
"PAT Length: $($env:PAT.Length)"

## 📊 TEST OUTPUT FILES

TestResults-YYYYMMDD-HHMMSS.json  → Detailed test results
TestReport-YYYYMMDD-HHMMSS.html   → Visual HTML report (with -ExportReport)

## 🎨 COLOR GUIDE

Green  ✓ = Passed
Red    ✗ = Failed
Yellow ⚠ = Warning
Cyan   ═ = Section header
Gray   • = Details

## 🚀 RECOMMENDED FIRST RUN

.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive -VerboseOutput -ExportReport

This will:
✅ Validate environment
✅ Run all 26+ tests
✅ Show detailed progress
✅ Generate HTML report
✅ Open report in browser
✅ Export JSON results
✅ Clean up test resources

## ═══════════════════════════════════════════════════════════════════════════
## 🎉 READY TO GO! Copy the command above and enjoy your tea! ☕
## ═══════════════════════════════════════════════════════════════════════════
