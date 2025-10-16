# COPILOT-INSTRUCTIONS-FUNCTIONALITY-TEST.MD

Author: Generated for GitHub Copilot functional validation of OMG.PSUtilities.AzureDevOps module
Date: 2025-10-15
Scope: 26 public functions under `OMG.PSUtilities.AzureDevOps/Public`

---
## 1. Purpose
This document enables GitHub Copilot (and human reviewers) to systematically validate the runtime functionality of every exported Azure DevOps function in the OMG.PSUtilities.AzureDevOps module against a known test Azure DevOps environment.

It defines:
1. Environment + safety prerequisites
2. Ordered execution phases (read-first → create → update → lifecycle → inventories → cleanup)
3. Per-function test objectives, sample invocations, expected outputs, negative/edge cases
4. Idempotency / isolation guidance (all creations use timestamped names)
5. Central variable hand-off so later phases reuse IDs produced earlier

All tests are NON-DESTRUCTIVE to `main` by design: PRs and work items are prefixed and can be abandoned or left for audit. Variable Groups / Variables are created with a disposable naming convention.

---
## 2. Test Environment Definition

Required Azure DevOps context (provided by user):
- Organization: `Lakshmanachari`
- Project: `OMG.PSUtilities`
- Repository: `Test-Repo1`
- Branches: `main` (default), `test` (existing working branch)

Environment variables (MUST be set before running any tests):
```powershell
Set-PSUUserEnvironmentVariable -Name ORGANIZATION -Value 'Lakshmanachari'
Set-PSUUserEnvironmentVariable -Name PAT -Value '<your-valid-pat>'
```
Validation quick check:
```powershell
if(-not $env:ORGANIZATION){ throw 'ORGANIZATION not set'}
if(-not $env:PAT){ throw 'PAT not set'}
```

Local preconditions:
- PowerShell 7.x (preferred) or 5.1
- ThreadJob module installed (for inventory parallelism if used): `Install-Module ThreadJob` (optional)
- Git CLI installed (for `Invoke-PSUADORepoClone` & PR branch preparation)

---
## 3. Naming & Runtime Conventions

| Artifact Type | Prefix Pattern | Example |
|---------------|----------------|---------|
| Work Items (User Story / Bug / Task / Spike) | `PSU-TestWI-<Type>-<yyyyMMdd-HHmmss>` | `PSU-TestWI-UserStory-20251015-134501` |
| Variable Group | `PSU-Test-VG-<yyyyMMdd-HHmmss>` | `PSU-Test-VG-20251015-134501` |
| Variable Name | `PSU_TEST_VAR_<RANDOM4>` | `PSU_TEST_VAR_AB12` |
| PR Feature Branch | `psu/test-func-<yyyyMMdd-HHmmss>` (source) | `psu/test-func-20251015-134501` |
| Pull Request Title | `PSU Test PR <timestamp>` | `PSU Test PR 2025-10-15 13:45:01` |

All timestamps use local time; uniqueness prevents collisions and allows re-runs.

Store dynamic values in a shared hashtable for subsequent steps:
```powershell
$PSUFuncTest = [ordered]@{}  # central registry
```

---
## 4. Execution Phases Overview

| Phase | Goal | Functions Covered |
|-------|------|-------------------|
| 0 | Sanity + context capture | (env vars only) |
| 1 | Discovery (read-only) | Get-PSUADOProjectList, Get-PSUADORepositories, Get-PSUADORepoBranchList, Get-PSUADOPipeline, Get-PSUADOPipelineLatestRun (optional), Get-PSUADOPullRequest (baseline), Get-PSUADOVariableGroupInventory (optional filtered) |
| 2 | Create Work Items | New-PSUADOUserStory, New-PSUADOBug, New-PSUADOTask, New-PSUADOSpike |
| 3 | Update Work Items | Set-PSUADOUserStory, Set-PSUADOBug, Set-PSUADOTask, Set-PSUADOSpike |
| 4 | PR Lifecycle | New-PSUADOPullRequest, Approve-PSUADOPullRequest, Complete-PSUADOPullRequest (optional finalize) |
| 5 | Variable Groups & Variables | New-PSUADOVariableGroup, New-PSUADOVariable, Set-PSUADOVariable, Set-PSUADOVariableGroup |
| 6 | Additional Retrieval & Inventory | Get-PSUADOPullRequestInventory, Get-PSUADOWorkItem, Get-PSUADOPipelineBuild (if BuildId available) |
| 7 | Repo Operations | Invoke-PSUADORepoClone |
| 8 | Review & (Manual) Cleanup | (UI / optional API) |

Run phases in order. Phases are additive.

---
## 5. Shared Setup Script (Run Once)
```powershell
# Phase 0: Setup
Import-Module ./OMG.PSUtilities.AzureDevOps/OMG.PSUtilities.AzureDevOps.psd1 -Force
$PSUFuncTest = [ordered]@{}
$PSUFuncTest.Org = $env:ORGANIZATION
$PSUFuncTest.Project = 'OMG.PSUtilities'
$PSUFuncTest.Repository = 'Test-Repo1'
$PSUFuncTest.Timestamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
$PSUFuncTest.FeatureBranch = "psu/test-func-$($PSUFuncTest.Timestamp)"
$PSUFuncTest.PRTitle = "PSU Test PR $((Get-Date).ToString('u'))"

# Ensure source feature branch exists locally & remote
git fetch origin
git checkout test
git pull origin test --ff-only
git checkout -b $PSUFuncTest.FeatureBranch
git push origin $PSUFuncTest.FeatureBranch
```

---
## 6. Per-Function Test Specifications

Format Legend:
- Purpose: What is validated
- Invocation: Representative command (omit PAT to use env var)
- Capture: Variables to store in `$PSUFuncTest`
- Expected: Key assertions (conceptual)
- Negative: At least one safe failing scenario (optional where meaningful)
- Notes: Edge cases / idempotency / cleanup

### 6.1 Discovery Functions (Read-Only)

#### Get-PSUADOProjectList
Purpose: Enumerate accessible projects.
Invocation:
```powershell
$projects = Get-PSUADOProjectList -Organization $PSUFuncTest.Org -Verbose
$PSUFuncTest.ProjectList = $projects
```
Expected: Array contains a project with Name = `OMG.PSUtilities`.
Negative: (Optional) Validate filtering by piping and selecting; no destructive case.

#### Get-PSUADORepositories
Purpose: List repositories in project.
```powershell
$repos = Get-PSUADORepositories -Project $PSUFuncTest.Project -Organization $PSUFuncTest.Org
$PSUFuncTest.Repos = $repos
$PSUFuncTest.Repo = ($repos | Where-Object Name -eq $PSUFuncTest.Repository)
```
Expected: `$PSUFuncTest.Repo.Id` not null.
Negative: Use bogus project -> expect terminating error.

#### Get-PSUADORepoBranchList
Purpose: Validate branch enumeration.
```powershell
$branches = Get-PSUADORepoBranchList -Project $PSUFuncTest.Project -RepositoryName $PSUFuncTest.Repository -Organization $PSUFuncTest.Org -Verbose 2>$null
$PSUFuncTest.Branches = $branches
```
Expected: Contains refs/heads/main and refs/heads/test (if ADO API returns full ref names).
Known Issue: 404 if repository not initialized with multiple branches (documented earlier); treat as soft fail.

#### Get-PSUADOPipeline
Purpose: Enumerate pipelines (optional details).
```powershell
$pipelines = Get-PSUADOPipeline -Project $PSUFuncTest.Project -Organization $PSUFuncTest.Org -Verbose
$PSUFuncTest.Pipelines = $pipelines
if($pipelines){ $PSUFuncTest.PipelineId = $pipelines[0].ID }
```
Expected: Zero or more objects; if at least one, store ID.

#### Get-PSUADOPipelineLatestRun (conditional)
Run only if `$PSUFuncTest.PipelineId` set.
```powershell
if($PSUFuncTest.PipelineId){ $latest = Get-PSUADOPipelineLatestRun -Project $PSUFuncTest.Project -PipelineId $PSUFuncTest.PipelineId; $PSUFuncTest.LatestRun = $latest }
```
Expected: Object or `$null` (if no runs). Not a failure if null.

#### Get-PSUADOVariableGroupInventory (optional scope)
Purpose: Baseline variable groups (no creation yet) for delta comparison.
```powershell
$vgBaseline = Get-PSUADOVariableGroupInventory -Organization $PSUFuncTest.Org -Verbose
$PSUFuncTest.VariableGroupsBaselineCount = $vgBaseline.Count
```

### 6.2 Work Item Creation Functions

Generate dynamic naming:
```powershell
$now = Get-Date -Format 'yyyyMMdd-HHmmss'
$titleBase = "PSU-TestWI"  # reused
```

#### New-PSUADOUserStory
```powershell
$us = New-PSUADOUserStory -Project $PSUFuncTest.Project -Title "$titleBase-UserStory-$now" -Description 'User Story for functional test' -AcceptanceCriteria 'AC: demo' -Priority 2
$PSUFuncTest.UserStoryId = $us.Id
```
Expected: `$us.WorkItemType -eq 'User Story'`

#### New-PSUADOBug
```powershell
$bug = New-PSUADOBug -Project $PSUFuncTest.Project -Title "$titleBase-Bug-$now" -Description 'Bug for functional test' -ReproductionSteps '1. Step A; 2. Step B' -Priority 2
$PSUFuncTest.BugId = $bug.Id
```
Expected: WorkItemType 'Bug'

#### New-PSUADOSpike
```powershell
$spike = New-PSUADOSpike -Project $PSUFuncTest.Project -Title "$titleBase-Spike-$now" -Description 'Spike for functional test' -Priority 3 -TimeBox '1 day'
$PSUFuncTest.SpikeId = $spike.Id
```

#### New-PSUADOTask (linked to User Story)
```powershell
$task = New-PSUADOTask -Project $PSUFuncTest.Project -Title "$titleBase-Task-$now" -Description 'Task for functional test' -ParentWorkItemId $PSUFuncTest.UserStoryId -EstimatedHours 4
$PSUFuncTest.TaskId = $task.Id
```
Expected: Child relation to user story (inspect in UI or later retrieval).

### 6.3 Work Item Update Functions

#### Set-PSUADOUserStory
```powershell
Set-PSUADOUserStory -Project $PSUFuncTest.Project -Id $PSUFuncTest.UserStoryId -State Active -Tags 'func,test' -StoryPoints 3 -AcceptanceCriteria 'Updated AC'
```
Verify: Retrieve via `Get-PSUADOWorkItem -Id $PSUFuncTest.UserStoryId` -> State Active, StoryPoints 3.

#### Set-PSUADOBug
```powershell
Set-PSUADOBug -Project $PSUFuncTest.Project -Id $PSUFuncTest.BugId -State Active -Priority 1 -Severity '2 - High' -Tags 'bug,functional'
```

#### Set-PSUADOSpike
```powershell
Set-PSUADOSpike -Project $PSUFuncTest.Project -Id $PSUFuncTest.SpikeId -State Active -Priority 1 -Effort 5 -Tags 'spike,research'
```

#### Set-PSUADOTask
```powershell
Set-PSUADOTask -Project $PSUFuncTest.Project -Id $PSUFuncTest.TaskId -State 'In Progress' -RemainingWork 2 -Activity Development -Tags 'task,functional'
```

### 6.4 Pull Request Lifecycle

Preconditions:
1. Feature branch already pushed (see setup)
2. Ensure at least one commit exists uniquely on the feature branch:
```powershell
git checkout $PSUFuncTest.FeatureBranch
"Test $(Get-Date)" | Out-File TEMP_FUNC_TEST.txt -Encoding utf8
git add TEMP_FUNC_TEST.txt
git commit -m "feat(test): functional PR seed"
git push origin $PSUFuncTest.FeatureBranch
```

#### New-PSUADOPullRequest
```powershell
$pr = New-PSUADOPullRequest -Project $PSUFuncTest.Project -Repository $PSUFuncTest.Repository -SourceBranch $PSUFuncTest.FeatureBranch -TargetBranch 'test' -Title $PSUFuncTest.PRTitle -Description 'Functional validation PR' -Draft
$PSUFuncTest.PullRequestId = $pr.Id
```
Expected: `IsDraft -eq $true`, sourceRefName contains feature branch, targetRefName refs/heads/test.
Negative: Attempt duplicate PR with same source/target -> expect validation / 400 (do NOT treat as failure; document).

#### Approve-PSUADOPullRequest
```powershell
Approve-PSUADOPullRequest -Project $PSUFuncTest.Project -Repository $PSUFuncTest.Repository -PullRequestId $PSUFuncTest.PullRequestId -Vote 10 -Comment 'Automated approval'
```
Expected: Vote recorded (check returned object / UI). Draft PR may need to be active before completion; remain draft for safety.

#### Complete-PSUADOPullRequest (Optional)
For safety, you may SKIP completion to avoid merging test artifact into `test`. If performing, ensure branch target is a disposable branch instead. Recommended: skip.
```powershell
# Optional ONLY if safe
# Complete-PSUADOPullRequest -Project $PSUFuncTest.Project -Repository $PSUFuncTest.Repository -PullRequestId $PSUFuncTest.PullRequestId -MergeStrategy squash
```
Expected (if run): PR status Completed; source branch optionally retained.

### 6.5 Variable Groups & Variables

#### New-PSUADOVariableGroup
```powershell
$vgName = "PSU-Test-VG-$($PSUFuncTest.Timestamp)"
$vg = New-PSUADOVariableGroup -Project $PSUFuncTest.Project -VariableGroupName $vgName -Description 'Functional test variable group'
$PSUFuncTest.VariableGroupId = $vg.Id
$PSUFuncTest.VariableGroupName = $vg.Name
```

#### New-PSUADOVariable
```powershell
$varName = ("PSU_TEST_VAR_" + -join ((65..90)|Get-Random -Count 4|% {[char]$_}))
New-PSUADOVariable -Project $PSUFuncTest.Project -VariableGroupName $PSUFuncTest.VariableGroupName -VariableName $varName -VariableValue 'initial' | Out-Null
$PSUFuncTest.VariableName = $varName
```

#### Set-PSUADOVariable (update value + secret)
```powershell
Set-PSUADOVariable -Project $PSUFuncTest.Project -VariableGroupName $PSUFuncTest.VariableGroupName -VariableName $PSUFuncTest.VariableName -VariableValue 'updated' -IsSecret | Out-Null
```
Expected: Value updated; secret flag stored (cannot retrieve secret value—only trust success response).

#### Set-PSUADOVariableGroup (rename + description)
```powershell
$newVGName = "$($PSUFuncTest.VariableGroupName)-Renamed"
Set-PSUADOVariableGroup -Project $PSUFuncTest.Project -VariableGroupId $PSUFuncTest.VariableGroupId -VariableGroupName $newVGName -Description 'Renamed functional group' | Out-Null
$PSUFuncTest.VariableGroupName = $newVGName
```

Post-check inventory delta:
```powershell
$vgAfter = Get-PSUADOVariableGroupInventory -Organization $PSUFuncTest.Org
$PSUFuncTest.VariableGroupsAfterCount = $vgAfter.Count
```
Expected: Count >= baseline; renamed group present.

### 6.6 Additional Retrieval / Verification

#### Get-PSUADOWorkItem (spot-check each created ID)
```powershell
foreach($idKey in 'UserStoryId','BugId','SpikeId','TaskId'){
  $id = $PSUFuncTest[$idKey]; if($id){ $wi = Get-PSUADOWorkItem -Id $id -Project $PSUFuncTest.Project; Write-Host "Verified WorkItem $id ($($wi.WorkItemType))" }
}
```

#### Get-PSUADOPullRequest (filter by repository)
```powershell
$activePRs = Get-PSUADOPullRequest -Project $PSUFuncTest.Project -RepositoryName $PSUFuncTest.Repository -State Active
```
Expected: Contains test PR (unless completed).

#### Get-PSUADOPullRequestInventory
```powershell
$orgActivePRs = Get-PSUADOPullRequestInventory -Organization $PSUFuncTest.Org -Verbose
```
Expected: Returns aggregated list; not a failure if test PR absent (completed).

#### Get-PSUADOPipelineBuild (conditional)
If you have a recent BuildId (manually supply or parse from pipeline runs):
```powershell
# Example only if a build ID known
# $build = Get-PSUADOPipelineBuild -Project $PSUFuncTest.Project -BuildId <BuildId>
```

### 6.7 Repository Clone

#### Invoke-PSUADORepoClone (to temp path)
```powershell
$cloneBase = Join-Path $env:TEMP "PSU-AdoClone"
if(-not (Test-Path $cloneBase)){ New-Item -ItemType Directory -Path $cloneBase | Out-Null }
Invoke-PSUADORepoClone -Project $PSUFuncTest.Project -TargetPath $cloneBase -RepositoryFilter $PSUFuncTest.Repository -Verbose
```
Expected: Local folder `<TargetPath>\OMG.PSUtilities-Repos\<RepoName>` (projectName-Repos pattern) exists with `.git` directory.

---
## 7. Negative / Edge Case Matrix (Optional, Safe)

| Function | Scenario | Expected | Notes |
|----------|----------|----------|-------|
| New-PSUADOPullRequest | Duplicate creation (same source/target) | 400 Bad Request | Do AFTER capturing first PR ID |
| Get-PSUADORepoBranchList | Repo with no extra branches | 404 / empty list | Document only; treat as non-fatal |
| Set-PSUADOVariable | Nonexistent group name | Exception | Use clearly bogus group name |
| Get-PSUADOPipelineLatestRun | Pipeline exists, no runs | Null result | Not failure |
| Complete-PSUADOPullRequest | Attempt on Draft PR | Failure / validation | Convert out of draft first (not automated here) |

---
## 8. Assertions & Lightweight Checks

Suggested PowerShell assertion helpers (inline – no external test framework required):
```powershell
function Assert-NotNull($Value, $Message){ if($null -eq $Value){ throw "ASSERT NULL: $Message" } }
function Assert-Equal($A,$B,$Message){ if($A -ne $B){ throw "ASSERT NEQ ($A vs $B): $Message" } }
```
Example usage after creating a User Story:
```powershell
Assert-NotNull $PSUFuncTest.UserStoryId 'User Story was not created.'
```

---
## 9. Cleanup Guidance (Manual / Optional)

Because the module currently has no delete functions:
- Work Items: Optionally transition to Closed state or leave for audit.
- Variable Group: Manually delete in Azure DevOps Library UI if desired.
- Feature Branch: `git push origin --delete $PSUFuncTest.FeatureBranch` + local delete.
- Test PR: Abandon instead of complete if you do not want merges.

Manual PR abandon (if still active) can be done in UI or via REST:
```
PATCH https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repoId}/pullrequests/{id}?api-version=7.0
Body: {"status":"abandoned"}
```

---
## 10. End-to-End Orchestration (Condensed Script)
The following consolidates a minimal happy-path run (excludes optional pipeline/build and variable inventory baseline). Execute stepwise for clarity.
```powershell
Import-Module ./OMG.PSUtilities.AzureDevOps/OMG.PSUtilities.AzureDevOps.psd1 -Force
$PSUFuncTest = [ordered]@{ Org=$env:ORGANIZATION; Project='OMG.PSUtilities'; Repository='Test-Repo1'; Timestamp=(Get-Date -Format 'yyyyMMdd-HHmmss') }
$PSUFuncTest.FeatureBranch = "psu/test-func-$($PSUFuncTest.Timestamp)"
git fetch origin; git checkout test; git pull origin test --ff-only; git checkout -b $PSUFuncTest.FeatureBranch; git push origin $PSUFuncTest.FeatureBranch
$repos = Get-PSUADORepositories -Project $PSUFuncTest.Project
$PSUFuncTest.Repo = $repos | Where-Object Name -eq $PSUFuncTest.Repository
$titleBase='PSU-TestWI'; $now=(Get-Date -Format 'yyyyMMdd-HHmmss')
$us = New-PSUADOUserStory -Project $PSUFuncTest.Project -Title "$titleBase-UserStory-$now" -Description 'User Story'; $PSUFuncTest.UserStoryId=$us.Id
$bug = New-PSUADOBug -Project $PSUFuncTest.Project -Title "$titleBase-Bug-$now" -Description 'Bug'; $PSUFuncTest.BugId=$bug.Id
$spike = New-PSUADOSpike -Project $PSUFuncTest.Project -Title "$titleBase-Spike-$now" -Description 'Spike'; $PSUFuncTest.SpikeId=$spike.Id
$task = New-PSUADOTask -Project $PSUFuncTest.Project -Title "$titleBase-Task-$now" -Description 'Task' -ParentWorkItemId $us.Id; $PSUFuncTest.TaskId=$task.Id
Set-PSUADOTask -Project $PSUFuncTest.Project -Id $PSUFuncTest.TaskId -State 'In Progress' -RemainingWork 1 | Out-Null
git checkout $PSUFuncTest.FeatureBranch; "PR seed" | Out-File pr_seed.txt; git add pr_seed.txt; git commit -m "chore: pr seed"; git push origin $PSUFuncTest.FeatureBranch
$pr = New-PSUADOPullRequest -Project $PSUFuncTest.Project -Repository $PSUFuncTest.Repository -SourceBranch $PSUFuncTest.FeatureBranch -TargetBranch 'test' -Title "PSU Test PR $now" -Description 'Functional PR' -Draft
Approve-PSUADOPullRequest -Project $PSUFuncTest.Project -Repository $PSUFuncTest.Repository -PullRequestId $pr.Id -Comment 'Auto approve' | Out-Null
$vgName = "PSU-Test-VG-$now"; $vg = New-PSUADOVariableGroup -Project $PSUFuncTest.Project -VariableGroupName $vgName; $PSUFuncTest.VariableGroupId=$vg.Id
$varName = 'PSU_TEST_VAR_INIT'; New-PSUADOVariable -Project $PSUFuncTest.Project -VariableGroupName $vgName -VariableName $varName -VariableValue 'initial' | Out-Null
Set-PSUADOVariable -Project $PSUFuncTest.Project -VariableGroupName $vgName -VariableName $varName -VariableValue 'updated' -IsSecret | Out-Null
Write-Host 'Functional test sequence complete.' -ForegroundColor Green
```

---
## 11. Reporting & Automation Suggestions (Future Enhancement)
- Wrap assertions into a Pester test file generating JUnit XML for CI ingestion.
- Capture `$PSUFuncTest` (ConvertTo-Json) to artifact for auditing.
- Add a cleanup script stub for deleting ephemeral branches & abandoning PRs automatically.

---
## 12. Checklist (Manual Sign-off)
| Item | Status |
|------|--------|
| Env vars set |  |
| Module imported |  |
| Discovery completed |  |
| Work items created |  |
| Work items updated |  |
| PR created |  |
| PR approved |  |
| (Optional) PR completed |  |
| Variable group created/updated |  |
| Inventories captured |  |
| Repo cloned |  |
| Results archived |  |

---
## 13. Known Limitations / Notes
1. Some Azure DevOps transitions (work item state changes) may fail if not valid for the current process template; adjust states accordingly.
2. Completing PRs merges commits—skipped by default to avoid altering shared branches.
3. Secret variable values cannot be re-read for verification; rely on successful API response.
4. Branch enumeration may return limited refs if repository minimal.
5. Pipeline tests are opportunistic if pipelines exist; absence is not a failure.

---
## 14. Completion Summary Template
Upon finishing, produce (manually or scripted):
```powershell
$summary = [pscustomobject]@{
  Timestamp = Get-Date
  UserStoryId = $PSUFuncTest.UserStoryId
  BugId = $PSUFuncTest.BugId
  SpikeId = $PSUFuncTest.SpikeId
  TaskId = $PSUFuncTest.TaskId
  PullRequestId = $PSUFuncTest.PullRequestId
  VariableGroupId = $PSUFuncTest.VariableGroupId
  FeatureBranch = $PSUFuncTest.FeatureBranch
}
$summary | Format-List
```

Store the object (JSON) for audit:
```powershell
$summary | ConvertTo-Json -Depth 5 | Out-File "FunctionalTest-Summary-$($PSUFuncTest.Timestamp).json"
```

---
End of COPILOT-INSTRUCTIONS-FUNCTIONALITY-TEST.MD
