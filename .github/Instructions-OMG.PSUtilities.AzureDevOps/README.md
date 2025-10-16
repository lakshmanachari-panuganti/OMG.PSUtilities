# OMG.PSUtilities.AzureDevOps - Comprehensive Test Suite

## 📍 Location
All test scripts and documentation are in:
```
.github\Instructions-OMG.PSUtilities.AzureDevOps\
```

## 🚀 Quick Start

### Run Complete Test Suite
```powershell
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive -VerboseOutput -ExportReport
```

### Validate Environment First
```powershell
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Test-PreFlightValidation.ps1
```

### Quick Smoke Test (1 minute)
```powershell
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Quick
```

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| **README.md** (this file) | Quick start guide |
| **INDEX.md** | Complete documentation index |
| **WELCOME-BACK.md** | Comprehensive welcome guide |
| **QUICK-REFERENCE.md** | One-page command reference |
| **COMPREHENSIVE-TEST-SUITE-SUMMARY.md** | Full feature documentation |
| **TEST-ARCHITECTURE.md** | Visual architecture & flow diagrams |
| **WHAT-TO-EXPECT.md** | Screen-by-screen execution walkthrough |
| **Test-AzureDevOps-Comprehensive-README.md** | Detailed usage & troubleshooting |

## 🛠️ Test Scripts

| Script | Purpose |
|--------|---------|
| **Run-MasterTest.ps1** | Main orchestrator - START HERE |
| **Test-PreFlightValidation.ps1** | Environment validation (8 checks) |
| **Test-AzureDevOps-Comprehensive.ps1** | Core test engine (26+ tests) |
| **Debug-SetPSUADOVariable.ps1** | Debug tool for variable operations |

## 🎯 Test Coverage

Tests all 26 functions in `OMG.PSUtilities.AzureDevOps` module:

- ✅ **Project & Repository Management** (3 functions)
- ✅ **Variable Groups** (5 functions) - Including newly updated functions!
- ✅ **Pull Requests** (5 functions)
- ✅ **Work Items** (6 functions)
- ✅ **Pipelines** (3 functions)
- ✅ **Additional Features** (4 functions)

## 🌐 Test Target

- **Organization**: Lakshmanachari (from `$env:ORGANIZATION`)
- **Project**: OMG.PSUtilities
- **Repository**: Test-Repo1
- **URL**: https://dev.azure.com/Lakshmanachari/OMG.PSUtilities/_git/Test-Repo1

## ⏱️ Expected Duration

- **Pre-Flight Validation**: 30 seconds
- **Quick Test**: 1 minute
- **Comprehensive Test**: 5-10 minutes

## 📊 Output

The test suite generates:

1. **Color-coded terminal output** (real-time progress)
2. **JSON results file** (detailed test data)
3. **HTML report** (visual charts & tables, auto-opens in browser)

Output files are saved in the same folder as the scripts:
```
.github\Instructions-OMG.PSUtilities.AzureDevOps\
├─ TestResults-YYYYMMDD-HHMMSS.json
└─ TestReport-YYYYMMDD-HHMMSS.html
```

## ✅ Success Criteria

- **Excellent**: 90-100% success rate
- **Good**: 70-89% success rate
- **Needs attention**: <70% success rate

**Note**: Some tests may be "skipped" (counts as success):
- PR creation (if branches identical)
- Pipeline tests (if no pipelines exist)

## 🔧 Prerequisites

Before running tests, ensure:

1. ✅ PowerShell 5.1 or later
2. ✅ Environment variables set:
   ```powershell
   Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value 'Lakshmanachari'
   Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<your_pat>'
   ```
3. ✅ PAT has permissions:
   - Code (Read & Write)
   - Work Items (Read & Write)
   - Variable Groups (Manage)
4. ✅ Test-Repo1 exists and is accessible

## 📖 Getting Started

### First Time Users
1. Read **WELCOME-BACK.md** for complete overview
2. Run validation: `Test-PreFlightValidation.ps1`
3. Review **WHAT-TO-EXPECT.md** to see execution flow
4. Run comprehensive test: `Run-MasterTest.ps1`

### Quick Reference Users
- Jump to **QUICK-REFERENCE.md** for commands
- All copy/paste ready

### Architecture Enthusiasts
- Check **TEST-ARCHITECTURE.md** for visual diagrams
- See how all components interact

## 🆘 Troubleshooting

If tests fail, check:

1. **Environment variables** - Are ORGANIZATION and PAT set correctly?
2. **PAT permissions** - Does it have Code, Work Items, and Variable Groups access?
3. **Repository access** - Can you access Test-Repo1 in Azure DevOps portal?
4. **Network connectivity** - Can you reach dev.azure.com?

For detailed troubleshooting, see **Test-AzureDevOps-Comprehensive-README.md**.

## 🎓 Pro Tips

1. **Use verbose mode** for first run: `-VerboseOutput`
2. **Generate HTML report** for visual results: `-ExportReport`
3. **Skip cleanup** to inspect created resources: `-SkipCleanup`
4. **Run validation first** to catch environment issues early

## 📅 Recent Updates

### October 15, 2025
- ✅ Updated parameter standardization: All functions now use `$env:ORGANIZATION` as default
- ✅ Created comprehensive test suite with 26+ tests
- ✅ Added 7 documentation files for different user levels
- ✅ Implemented HTML + JSON reporting
- ✅ Added color-coded terminal output
- ✅ Created pre-flight validation system

## 📞 Need Help?

1. **Quick answers**: Read **QUICK-REFERENCE.md**
2. **Detailed help**: Read **COMPREHENSIVE-TEST-SUITE-SUMMARY.md**
3. **Visual understanding**: Read **TEST-ARCHITECTURE.md**
4. **Step-by-step**: Read **WHAT-TO-EXPECT.md**
5. **Troubleshooting**: Read **Test-AzureDevOps-Comprehensive-README.md**

---

**Ready to test?** Run this command:
```powershell
.\.github\Instructions-OMG.PSUtilities.AzureDevOps\Run-MasterTest.ps1 -TestType Comprehensive -VerboseOutput -ExportReport
```

🎉 **Happy Testing!**
