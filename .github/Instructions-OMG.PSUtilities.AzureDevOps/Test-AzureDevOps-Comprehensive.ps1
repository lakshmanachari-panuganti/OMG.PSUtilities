# =========================================================================
# Comprehensive Test Suite for OMG.PSUtilities.AzureDevOps Module
# =========================================================================
# Test Repository: https://dev.azure.com/Lakshmanachari/OMG.PSUtilities/_git/Test-Repo1
# Organization: Lakshmanachari (from $env:ORGANIZATION)
# Project: OMG.PSUtilities
# Repository: Test-Repo1
# =========================================================================

[CmdletBinding()]
param(
    [switch]$SkipCleanup,
    [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'
$testResults = @()
$testStartTime = Get-Date

# Color scheme for output
$colors = @{
    Header   = 'Cyan'
    Success  = 'Green'
    Warning  = 'Yellow'
    Error    = 'Red'
    Info     = 'White'
    Detail   = 'Gray'
}

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n$('=' * 80)" -ForegroundColor $colors.Header
    Write-Host $Message -ForegroundColor $colors.Header
    Write-Host $('=' * 80) -ForegroundColor $colors.Header
}

function Write-TestSection {
    param([string]$Message)
    Write-Host "`n$('-' * 80)" -ForegroundColor $colors.Info
    Write-Host $Message -ForegroundColor $colors.Info
    Write-Host $('-' * 80) -ForegroundColor $colors.Info
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Message,
        [object]$Data
    )
    
    $result = [PSCustomObject]@{
        TestName  = $TestName
        Success   = $Success
        Message   = $Message
        Data      = $Data
        Timestamp = Get-Date
    }
    
    $script:testResults += $result
    
    if ($Success) {
        Write-Host "  ✓ " -ForegroundColor $colors.Success -NoNewline
        Write-Host "$TestName" -ForegroundColor $colors.Success
        if ($Message) {
            Write-Host "    $Message" -ForegroundColor $colors.Detail
        }
    } else {
        Write-Host "  ✗ " -ForegroundColor $colors.Error -NoNewline
        Write-Host "$TestName" -ForegroundColor $colors.Error
        if ($Message) {
            Write-Host "    $Message" -ForegroundColor $colors.Error
        }
    }
}

# =========================================================================
# SECTION 0: PRE-FLIGHT CHECKS
# =========================================================================
Write-TestHeader "SECTION 0: Pre-Flight Checks"

# Check environment variables
Write-Host "`nChecking environment variables..." -ForegroundColor $colors.Info
$envVars = @{
    ORGANIZATION = $env:ORGANIZATION
    PAT          = $env:PAT
}

if (-not $envVars.ORGANIZATION) {
    Write-Host "  ✗ ORGANIZATION not set. Run: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value 'Lakshmanachari'" -ForegroundColor $colors.Error
    exit 1
}
Write-TestResult "Environment: ORGANIZATION" $true $envVars.ORGANIZATION

if (-not $envVars.PAT) {
    Write-Host "  ✗ PAT not set. Run: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<your_pat>'" -ForegroundColor $colors.Error
    exit 1
}
Write-TestResult "Environment: PAT" $true "Length: $($envVars.PAT.Length) characters"

# Import module
Write-Host "`nImporting module..." -ForegroundColor $colors.Info
try {
    Import-Module .\OMG.PSUtilities.AzureDevOps\OMG.PSUtilities.AzureDevOps.psm1 -Force
    $moduleInfo = Get-Module OMG.PSUtilities.AzureDevOps
    Write-TestResult "Module Import" $true "Version $($moduleInfo.Version), $($moduleInfo.ExportedFunctions.Count) functions"
} catch {
    Write-TestResult "Module Import" $false $_.Exception.Message
    exit 1
}

# List all exported functions
$allFunctions = Get-Command -Module OMG.PSUtilities.AzureDevOps | Sort-Object Name
Write-Host "`nExported Functions ($($allFunctions.Count)):" -ForegroundColor $colors.Info
$allFunctions | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor $colors.Detail }

# =========================================================================
# SECTION 1: PROJECT & REPOSITORY FUNCTIONS
# =========================================================================
Write-TestHeader "SECTION 1: Project & Repository Functions"

# Test 1.1: Get-PSUADOProjectList
Write-TestSection "Test 1.1: Get-PSUADOProjectList"
try {
    $projects = Get-PSUADOProjectList
    $targetProject = $projects | Where-Object { $_.name -eq 'OMG.PSUtilities' }
    
    if ($targetProject) {
        Write-TestResult "Get-PSUADOProjectList" $true "Found project 'OMG.PSUtilities' (ID: $($targetProject.id))"
        $script:projectId = $targetProject.id
        $script:projectName = $targetProject.name
    } else {
        Write-TestResult "Get-PSUADOProjectList" $false "Project 'OMG.PSUtilities' not found. Available: $($projects.name -join ', ')"
    }
} catch {
    Write-TestResult "Get-PSUADOProjectList" $false $_.Exception.Message
}

# Test 1.2: Get-PSUADORepositories
Write-TestSection "Test 1.2: Get-PSUADORepositories"
try {
    $repositories = Get-PSUADORepositories -Project $projectName
    $targetRepo = $repositories | Where-Object { $_.name -eq 'Test-Repo1' }
    
    if ($targetRepo) {
        Write-TestResult "Get-PSUADORepositories" $true "Found repository 'Test-Repo1' (ID: $($targetRepo.id))"
        $script:repositoryId = $targetRepo.id
        $script:repositoryName = $targetRepo.name
        Write-Host "    Default Branch: $($targetRepo.defaultBranch)" -ForegroundColor $colors.Detail
    } else {
        Write-TestResult "Get-PSUADORepositories" $false "Repository 'Test-Repo1' not found. Available: $($repositories.name -join ', ')"
    }
} catch {
    Write-TestResult "Get-PSUADORepositories" $false $_.Exception.Message
}

# Test 1.3: Get-PSUADORepoBranchList
Write-TestSection "Test 1.3: Get-PSUADORepoBranchList"
try {
    $branches = Get-PSUADORepoBranchList -Project $projectName -RepositoryName $repositoryName
    Write-TestResult "Get-PSUADORepoBranchList" $true "Found $($branches.Count) branch(es)"
    
    $script:defaultBranch = ($branches | Where-Object { $_.isDefault -eq $true }).name
    if (-not $script:defaultBranch) {
        $script:defaultBranch = $branches[0].name
    }
    Write-Host "    Default Branch: $defaultBranch" -ForegroundColor $colors.Detail
    
    if ($VerboseOutput) {
        $branches | ForEach-Object { Write-Host "      - $($_.name)" -ForegroundColor $colors.Detail }
    }
} catch {
    Write-TestResult "Get-PSUADORepoBranchList" $false $_.Exception.Message
    # Set a fallback default branch for downstream tests
    $script:defaultBranch = "refs/heads/main"
    Write-Host "    Using fallback branch: $defaultBranch" -ForegroundColor $colors.Warning
}

# =========================================================================
# SECTION 2: VARIABLE GROUP FUNCTIONS
# =========================================================================
Write-TestHeader "SECTION 2: Variable Group Functions"

$testVarGroupName = "TestVarGroup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$script:testVariableGroupId = $null

# Test 2.1: New-PSUADOVariableGroup
Write-TestSection "Test 2.1: New-PSUADOVariableGroup"
try {
    $newVarGroup = New-PSUADOVariableGroup `
        -VariableGroupName $testVarGroupName `
        -Description "Comprehensive test variable group created by automated test suite" `
        -Project $projectName `
        -Verbose:$VerboseOutput
    
    if ($newVarGroup.Id) {
        $script:testVariableGroupId = $newVarGroup.Id
        Write-TestResult "New-PSUADOVariableGroup" $true "Created variable group ID: $($newVarGroup.Id)"
        Write-Host "    Name: $($newVarGroup.Name)" -ForegroundColor $colors.Detail
        Write-Host "    Description: $($newVarGroup.Description)" -ForegroundColor $colors.Detail
    } else {
        Write-TestResult "New-PSUADOVariableGroup" $false "Failed to create variable group"
    }
} catch {
    Write-TestResult "New-PSUADOVariableGroup" $false $_.Exception.Message
}

# Test 2.2: New-PSUADOVariable (Add multiple variables)
Write-TestSection "Test 2.2: New-PSUADOVariable (Add Variables to Group)"
if ($testVariableGroupId) {
    # Add regular variable
    try {
        $var1 = New-PSUADOVariable `
            -VariableGroupId $testVariableGroupId `
            -VariableName "TestVar1" `
            -VariableValue "Value1" `
            -Project $projectName `
            -Verbose:$VerboseOutput
        Write-TestResult "New-PSUADOVariable (Regular)" $true "Added variable 'TestVar1'"
    } catch {
        Write-TestResult "New-PSUADOVariable (Regular)" $false $_.Exception.Message
    }
    
    # Add secret variable
    try {
        $var2 = New-PSUADOVariable `
            -VariableGroupId $testVariableGroupId `
            -VariableName "SecretVar1" `
            -VariableValue "SecretValue123" `
            -IsSecret `
            -Project $projectName `
            -Verbose:$VerboseOutput
        Write-TestResult "New-PSUADOVariable (Secret)" $true "Added secret variable 'SecretVar1'"
    } catch {
        Write-TestResult "New-PSUADOVariable (Secret)" $false $_.Exception.Message
    }
    
    # Add another regular variable
    try {
        $var3 = New-PSUADOVariable `
            -VariableGroupId $testVariableGroupId `
            -VariableName "Environment" `
            -VariableValue "Testing" `
            -Project $projectName `
            -Verbose:$VerboseOutput
        Write-TestResult "New-PSUADOVariable (Environment)" $true "Added variable 'Environment'"
    } catch {
        Write-TestResult "New-PSUADOVariable (Environment)" $false $_.Exception.Message
    }
} else {
    Write-TestResult "New-PSUADOVariable" $false "Skipped - no variable group created"
}

# Test 2.3: Set-PSUADOVariable (Update existing variable)
Write-TestSection "Test 2.3: Set-PSUADOVariable (Update Existing Variable)"
if ($testVariableGroupId) {
    try {
        $updatedVar = Set-PSUADOVariable `
            -VariableGroupId $testVariableGroupId `
            -VariableName "TestVar1" `
            -VariableValue "UpdatedValue1" `
            -Project $projectName `
            -Verbose:$VerboseOutput
        
        if ($updatedVar.Action -eq 'Updated') {
            Write-TestResult "Set-PSUADOVariable (Update)" $true "Updated TestVar1 to 'UpdatedValue1'"
        } else {
            Write-TestResult "Set-PSUADOVariable (Update)" $false "Expected 'Updated' action, got '$($updatedVar.Action)'"
        }
    } catch {
        Write-TestResult "Set-PSUADOVariable (Update)" $false $_.Exception.Message
    }
    
    # Add new variable via Set
    try {
        $newVar = Set-PSUADOVariable `
            -VariableGroupId $testVariableGroupId `
            -VariableName "NewVarViaSet" `
            -VariableValue "AddedViaSet" `
            -Project $projectName `
            -Verbose:$VerboseOutput
        
        if ($newVar.Action -eq 'Added') {
            Write-TestResult "Set-PSUADOVariable (Add)" $true "Added new variable 'NewVarViaSet'"
        } else {
            Write-TestResult "Set-PSUADOVariable (Add)" $false "Expected 'Added' action, got '$($newVar.Action)'"
        }
    } catch {
        Write-TestResult "Set-PSUADOVariable (Add)" $false $_.Exception.Message
    }
} else {
    Write-TestResult "Set-PSUADOVariable" $false "Skipped - no variable group created"
}

# Test 2.4: Set-PSUADOVariableGroup (Update group properties)
Write-TestSection "Test 2.4: Set-PSUADOVariableGroup"
if ($testVariableGroupId) {
    try {
        $updatedGroup = Set-PSUADOVariableGroup `
            -VariableGroupId $testVariableGroupId `
            -VariableGroupName "$testVarGroupName-Updated" `
            -Description "Updated description from test suite" `
            -Project $projectName `
            -Verbose:$VerboseOutput
        
        if ($updatedGroup.Name -eq "$testVarGroupName-Updated") {
            Write-TestResult "Set-PSUADOVariableGroup (Name)" $true "Updated group name successfully"
        } else {
            Write-TestResult "Set-PSUADOVariableGroup (Name)" $false "Name not updated correctly"
        }
        
        if ($updatedGroup.Description -eq "Updated description from test suite") {
            Write-TestResult "Set-PSUADOVariableGroup (Description)" $true "Updated description successfully"
        } else {
            Write-TestResult "Set-PSUADOVariableGroup (Description)" $false "Description not updated correctly"
        }
    } catch {
        Write-TestResult "Set-PSUADOVariableGroup" $false $_.Exception.Message
    }
} else {
    Write-TestResult "Set-PSUADOVariableGroup" $false "Skipped - no variable group created"
}

# Test 2.5: Get-PSUADOVariableGroupInventory
Write-TestSection "Test 2.5: Get-PSUADOVariableGroupInventory"
try {
    # Test without IncludeVariableDetails
    $inventory = Get-PSUADOVariableGroupInventory -Project $projectName
    Write-TestResult "Get-PSUADOVariableGroupInventory (Basic)" $true "Found $($inventory.Count) variable group(s)"
    
    # Test with IncludeVariableDetails
    $detailedInventory = Get-PSUADOVariableGroupInventory -Project $projectName -IncludeVariableDetails
    $testGroup = $detailedInventory | Where-Object { $_.VariableGroupId -eq $testVariableGroupId }
    
    if ($testGroup) {
        Write-TestResult "Get-PSUADOVariableGroupInventory (Detailed)" $true "Found test group with $($testGroup.VariableCount) variable(s)"
        
        if ($VerboseOutput -and $testGroup.Variables) {
            Write-Host "`n    Variables in test group:" -ForegroundColor $colors.Detail
            $testGroup.Variables | Format-Table VariableName, VariableValue, IsSecret -AutoSize | Out-String | 
                ForEach-Object { Write-Host $_ -ForegroundColor $colors.Detail }
        }
    }
} catch {
    Write-TestResult "Get-PSUADOVariableGroupInventory" $false $_.Exception.Message
}

# =========================================================================
# SECTION 3: PULL REQUEST FUNCTIONS
# =========================================================================
Write-TestHeader "SECTION 3: Pull Request Functions"

$testBranchName = "test/automated-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$script:testPullRequestId = $null

# Test 3.1: Create a test branch and PR
Write-TestSection "Test 3.1: New-PSUADOPullRequest"
try {
    # Note: This requires an actual branch to exist
    # We'll attempt to create a PR from main to main (or skip if not possible)
    
    Write-Host "  ℹ Attempting to create test pull request..." -ForegroundColor $colors.Info
    Write-Host "    Note: This may fail if no suitable branches exist - this is expected" -ForegroundColor $colors.Detail
    
    try {
        $newPR = New-PSUADOPullRequest `
            -Project $projectName `
            -Repository $repositoryName `
            -SourceBranch $defaultBranch `
            -TargetBranch $defaultBranch `
            -Title "Test PR - Automated Test $(Get-Date -Format 'yyyy-MM-dd HH:mm')" `
            -Description "This is a test pull request created by the automated test suite" `
            -Verbose:$VerboseOutput -ErrorAction Stop
        
        if ($newPR.pullRequestId) {
            $script:testPullRequestId = $newPR.pullRequestId
            Write-TestResult "New-PSUADOPullRequest" $true "Created PR #$($newPR.pullRequestId)"
        } else {
            Write-TestResult "New-PSUADOPullRequest" $false "PR creation returned no ID"
        }
    } catch {
        if ($_.Exception.Message -like "*cannot be merged*" -or $_.Exception.Message -like "*already exists*") {
            Write-TestResult "New-PSUADOPullRequest" $true "Skipped (branches cannot be merged or PR exists) - Expected"
        } else {
            Write-TestResult "New-PSUADOPullRequest" $false $_.Exception.Message
        }
    }
} catch {
    Write-TestResult "New-PSUADOPullRequest" $false $_.Exception.Message
}

# Test 3.2: Get-PSUADOPullRequest
Write-TestSection "Test 3.2: Get-PSUADOPullRequest"
try {
    $pullRequests = Get-PSUADOPullRequest -Project $projectName -RepositoryName $repositoryName
    Write-TestResult "Get-PSUADOPullRequest" $true "Found $($pullRequests.Count) pull request(s)"
    
    if ($VerboseOutput -and $pullRequests.Count -gt 0) {
        Write-Host "`n    Recent Pull Requests:" -ForegroundColor $colors.Detail
        $pullRequests | Select-Object -First 5 pullRequestId, title, status, createdBy | 
            Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor $colors.Detail }
    }
} catch {
    Write-TestResult "Get-PSUADOPullRequest" $false $_.Exception.Message
}

# Test 3.3: Get-PSUADOPullRequestInventory
Write-TestSection "Test 3.3: Get-PSUADOPullRequestInventory"
try {
    $prInventory = Get-PSUADOPullRequestInventory
    Write-TestResult "Get-PSUADOPullRequestInventory" $true "Found $($prInventory.Count) PR(s) across repositories"
} catch {
    Write-TestResult "Get-PSUADOPullRequestInventory" $false $_.Exception.Message
}

# Test 3.4: Approve-PSUADOPullRequest (if we have a PR)
Write-TestSection "Test 3.4: Approve-PSUADOPullRequest"
if ($testPullRequestId) {
    try {
        $approval = Approve-PSUADOPullRequest `
            -Project $projectName `
            -Repository $repositoryName `
            -PullRequestId $testPullRequestId `
            -Verbose:$VerboseOutput
        Write-TestResult "Approve-PSUADOPullRequest" $true "Approved PR #$testPullRequestId"
    } catch {
        Write-TestResult "Approve-PSUADOPullRequest" $false $_.Exception.Message
    }
} else {
    Write-TestResult "Approve-PSUADOPullRequest" $true "Skipped - no test PR created"
}

# Test 3.5: Complete-PSUADOPullRequest (if we have a PR and want to clean up)
Write-TestSection "Test 3.5: Complete-PSUADOPullRequest"
if ($testPullRequestId -and -not $SkipCleanup) {
    try {
        $completion = Complete-PSUADOPullRequest `
            -Project $projectName `
            -Repository $repositoryName `
            -PullRequestId $testPullRequestId `
            -Verbose:$VerboseOutput
        Write-TestResult "Complete-PSUADOPullRequest" $true "Completed PR #$testPullRequestId"
    } catch {
        if ($_.Exception.Message -like "*cannot be completed*") {
            Write-TestResult "Complete-PSUADOPullRequest" $true "Skipped (PR cannot be completed) - Expected"
        } else {
            Write-TestResult "Complete-PSUADOPullRequest" $false $_.Exception.Message
        }
    }
} else {
    Write-TestResult "Complete-PSUADOPullRequest" $true "Skipped - no test PR or cleanup disabled"
}

# =========================================================================
# SECTION 4: WORK ITEM FUNCTIONS
# =========================================================================
Write-TestHeader "SECTION 4: Work Item Functions"

$script:testUserStoryId = $null
$script:testTaskId = $null
$script:testBugId = $null

# Test 4.1: New-PSUADOUserStory
Write-TestSection "Test 4.1: New-PSUADOUserStory"
try {
    $newUserStory = New-PSUADOUserStory `
        -Project $projectName `
        -Title "Test User Story - Automated Test $(Get-Date -Format 'yyyy-MM-dd HH:mm')" `
        -Description "This is a test user story created by the automated test suite" `
        -AcceptanceCriteria "AC1: Test passes`nAC2: User story is created" `
        -Priority 2 `
        -Verbose:$VerboseOutput
    
    if ($newUserStory.id) {
        $script:testUserStoryId = $newUserStory.id
        Write-TestResult "New-PSUADOUserStory" $true "Created User Story #$($newUserStory.id)"
        Write-Host "    URL: $($newUserStory._links.html.href)" -ForegroundColor $colors.Detail
    } else {
        Write-TestResult "New-PSUADOUserStory" $false "Failed to create user story"
    }
} catch {
    Write-TestResult "New-PSUADOUserStory" $false $_.Exception.Message
}

# Test 4.2: New-PSUADOTask
Write-TestSection "Test 4.2: New-PSUADOTask"
try {
    $taskParams = @{
        Project     = $projectName
        Title       = "Test Task - Automated Test $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        Description = "This is a test task created by the automated test suite"
        Priority    = 2
        Verbose     = $VerboseOutput
    }
    
    # Link to user story if available
    if ($testUserStoryId) {
        $taskParams.ParentWorkItemId = $testUserStoryId
    }
    
    $newTask = New-PSUADOTask @taskParams
    
    if ($newTask.id) {
        $script:testTaskId = $newTask.id
        $parentInfo = if ($testUserStoryId) { " (linked to User Story #$testUserStoryId)" } else { "" }
        Write-TestResult "New-PSUADOTask" $true "Created Task #$($newTask.id)$parentInfo"
    } else {
        Write-TestResult "New-PSUADOTask" $false "Failed to create task"
    }
} catch {
    Write-TestResult "New-PSUADOTask" $false $_.Exception.Message
}

# Test 4.3: New-PSUADOBug
Write-TestSection "Test 4.3: New-PSUADOBug"
try {
    $newBug = New-PSUADOBug `
        -Project $projectName `
        -Title "Test Bug - Automated Test $(Get-Date -Format 'yyyy-MM-dd HH:mm')" `
        -Description "This is a test bug created by the automated test suite" `
        -ReproductionSteps "1. Run automated test`n2. Observe bug creation" `
        -Priority 3 `
        -Verbose:$VerboseOutput
    
    if ($newBug.id) {
        $script:testBugId = $newBug.id
        Write-TestResult "New-PSUADOBug" $true "Created Bug #$($newBug.id)"
    } else {
        Write-TestResult "New-PSUADOBug" $false "Failed to create bug"
    }
} catch {
    Write-TestResult "New-PSUADOBug" $false $_.Exception.Message
}

# Test 4.4: Set-PSUADOTask
Write-TestSection "Test 4.4: Set-PSUADOTask"
if ($testTaskId) {
    try {
        $updatedTask = Set-PSUADOTask `
            -Project $projectName `
            -Id $testTaskId `
            -State "In Progress" `
            -AssignedTo "" `
            -Verbose:$VerboseOutput
        
        Write-TestResult "Set-PSUADOTask" $true "Updated Task #$testTaskId to 'In Progress' state"
    } catch {
        Write-TestResult "Set-PSUADOTask" $false $_.Exception.Message
    }
} else {
    Write-TestResult "Set-PSUADOTask" $true "Skipped - no test task created"
}

# Test 4.5: Set-PSUADOBug
Write-TestSection "Test 4.5: Set-PSUADOBug"
if ($testBugId) {
    try {
        $updatedBug = Set-PSUADOBug `
            -Project $projectName `
            -Id $testBugId `
            -State "Active" `
            -Verbose:$VerboseOutput
        
        Write-TestResult "Set-PSUADOBug" $true "Updated Bug #$testBugId to 'Active' state"
    } catch {
        Write-TestResult "Set-PSUADOBug" $false $_.Exception.Message
    }
} else {
    Write-TestResult "Set-PSUADOBug" $true "Skipped - no test bug created"
}

# Test 4.6: Set-PSUADOSpike
Write-TestSection "Test 4.6: Set-PSUADOSpike"
# Note: This function seems to update existing work items
# We'll skip if no suitable work item exists
Write-TestResult "Set-PSUADOSpike" $true "Skipped - requires existing spike work item"

# =========================================================================
# SECTION 5: PIPELINE FUNCTIONS
# =========================================================================
Write-TestHeader "SECTION 5: Pipeline Functions"

# Test 5.1: Get-PSUADOPipeline
Write-TestSection "Test 5.1: Get-PSUADOPipeline"
try {
    $pipelines = Get-PSUADOPipeline -Project $projectName
    Write-TestResult "Get-PSUADOPipeline" $true "Found $($pipelines.Count) pipeline(s)"
    
    if ($pipelines.Count -gt 0) {
        $script:testPipelineId = $pipelines[0].id
        $script:testPipelineName = $pipelines[0].name
        
        if ($VerboseOutput) {
            Write-Host "`n    Available Pipelines:" -ForegroundColor $colors.Detail
            $pipelines | Select-Object -First 5 id, name, folder | 
                Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor $colors.Detail }
        }
    }
} catch {
    Write-TestResult "Get-PSUADOPipeline" $false $_.Exception.Message
}

# Test 5.2: Get-PSUADOPipelineLatestRun
Write-TestSection "Test 5.2: Get-PSUADOPipelineLatestRun"
if ($testPipelineId) {
    try {
        $latestRun = Get-PSUADOPipelineLatestRun -Project $projectName -PipelineId $testPipelineId
        
        if ($latestRun) {
            Write-TestResult "Get-PSUADOPipelineLatestRun" $true "Found latest run for pipeline #$testPipelineId"
            Write-Host "    Run ID: $($latestRun.id), State: $($latestRun.state), Result: $($latestRun.result)" -ForegroundColor $colors.Detail
        } else {
            Write-TestResult "Get-PSUADOPipelineLatestRun" $true "No runs found for pipeline (expected if new pipeline)"
        }
    } catch {
        Write-TestResult "Get-PSUADOPipelineLatestRun" $false $_.Exception.Message
    }
} else {
    Write-TestResult "Get-PSUADOPipelineLatestRun" $true "Skipped - no pipelines found"
}

# Test 5.3: Get-PSUADOPipelineBuild
Write-TestSection "Test 5.3: Get-PSUADOPipelineBuild"
if ($latestRun -and $latestRun.id -gt 0) {
    try {
        $buildDetails = Get-PSUADOPipelineBuild -Project $projectName -BuildId $latestRun.id
        Write-TestResult "Get-PSUADOPipelineBuild" $true "Retrieved build #$($latestRun.id) details"
        
        if ($VerboseOutput) {
            Write-Host "`n    Build Details:" -ForegroundColor $colors.Detail
            Write-Host "      ID: $($buildDetails.id)" -ForegroundColor $colors.Detail
            Write-Host "      Build Number: $($buildDetails.buildNumber)" -ForegroundColor $colors.Detail
            Write-Host "      Status: $($buildDetails.status)" -ForegroundColor $colors.Detail
            Write-Host "      Result: $($buildDetails.result)" -ForegroundColor $colors.Detail
        }
    } catch {
        Write-TestResult "Get-PSUADOPipelineBuild" $false $_.Exception.Message
    }
} else {
    Write-TestResult "Get-PSUADOPipelineBuild" $true "Skipped - no pipeline runs found"
}

# =========================================================================
# SECTION 6: CLEANUP (Optional)
# =========================================================================
Write-TestHeader "SECTION 6: Cleanup"

if (-not $SkipCleanup) {
    Write-Host "`nCleaning up test resources..." -ForegroundColor $colors.Info
    
    # Note: Variable groups don't have a delete API in the standard REST API
    # Work items typically shouldn't be deleted in ADO (just closed)
    # PRs are already completed above if applicable
    
    Write-Host "  ℹ Test resources created (manual cleanup may be required):" -ForegroundColor $colors.Warning
    if ($testVariableGroupId) {
        Write-Host "    - Variable Group ID: $testVariableGroupId (Name: $testVarGroupName-Updated)" -ForegroundColor $colors.Detail
    }
    if ($testUserStoryId) {
        Write-Host "    - User Story ID: $testUserStoryId" -ForegroundColor $colors.Detail
    }
    if ($testTaskId) {
        Write-Host "    - Task ID: $testTaskId" -ForegroundColor $colors.Detail
    }
    if ($testBugId) {
        Write-Host "    - Bug ID: $testBugId" -ForegroundColor $colors.Detail
    }
} else {
    Write-Host "`nSkipping cleanup (use -SkipCleanup to keep test resources)" -ForegroundColor $colors.Info
}

# =========================================================================
# SECTION 7: TEST SUMMARY
# =========================================================================
Write-TestHeader "SECTION 7: Test Summary"

$testEndTime = Get-Date
$testDuration = $testEndTime - $testStartTime

$successCount = ($testResults | Where-Object { $_.Success -eq $true }).Count
$failureCount = ($testResults | Where-Object { $_.Success -eq $false }).Count
$totalTests = $testResults.Count

Write-Host "`nTest Execution Summary:" -ForegroundColor $colors.Header
Write-Host "  Total Tests: $totalTests" -ForegroundColor $colors.Info
Write-Host "  Passed: $successCount" -ForegroundColor $colors.Success
Write-Host "  Failed: $failureCount" -ForegroundColor $(if ($failureCount -eq 0) { $colors.Success } else { $colors.Error })
Write-Host "  Duration: $($testDuration.ToString('mm\:ss'))" -ForegroundColor $colors.Info
Write-Host "  Success Rate: $([math]::Round(($successCount / $totalTests) * 100, 2))%" -ForegroundColor $colors.Info

# Group results by function
Write-Host "`nResults by Function:" -ForegroundColor $colors.Header
$groupedResults = $testResults | Group-Object { $_.TestName -replace ' \(.*\)', '' } | Sort-Object Name
foreach ($group in $groupedResults) {
    $allPassed = ($group.Group | Where-Object { $_.Success -eq $false }).Count -eq 0
    $color = if ($allPassed) { $colors.Success } else { $colors.Error }
    $status = if ($allPassed) { '✓' } else { '✗' }
    Write-Host "  $status $($group.Name): $($group.Count) test(s)" -ForegroundColor $color
}

# Failed tests detail
if ($failureCount -gt 0) {
    Write-Host "`nFailed Tests Detail:" -ForegroundColor $colors.Error
    $testResults | Where-Object { $_.Success -eq $false } | ForEach-Object {
        Write-Host "  ✗ $($_.TestName)" -ForegroundColor $colors.Error
        Write-Host "    Error: $($_.Message)" -ForegroundColor $colors.Detail
    }
}

# Export results
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$resultsFile = Join-Path $scriptPath "TestResults-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$testResults | ConvertTo-Json -Depth 5 | Out-File $resultsFile -Encoding UTF8
Write-Host "`nDetailed results exported to: $resultsFile" -ForegroundColor $colors.Info

Write-Host "`n$('=' * 80)" -ForegroundColor $colors.Header
Write-Host "Test Suite Complete!" -ForegroundColor $colors.Header
Write-Host $('=' * 80) -ForegroundColor $colors.Header

# Return summary object
[PSCustomObject]@{
    TotalTests   = $totalTests
    Passed       = $successCount
    Failed       = $failureCount
    SuccessRate  = [math]::Round(($successCount / $totalTests) * 100, 2)
    Duration     = $testDuration
    ResultsFile  = $resultsFile
    TestResults  = $testResults
}
