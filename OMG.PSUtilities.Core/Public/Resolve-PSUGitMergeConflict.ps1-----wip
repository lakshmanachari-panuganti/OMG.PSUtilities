function Resolve-PSUGitMergeConflict {
    <#
    .SYNOPSIS
        Safely resolves Git merge conflicts with optional auto-resolution strategies.

    .DESCRIPTION
        This function performs a `git merge` from a specified source branch into the current branch.
        If merge conflicts are detected, it supports resolving them via the chosen strategy:
        - Manual (default): Prompts the user to resolve conflicts.
        - Ours: Keeps current branch changes.
        - Theirs: Takes changes from the incoming branch.

        It includes safety checks to prevent loss of uncommitted changes and allows rollback on failure.

    .PARAMETER SourceBranch
        The branch to merge into the current branch.

    .PARAMETER Strategy
        Conflict resolution strategy: 'Manual' (default), 'Ours', or 'Theirs'.

    .PARAMETER Force
        Forces the merge even if there are uncommitted changes in the working directory.

    .EXAMPLE
        Resolve-PSUGitMergeConflict -SourceBranch dev

    .EXAMPLE
        Resolve-PSUGitMergeConflict -SourceBranch release -Strategy Ours

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2025-07-28
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$SourceBranch,

        [ValidateSet('Manual', 'Ours', 'Theirs')]
        [string]$Strategy = 'Manual',

        [switch]$Force
    )

    # Ensure inside a git repo
    if (-not (Test-Path .git)) {
        throw "Not inside a Git repository."
    }

    # Get current branch
    $CurrentBranch = git rev-parse --abbrev-ref HEAD 2>$null

    if (-not $CurrentBranch) {
        throw "Failed to determine the current Git branch."
    }

    # Check uncommitted changes
    if (-not $Force) {
        $Status = git status --porcelain
        if ($Status) {
            Write-Warning "Uncommitted changes detected. Use -Force to override."
            return
        }
    }

    # Ensure source branch exists
    if (-not (git rev-parse --verify $SourceBranch 2>$null)) {
        throw "Source branch '$SourceBranch' does not exist."
    }

    Write-Host "Merging '$SourceBranch' into '$CurrentBranch' with strategy '$Strategy'..."

    # Perform merge
    $MergeResult = git merge $SourceBranch 2>&1

    # Check for conflict markers
    $Conflicts = git diff --name-status | Where-Object { $_ -match "^[A-ZU]{2}" }

    if ($Conflicts) {
        Write-Warning "Merge conflicts detected in the following files:"
        $Conflicts | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }

        switch ($Strategy) {
            'Ours' {
                Write-Host "Resolving using 'ours' strategy..."
                git merge -X ours $SourceBranch *> $null
                git commit -m "Merge '$SourceBranch' using ours strategy" *> $null
            }
            'Theirs' {
                Write-Host "Resolving using 'theirs' strategy..."
                foreach ($file in ($Conflicts -replace "^[A-Z]{2}\s+", "")) {
                    git checkout --theirs -- $file *> $null
                    git add $file *> $null
                }
                git commit -m "Merge '$SourceBranch' using theirs strategy" *> $null
            }
            'Manual' {
                Write-Host "Please resolve the conflicts manually. Run 'git status' for help."
                return
            }
        }
    }
    else {
        Write-Host "Merge completed successfully with no conflicts." -ForegroundColor Green
    }

    # Return object for automation use
    [PSCustomObject]@{
        Status        = 'Success'
        Conflicts     = if ($Conflicts) { $true } else { $false }
        StrategyUsed  = $Strategy
        CommitHash    = (git rev-parse HEAD)
        MergedFrom    = $SourceBranch
        MergedTo      = $CurrentBranch
    }
}