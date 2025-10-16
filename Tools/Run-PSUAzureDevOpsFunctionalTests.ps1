<#
.SYNOPSIS
    Functional test harness for OMG.PSUtilities.AzureDevOps public functions.

.DESCRIPTION
    Implements the phased execution model documented in COPILOT-INSTRUCTIONS-FUNCTIONALITY-TEST.MD.
    Phases:
      1. Discovery (always runs)
      2. Work Item Creation (unless -SkipWorkItems or -DryRun)
      3. Work Item Updates (unless -NoWorkItemUpdates or -DryRun or -SkipWorkItems)
      4. Pull Request lifecycle (unless -SkipPR or -DryRun)
      5. Variable Group / Variable tests (if -IncludeVariableGroupTests and not -DryRun)
      6. Additional inventory + verification
      7. Repository clone (unless -SkipClone or -DryRun)

    Produces a summary object (and optional JSON file) containing IDs and metadata for created artefacts.

    NOTE: This harness is intentionally conservative (it does NOT complete the PR unless -CompletePR is passed).

.PARAMETER Project
    Azure DevOps project name (default OMG.PSUtilities)

.PARAMETER Repository
    Repository name used for PR and branch enumeration.

.PARAMETER FeatureBranchPrefix
    Prefix for generated feature branch (timestamp appended).

.PARAMETER Organization
    Azure DevOps organization (defaults to $env:ORGANIZATION).

.PARAMETER PAT
    Personal Access Token (defaults to $env:PAT).

.PARAMETER DryRun
    Run ONLY discovery (read-only) phases.

.PARAMETER SkipWorkItems
    Do not create / update work items.

.PARAMETER NoWorkItemUpdates
    Create work items but skip update phase.

.PARAMETER SkipPR
    Skip PR creation / approval.

.PARAMETER CompletePR
    Attempt to complete (merge) the PR (NOT recommended on shared branches for normal validation).

.PARAMETER SkipPRCompletion
    Legacy compatibility switch (ignored if -CompletePR is specified). Default behavior is to NOT complete.

.PARAMETER IncludeVariableGroupTests
    Include variable group + variable create/update tests.

.PARAMETER SkipClone
    Skip repository clone phase.

.PARAMETER OutputJsonPath
    Optional path to write summary JSON (directory created if missing).

.EXAMPLE
    ./Tools/Run-PSUAzureDevOpsFunctionalTests.ps1 -DryRun -Verbose

.EXAMPLE
    ./Tools/Run-PSUAzureDevOpsFunctionalTests.ps1 -IncludeVariableGroupTests -Verbose

.NOTES
    Author: GitHub Copilot (automated harness)
    Date: 2025-10-15
    Safe Defaults: Will not merge PR or modify main/test branches (other than creating a feature branch and a commit).
#>
[CmdletBinding()] param(
    [Parameter()] [string]$Project = 'OMG.PSUtilities',
    [Parameter()] [string]$Repository = 'Test-Repo1',
    [Parameter()] [string]$FeatureBranchPrefix = 'psu/test-func',
    [Parameter()] [switch]$DryRun,
    [Parameter()] [switch]$SkipWorkItems,
    [Parameter()] [switch]$NoWorkItemUpdates,
    [Parameter()] [switch]$SkipPR,
    [Parameter()] [switch]$CompletePR,
    [Parameter()] [switch]$SkipPRCompletion, # backward compatibility
    [Parameter()] [switch]$IncludeVariableGroupTests,
    [Parameter()] [switch]$SkipClone,
    [Parameter()] [string]$OutputJsonPath,
    [Parameter()] [string]$Organization = $env:ORGANIZATION,
    [Parameter()] [string]$PAT = $env:PAT
)

begin {
    Write-Verbose '--- Phase: Validation & Setup ---'
    # Masked parameter log
    Write-Verbose 'Parameters:'
    foreach($kv in [ordered]@{Project=$Project;Repository=$Repository;Organization=$Organization;DryRun=$DryRun;SkipWorkItems=$SkipWorkItems;NoWorkItemUpdates=$NoWorkItemUpdates;SkipPR=$SkipPR;IncludeVariableGroupTests=$IncludeVariableGroupTests;SkipClone=$SkipClone;OutputJsonPath=$OutputJsonPath;FeatureBranchPrefix=$FeatureBranchPrefix;CompletePR=$CompletePR}){ Write-Verbose ('  {0} = {1}' -f $kv.Key,$kv.Value) }
    if([string]::IsNullOrWhiteSpace($Organization)){ throw "Organization is required. Set ORGANIZATION env var or pass -Organization." }
    if([string]::IsNullOrWhiteSpace($PAT)){ throw "PAT is required. Set PAT env var or pass -PAT." }

    # Try to ensure the AzureDevOps module is imported
    if(-not (Get-Module OMG.PSUtilities.AzureDevOps -ListAvailable)){
        $localManifest = Join-Path $PSScriptRoot '..' 'OMG.PSUtilities.AzureDevOps' 'OMG.PSUtilities.AzureDevOps.psd1'
        if(Test-Path $localManifest){ Import-Module $localManifest -Force -ErrorAction Stop }
    }
    if(-not (Get-Module OMG.PSUtilities.AzureDevOps)){ throw 'OMG.PSUtilities.AzureDevOps module not found/imported.' }

    $Global:PSUFuncTest = [ordered]@{}
    $nowStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $PSUFuncTest.Timestamp = $nowStamp
    $PSUFuncTest.Project = $Project
    $PSUFuncTest.Repository = $Repository
    $PSUFuncTest.Organization = $Organization
    $PSUFuncTest.FeatureBranch = "$FeatureBranchPrefix-$nowStamp"
    $PSUFuncTest.Results = [ordered]@{}
}

process {
    # Phase 1: Discovery
    Write-Verbose '--- Phase 1: Discovery ---'
    try {
        $projects = Get-PSUADOProjectList -Organization $Organization -ErrorAction Stop
        $PSUFuncTest.Results.ProjectCount = $projects.Count
        $proj = $projects | Where-Object Name -eq $Project
        if(-not $proj){ throw "Project '$Project' not found in organization '$Organization'" }
        $repos = Get-PSUADORepositories -Project $Project -Organization $Organization -ErrorAction Stop
        $PSUFuncTest.Results.RepositoryCount = $repos.Count
        $repoObj = $repos | Where-Object Name -eq $Repository
        if(-not $repoObj){ throw "Repository '$Repository' not found in project '$Project'" }
        $PSUFuncTest.RepositoryId = $repoObj.Id
        try {
            $branches = Get-PSUADORepoBranchList -Project $Project -RepositoryName $Repository -Organization $Organization -ErrorAction Stop
            $PSUFuncTest.Results.BranchCount = ($branches | Measure-Object).Count
        } catch { Write-Warning "Branch list retrieval failed: $($_.Exception.Message)" }
        try {
            $pipelines = Get-PSUADOPipeline -Project $Project -Organization $Organization -ErrorAction Stop
            $PSUFuncTest.Results.PipelineCount = ($pipelines | Measure-Object).Count
            if($pipelines){ $PSUFuncTest.PipelineId = $pipelines[0].ID }
        } catch { Write-Warning "Pipeline retrieval failed: $($_.Exception.Message)" }
        if($PSUFuncTest.PipelineId){
            try { $PSUFuncTest.LatestRun = Get-PSUADOPipelineLatestRun -Project $Project -PipelineId $PSUFuncTest.PipelineId -ErrorAction Stop } catch { Write-Warning "Latest run retrieval failed: $($_.Exception.Message)" }
        }
        if($IncludeVariableGroupTests){
            try { $vgBaseline = Get-PSUADOVariableGroupInventory -Organization $Organization -ErrorAction Stop; $PSUFuncTest.Results.VariableGroupBaseline = $vgBaseline.Count } catch { Write-Warning "Variable group baseline failed: $($_.Exception.Message)" }
        }
    } catch { $PSCmdlet.ThrowTerminatingError($_) }

    if($DryRun){
        Write-Verbose 'DryRun specified: skipping creation phases.'
        return
    }

    # Phase 2: Work Item Creation
    if(-not $SkipWorkItems){
        Write-Verbose '--- Phase 2: Work Item Creation ---'
        $titleBase = 'PSU-TestWI'
        $ts = (Get-Date -Format 'yyyyMMdd-HHmmss')
        try {
            $us = New-PSUADOUserStory -Project $Project -Title "$titleBase-UserStory-$ts" -Description 'Functional test user story' -AcceptanceCriteria 'AC sample'
            $PSUFuncTest.UserStoryId = $us.Id
        } catch { Write-Warning "User Story creation failed: $($_.Exception.Message)" }
        try {
            $bug = New-PSUADOBug -Project $Project -Title "$titleBase-Bug-$ts" -Description 'Functional test bug' -ReproductionSteps '1. Do X 2. Do Y'
            $PSUFuncTest.BugId = $bug.Id
        } catch { Write-Warning "Bug creation failed: $($_.Exception.Message)" }
        try {
            $spike = New-PSUADOSpike -Project $Project -Title "$titleBase-Spike-$ts" -Description 'Functional test spike'
            $PSUFuncTest.SpikeId = $spike.Id
        } catch { Write-Warning "Spike creation failed: $($_.Exception.Message)" }
        try {
            if($PSUFuncTest.UserStoryId){
                $task = New-PSUADOTask -Project $Project -Title "$titleBase-Task-$ts" -Description 'Functional test task' -ParentWorkItemId $PSUFuncTest.UserStoryId -EstimatedHours 2
                $PSUFuncTest.TaskId = $task.Id
            }
        } catch { Write-Warning "Task creation failed: $($_.Exception.Message)" }
    } else { Write-Verbose 'Skipping work item creation (--SkipWorkItems).' }

    # Phase 3: Work Item Updates
    if((-not $SkipWorkItems) -and (-not $NoWorkItemUpdates)){
        Write-Verbose '--- Phase 3: Work Item Updates ---'
        try { if($PSUFuncTest.UserStoryId){ Set-PSUADOUserStory -Project $Project -Id $PSUFuncTest.UserStoryId -State Active -StoryPoints 3 -Tags 'func,test' | Out-Null } } catch { Write-Warning "User story update failed: $($_.Exception.Message)" }
        try { if($PSUFuncTest.BugId){ Set-PSUADOBug -Project $Project -Id $PSUFuncTest.BugId -State Active -Priority 2 -Severity '3 - Medium' | Out-Null } } catch { Write-Warning "Bug update failed: $($_.Exception.Message)" }
        try { if($PSUFuncTest.SpikeId){ Set-PSUADOSpike -Project $Project -Id $PSUFuncTest.SpikeId -State Active -Priority 2 -Effort 1 | Out-Null } } catch { Write-Warning "Spike update failed: $($_.Exception.Message)" }
        try { if($PSUFuncTest.TaskId){ Set-PSUADOTask -Project $Project -Id $PSUFuncTest.TaskId -State 'In Progress' -RemainingWork 1 | Out-Null } } catch { Write-Warning "Task update failed: $($_.Exception.Message)" }
    } else { Write-Verbose 'Skipping work item update phase.' }

    # Phase 4: PR Lifecycle
    if(-not $SkipPR){
        Write-Verbose '--- Phase 4: PR Lifecycle ---'
        # Ensure git available only if needed
        if(Get-Command git -ErrorAction SilentlyContinue){
            try {
                git fetch origin | Out-Null
                # Use 'test' branch as base if exists
                git checkout test 2>$null | Out-Null
                git pull origin test --ff-only 2>$null | Out-Null
                git checkout -b $PSUFuncTest.FeatureBranch 2>$null | Out-Null
                "Functional test seed $(Get-Date)" | Out-File .\PSU_FUNC_TEST_SEED.txt -Encoding utf8
                git add PSU_FUNC_TEST_SEED.txt 2>$null | Out-Null
                git commit -m "chore: functional test seed" 2>$null | Out-Null
                git push origin $PSUFuncTest.FeatureBranch 2>$null | Out-Null
            } catch { Write-Warning "Git branch prep failed: $($_.Exception.Message)" }
        } else { Write-Warning 'git CLI not available; skipping branch creation (PR may fail).'}
        try {
            $pr = New-PSUADOPullRequest -Project $Project -Repository $Repository -SourceBranch $PSUFuncTest.FeatureBranch -TargetBranch 'test' -Title "PSU Test PR $($PSUFuncTest.Timestamp)" -Description 'Functional harness PR' -Draft
            $PSUFuncTest.PullRequestId = $pr.Id
        } catch { Write-Warning "PR creation failed: $($_.Exception.Message)" }
        if($PSUFuncTest.PullRequestId){
            try { Approve-PSUADOPullRequest -Project $Project -Repository $Repository -PullRequestId $PSUFuncTest.PullRequestId -Vote 10 -Comment 'Automated approval' | Out-Null } catch { Write-Warning "PR approval failed: $($_.Exception.Message)" }
            if($CompletePR){
                try { Complete-PSUADOPullRequest -Project $Project -Repository $Repository -PullRequestId $PSUFuncTest.PullRequestId -MergeStrategy squash | Out-Null } catch { Write-Warning "PR completion failed: $($_.Exception.Message)" }
            }
        }
    } else { Write-Verbose 'Skipping PR phase (--SkipPR).' }

    # Phase 5: Variable Groups & Variables
    if($IncludeVariableGroupTests){
        Write-Verbose '--- Phase 5: Variable Groups ---'
        try {
            $vgName = "PSU-Test-VG-$($PSUFuncTest.Timestamp)"
            $vg = New-PSUADOVariableGroup -Project $Project -VariableGroupName $vgName -Description 'Functional test VG'
            $PSUFuncTest.VariableGroupId = $vg.Id
            $varName = 'PSU_TEST_VAR_INIT'
            New-PSUADOVariable -Project $Project -VariableGroupName $vgName -VariableName $varName -VariableValue 'initial' | Out-Null
            Set-PSUADOVariable -Project $Project -VariableGroupName $vgName -VariableName $varName -VariableValue 'updated' -IsSecret | Out-Null
            $newVGName = $vgName + '-Renamed'
            Set-PSUADOVariableGroup -Project $Project -VariableGroupId $vg.Id -VariableGroupName $newVGName -Description 'Renamed via harness' | Out-Null
            $PSUFuncTest.VariableGroupName = $newVGName
        } catch { Write-Warning "Variable group tests failed: $($_.Exception.Message)" }
    }

    # Phase 6: Additional retrieval
    Write-Verbose '--- Phase 6: Additional Retrieval ---'
    foreach($key in 'UserStoryId','BugId','SpikeId','TaskId'){
        $id = $PSUFuncTest[$key]
        if($id){ try { $wi = Get-PSUADOWorkItem -Id $id -Project $Project -ErrorAction Stop; $PSUFuncTest["${key}State"] = $wi.State } catch { Write-Warning "Work item $id retrieval failed: $($_.Exception.Message)" } }
    }
    try { $activePRs = Get-PSUADOPullRequest -Project $Project -RepositoryName $Repository -State Active -ErrorAction Stop; $PSUFuncTest.ActivePRCount = $activePRs.Count } catch { Write-Warning "Active PR retrieval failed: $($_.Exception.Message)" }

    # Phase 7: Clone
    if(-not $SkipClone){
        Write-Verbose '--- Phase 7: Repository Clone ---'
        try {
            $cloneBase = Join-Path $env:TEMP 'PSU-AdoClone'
            if(-not (Test-Path $cloneBase)){ New-Item -ItemType Directory -Path $cloneBase | Out-Null }
            Invoke-PSUADORepoClone -Project $Project -TargetPath $cloneBase -RepositoryFilter $Repository -Organization $Organization -ErrorAction Stop | Out-Null
            $PSUFuncTest.ClonePath = Join-Path $cloneBase ("{0}-Repos" -f $Project)
        } catch { Write-Warning "Clone phase failed: $($_.Exception.Message)" }
    }
}

end {
    Write-Verbose '--- Summary ---'
    $summary = [pscustomobject]@{
        Timestamp        = $PSUFuncTest.Timestamp
        Organization     = $Organization
        Project          = $Project
        Repository       = $Repository
        RepositoryId     = $PSUFuncTest.RepositoryId
        PipelineId       = $PSUFuncTest.PipelineId
        FeatureBranch    = $PSUFuncTest.FeatureBranch
        PullRequestId    = $PSUFuncTest.PullRequestId
        UserStoryId      = $PSUFuncTest.UserStoryId
        BugId            = $PSUFuncTest.BugId
        SpikeId          = $PSUFuncTest.SpikeId
        TaskId           = $PSUFuncTest.TaskId
        VariableGroupId  = $PSUFuncTest.VariableGroupId
        ActivePRCount    = $PSUFuncTest.ActivePRCount
        ClonePath        = $PSUFuncTest.ClonePath
        DryRun           = [bool]$DryRun
    }
    if($OutputJsonPath){
        try {
            $dir = Split-Path $OutputJsonPath -Parent
            if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Path $dir | Out-Null }
            $summary | ConvertTo-Json -Depth 5 | Out-File $OutputJsonPath -Encoding utf8
            Write-Verbose "Summary written to $OutputJsonPath"
        } catch { Write-Warning "Failed to write summary JSON: $($_.Exception.Message)" }
    }
    return $summary
}
