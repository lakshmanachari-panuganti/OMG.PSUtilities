function Resolve-PSUGitMergeConflict {
    <#
    .SYNOPSIS
        Performs a safe Git merge and optionally resolves conflicts using predefined strategies.
    .DESCRIPTION
        Merges a feature branch into a target branch (usually main) and handles merge conflicts based on the strategy:
        - 'Manual': Leaves conflicts for manual resolution and opens merge tool.
        - 'Ours': Prefers current branch changes in conflicts during merge.
        - 'Theirs': Prefers incoming branch changes in conflicts during merge.
        
        The function performs safety checks and provides rollback capabilities.
    .PARAMETER TargetBranch
        The branch you want to merge into (e.g., main).
    .PARAMETER SourceBranch
        The feature branch to be merged.
    .PARAMETER ConflictResolutionStrategy
        Conflict resolution strategy: 'Manual' (default), 'Ours', or 'Theirs'.
    .PARAMETER Force
        Skip the working directory clean check (use with caution).
    .EXAMPLE
        Resolve-PSUGitMergeConflict -TargetBranch main -SourceBranch feature/dev -ConflictResolutionStrategy Ours
    .EXAMPLE
        Resolve-PSUGitMergeConflict -TargetBranch main -SourceBranch feature/auth
    .NOTES
        Author: Lakshmanachari Panuganti
        Created: 2025-07-28
        Revised: 2025-07-28
        
        Safety features:
        - Validates Git repository and branch existence
        - Checks for clean working directory
        - Provides merge abort capability
        - Uses proper Git merge strategies
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$TargetBranch,
        
        [Parameter(Mandatory)]
        [string]$SourceBranch,
        
        [ValidateSet("Manual", "Ours", "Theirs")]
        [string]$ConflictResolutionStrategy = "Manual",
        
        [switch]$Force
    )
    
    # Ensure Git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git CLI not found. Please install Git and ensure it's in the system PATH."
    }
    
    try {
        # Validate we're in a Git repository
        $null = git rev-parse --git-dir 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Not in a Git repository. Please run this command from within a Git repository."
        }
        
        # Store original branch for potential rollback
        $originalBranch = git branch --show-current
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to determine current branch."
        }
        
        # Validate target branch exists
        $null = git show-ref --verify --quiet "refs/heads/$TargetBranch"
        if ($LASTEXITCODE -ne 0) {
            throw "Target branch '$TargetBranch' does not exist."
        }
        
        # Validate source branch exists
        $null = git show-ref --verify --quiet "refs/heads/$SourceBranch"
        if ($LASTEXITCODE -ne 0) {
            throw "Source branch '$SourceBranch' does not exist."
        }
        
        # Check if working directory is clean (unless forced)
        if (-not $Force) {
            $status = git status --porcelain 2>&1
            if ($LASTEXITCODE -eq 0 -and $status) {
                throw "Working directory is not clean. Please commit or stash your changes, or use -Force to proceed anyway."
            }
        }
        
        Write-Host "Checking out target branch '$TargetBranch'..." -ForegroundColor Cyan
        git checkout $TargetBranch 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to checkout target branch '$TargetBranch'."
        }
        
        Write-Host "Pulling latest changes for '$TargetBranch'..." -ForegroundColor Cyan
        git pull origin $TargetBranch 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to pull latest changes. Continuing with local branch."
        }
        
        # Perform merge based on strategy
        Write-Host "Merging '$SourceBranch' into '$TargetBranch'..." -ForegroundColor Cyan
        
        switch ($ConflictResolutionStrategy) {
            "Ours" {
                Write-Host "Using 'ours' strategy for automatic conflict resolution..." -ForegroundColor Yellow
                git merge -X ours $SourceBranch 2>&1 | Tee-Object -Variable mergeOutput
            }
            "Theirs" {
                Write-Host "Using 'theirs' strategy for automatic conflict resolution..." -ForegroundColor Yellow
                git merge -X theirs $SourceBranch 2>&1 | Tee-Object -Variable mergeOutput
            }
            "Manual" {
                git merge $SourceBranch 2>&1 | Tee-Object -Variable mergeOutput
            }
        }
        
        # Check merge result
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Merge completed successfully!" -ForegroundColor Green
            Write-Host "Summary:" -ForegroundColor Cyan
            git log --oneline -1
        }
        else {
            # Check if it's a conflict or other error
            $conflictStatus = git status --porcelain 2>&1 | Where-Object { $_ -match "^(AA|UU|DD)" }
            
            if ($conflictStatus) {
                Write-Warning "Merge conflicts detected in the following files:"
                git status --porcelain | Where-Object { $_ -match "^(AA|UU|DD)" } | ForEach-Object {
                    Write-Host "  $_" -ForegroundColor Red
                }
                
                if ($ConflictResolutionStrategy -eq "Manual") {
                    Write-Host "`nConflict resolution options:" -ForegroundColor Yellow
                    Write-Host "1. Resolve conflicts manually and run: git commit" -ForegroundColor White
                    Write-Host "2. Abort merge and return to original state: git merge --abort" -ForegroundColor White
                    Write-Host "3. Use merge tool: git mergetool" -ForegroundColor White
                    
                    # Try to open merge tool if available
                    $mergeTool = git config --get merge.tool 2>$null
                    if ($mergeTool) {
                        $response = Read-Host "Open merge tool '$mergeTool'? (y/N)"
                        if ($response -match "^[Yy]") {
                            git mergetool
                        }
                    }
                }
                else {
                    Write-Error "Automatic conflict resolution failed. This shouldn't happen with -X strategy."
                    Write-Host "Run 'git merge --abort' to cancel the merge." -ForegroundColor Red
                }
            }
            else {
                Write-Error "Merge failed with error: $($mergeOutput -join "`n")"
                Write-Host "Run 'git merge --abort' to cancel the merge." -ForegroundColor Red
            }
        }
        
    }
    catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
        
        # Check if we're in middle of a merge
        if (Test-Path ".git/MERGE_HEAD") {
            Write-Host "`nYou can abort the merge with: git merge --abort" -ForegroundColor Yellow
        }
        
        # Offer to return to original branch
        $currentBranch = git branch --show-current 2>$null
        if ($currentBranch -and $originalBranch -and $currentBranch -ne $originalBranch) {
            $response = Read-Host "Return to original branch '$originalBranch'? (y/N)"
            if ($response -match "^[Yy]") {
                git checkout $originalBranch 2>&1 | Out-Null
            }
        }
    }
}

# Helper function to check merge status
function Get-GitMergeStatus {
    <#
    .SYNOPSIS
        Checks if a Git merge is in progress and shows conflict status.
    .DESCRIPTION
        Displays information about ongoing merge conflicts and provides guidance.
    #>
    
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "Git CLI not found."
        return
    }
    
    if (Test-Path ".git/MERGE_HEAD") {
        Write-Host "Merge in progress!" -ForegroundColor Yellow
        
        $conflicts = git status --porcelain | Where-Object { $_ -match "^(AA|UU|DD)" }
        if ($conflicts) {
            Write-Host "`nConflicted files:" -ForegroundColor Red
            $conflicts | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
            
            Write-Host "`nNext steps:" -ForegroundColor Cyan
            Write-Host "1. Resolve conflicts in the files above" -ForegroundColor White
            Write-Host "2. Stage resolved files: git add <file>" -ForegroundColor White
            Write-Host "3. Complete merge: git commit" -ForegroundColor White
            Write-Host "4. Or abort merge: git merge --abort" -ForegroundColor White
        }
        else {
            Write-Host "All conflicts resolved. Run 'git commit' to complete the merge." -ForegroundColor Green
        }
    }
    else {
        Write-Host "No merge in progress." -ForegroundColor Green
    }
}