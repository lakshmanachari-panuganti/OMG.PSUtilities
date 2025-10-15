# Test Suite Architecture & Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                   🎯 COMPREHENSIVE TEST SUITE ARCHITECTURE                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘


                              ┌─────────────────┐
                              │  USER EXECUTES  │
                              │  Run-MasterTest │
                              └────────┬────────┘
                                       │
                    ┌──────────────────┴──────────────────┐
                    │                                     │
                    ▼                                     ▼
          ┌──────────────────┐               ┌───────────────────┐
          │  STEP 1:         │               │  Optional:        │
          │  Pre-Flight      │◄──────────────│  Skip Validation  │
          │  Validation      │               └───────────────────┘
          └────────┬─────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
   ┌─────────┐         ┌─────────────┐
   │ Env Vars│         │ Connectivity│
   │  Check  │         │    Check    │
   └────┬────┘         └──────┬──────┘
        │                     │
        └──────────┬──────────┘
                   │ All ✓
                   ▼
          ┌──────────────────┐
          │  STEP 2:         │
          │  Select Test     │
          │  Type            │
          └────────┬─────────┘
                   │
        ┌──────────┼──────────┬──────────────┐
        │          │          │              │
        ▼          ▼          ▼              ▼
   ┌─────────┐┌────────┐┌──────────┐  ┌──────────────────┐
   │Validate ││ Quick  ││Comprehens││  │Test-AzureDevOps- │
   │  Only   ││ Test   ││ive Test  ├──►│Comprehensive.ps1 │
   │ (Done)  ││(5 func)││(26+ func)│  └────────┬─────────┘
   └─────────┘└────────┘└──────────┘           │
                                                │
                         ┌──────────────────────┴──────────────────────┐
                         │                                             │
                         │     COMPREHENSIVE TEST SECTIONS             │
                         │                                             │
                         │  ┌────────────────────────────────────┐    │
                         │  │ Section 0: Pre-Flight (3 tests)    │    │
                         │  └────────────────────────────────────┘    │
                         │           ↓                                 │
                         │  ┌────────────────────────────────────┐    │
                         │  │ Section 1: Projects/Repos (3 tests)│    │
                         │  └────────────────────────────────────┘    │
                         │           ↓                                 │
                         │  ┌────────────────────────────────────┐    │
                         │  │ Section 2: Variable Groups (8 test)│    │
                         │  │  • Create variable group            │    │
                         │  │  • Add variables (regular + secret) │    │
                         │  │  • Update variables                 │    │
                         │  │  • Update group properties          │    │
                         │  │  • Get inventory                    │    │
                         │  └────────────────────────────────────┘    │
                         │           ↓                                 │
                         │  ┌────────────────────────────────────┐    │
                         │  │ Section 3: Pull Requests (5 tests) │    │
                         │  │  • Create PR                        │    │
                         │  │  • Get PRs                          │    │
                         │  │  • Get PR inventory                 │    │
                         │  │  • Approve PR                       │    │
                         │  │  • Complete PR                      │    │
                         │  └────────────────────────────────────┘    │
                         │           ↓                                 │
                         │  ┌────────────────────────────────────┐    │
                         │  │ Section 4: Work Items (6 tests)    │    │
                         │  │  • Create User Story                │    │
                         │  │  • Create Task (linked to story)    │    │
                         │  │  • Create Bug                       │    │
                         │  │  • Update Task state                │    │
                         │  │  • Update Bug state                 │    │
                         │  └────────────────────────────────────┘    │
                         │           ↓                                 │
                         │  ┌────────────────────────────────────┐    │
                         │  │ Section 5: Pipelines (3 tests)     │    │
                         │  │  • Get pipelines                    │    │
                         │  │  • Get latest run                   │    │
                         │  │  • Get builds                       │    │
                         │  └────────────────────────────────────┘    │
                         │           ↓                                 │
                         │  ┌────────────────────────────────────┐    │
                         │  │ Section 6: Cleanup (optional)      │    │
                         │  └────────────────────────────────────┘    │
                         │           ↓                                 │
                         │  ┌────────────────────────────────────┐    │
                         │  │ Section 7: Summary & Export        │    │
                         │  └────────────────────────────────────┘    │
                         └─────────────────┬───────────────────────────┘
                                           │
                         ┌─────────────────┴───────────────────┐
                         │                                     │
                         ▼                                     ▼
                ┌─────────────────┐               ┌─────────────────────┐
                │  STEP 3:        │               │  Optional:          │
                │  Generate       │◄──────────────│  -ExportReport flag │
                │  Report         │               └─────────────────────┘
                └────────┬────────┘
                         │
                ┌────────┼────────┐
                │        │        │
                ▼        ▼        ▼
          ┌─────────┐ ┌────┐ ┌──────┐
          │  JSON   │ │HTML│ │Screen│
          │ Results │ │Rpt │ │Output│
          └─────────┘ └────┘ └──────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                        📊 TEST RESULT FLOW                                  │
└─────────────────────────────────────────────────────────────────────────────┘

Each Test:
    │
    ├─► Try Execute Function
    │
    ├─► Capture Result
    │   ├─ Success: ✓ Green
    │   └─ Failure: ✗ Red
    │
    ├─► Store in $testResults array
    │   └─ [TestName, Success, Message, Data, Timestamp]
    │
    └─► Continue to next test

After All Tests:
    │
    ├─► Calculate Summary
    │   ├─ Total Tests
    │   ├─ Passed
    │   ├─ Failed
    │   └─ Success Rate
    │
    ├─► Group by Function
    │
    ├─► Export to JSON
    │
    ├─► Generate HTML (if -ExportReport)
    │
    └─► Display Summary
        └─► Return Results Object


┌─────────────────────────────────────────────────────────────────────────────┐
│                     🎯 AZURE DEVOPS INTERACTION                             │
└─────────────────────────────────────────────────────────────────────────────┘

Test Suite                          Azure DevOps
    │                                    │
    ├──► GET Projects ─────────────────►│
    │◄─── Project List ──────────────────┤
    │                                    │
    ├──► GET Repositories ─────────────►│
    │◄─── Repo List ────────────────────┤
    │                                    │
    ├──► POST Create VarGroup ─────────►│
    │◄─── VarGroup ID ──────────────────┤
    │                                    │
    ├──► PUT Add Variable ─────────────►│
    │◄─── Success ──────────────────────┤
    │                                    │
    ├──► PUT Update Variable ──────────►│
    │◄─── Success ──────────────────────┤
    │                                    │
    ├──► POST Create PR ───────────────►│
    │◄─── PR ID ────────────────────────┤
    │                                    │
    ├──► POST Approve PR ──────────────►│
    │◄─── Success ──────────────────────┤
    │                                    │
    ├──► POST Complete PR ─────────────►│
    │◄─── Success ──────────────────────┤
    │                                    │
    ├──► POST Create Work Items ───────►│
    │◄─── Work Item IDs ────────────────┤
    │                                    │
    ├──► PATCH Update Work Items ──────►│
    │◄─── Success ──────────────────────┤
    │                                    │
    ├──► GET Pipelines ────────────────►│
    │◄─── Pipeline List ────────────────┤
    │                                    │
    └──► GET Builds ───────────────────►│
       ◄─── Build List ────────────────┤


┌─────────────────────────────────────────────────────────────────────────────┐
│                        📦 CREATED TEST RESOURCES                            │
└─────────────────────────────────────────────────────────────────────────────┘

Azure DevOps (Lakshmanachari/OMG.PSUtilities)
│
├─ Variable Groups
│  └─ TestVarGroup-YYYYMMDD-HHMMSS-Updated
│     ├─ _placeholder (original)
│     ├─ TestVar1 (regular)
│     ├─ SecretVar1 (secret)
│     ├─ Environment (regular)
│     └─ NewVarViaSet (added via Set)
│
├─ Work Items
│  ├─ User Story: Test User Story - Automated Test YYYY-MM-DD HH:MM
│  ├─ Task: Test Task - Automated Test YYYY-MM-DD HH:MM (linked to story)
│  └─ Bug: Test Bug - Automated Test YYYY-MM-DD HH:MM
│
├─ Pull Requests
│  └─ Test PR - Automated Test YYYY-MM-DD HH:MM (completed)
│
└─ Local Files
   ├─ TestResults-YYYYMMDD-HHMMSS.json
   └─ TestReport-YYYYMMDD-HHMMSS.html


┌─────────────────────────────────────────────────────────────────────────────┐
│                          🎨 OUTPUT VISUALIZATION                            │
└─────────────────────────────────────────────────────────────────────────────┘

Terminal Output:
═══════════════════════════════════════════════════════
SECTION 1: Project & Repository Functions
═══════════════════════════════════════════════════════
  ✓ Get-PSUADOProjectList
    Found project 'OMG.PSUtilities' (ID: 260618a0-...)
  ✓ Get-PSUADORepositories
    Found repository 'Test-Repo1' (ID: abc123...)
  ✓ Get-PSUADORepoBranchList
    Found 3 branch(es)

═══════════════════════════════════════════════════════
SECTION 2: Variable Group Functions
═══════════════════════════════════════════════════════
  ✓ New-PSUADOVariableGroup
    Created variable group ID: 42
  ✓ New-PSUADOVariable (Regular)
    Added variable 'TestVar1'
  ✓ New-PSUADOVariable (Secret)
    Added secret variable 'SecretVar1'
[... continues for all tests ...]

═══════════════════════════════════════════════════════
🎯 MASTER TEST SUMMARY
═══════════════════════════════════════════════════════
Test Type: Comprehensive
Total Tests: 26
Passed: 24
Failed: 0
Success Rate: 92.3%
Total Duration: 08:45

Results File: .\.github\Instructions-OMG.PSUtilities.AzureDevOps\TestResults-20251015-123456.json
═══════════════════════════════════════════════════════


┌─────────────────────────────────────────────────────────────────────────────┐
│                         🚀 EXECUTION TIME ESTIMATES                         │
└─────────────────────────────────────────────────────────────────────────────┘

Test Type       │ Tests │ Duration  │ Creates Resources │ Best For
────────────────┼───────┼───────────┼───────────────────┼─────────────────
Validation      │   8   │  ~30 sec  │       No          │ Pre-check only
Quick           │   5   │  ~1 min   │       No          │ Smoke test
Comprehensive   │  26+  │  5-10 min │       Yes         │ Full validation
                                                         │ (recommended)


┌─────────────────────────────────────────────────────────────────────────────┐
│                            💡 DECISION TREE                                 │
└─────────────────────────────────────────────────────────────────────────────┘

                        Want to test?
                              │
                    ┌─────────┴─────────┐
                    │                   │
              First time?          Regular testing?
                    │                   │
                    ▼                   ▼
         Run-MasterTest.ps1    Run-MasterTest.ps1
         -Comprehensive        -Comprehensive
         -VerboseOutput             │
         -ExportReport              │
                    │               │
                    └───────┬───────┘
                            │
                    Review results
                            │
                    ┌───────┴───────┐
                    │               │
              All passed?      Some failed?
                    │               │
                    ▼               ▼
              You're good!    Check errors
                              Review JSON
                              Fix issues
                              Re-run


═══════════════════════════════════════════════════════════════════════════════
                            🎉 END OF ARCHITECTURE
═══════════════════════════════════════════════════════════════════════════════
