function Invoke-SafeGitCheckout {
    <#
    .SYNOPSIS
        Safely checks out a target Git branch and pulls the latest changes, then returns to the original branch.

    .DESCRIPTION
        Handles uncommitted changes by prompting the user to commit, stash, or abort.
        Fetches and pulls the latest changes from the remote for the target branch.
        Ensures a safe switch to the target branch and back to the original branch.

    .PARAMETER TargetBranch
        The branch to checkout and pull the latest changes into.

    .PARAMETER ReturnToBranch
        The branch to return to after syncing the target branch. If not specified, it uses the current branch before switch.

    .EXAMPLE
        Invoke-SafeGitCheckout -TargetBranch main -ReturnToBranch feature/login-ui

    .NOTES
        Author: Lakshmanachari Panuganti
        Created: 2025-07-28
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$TargetBranch,

        [string]$ReturnToBranch
    )

    # Get current branch if not explicitly passed
    if (-not $ReturnToBranch) {
        $ReturnToBranch = git rev-parse --abbrev-ref HEAD
    }

    # Check for uncommitted changes
    $hasUncommitted = git status --porcelain
    if ($hasUncommitted) {
        Write-Warning "You have uncommitted changes in your working directory."

        $choice = Read-Host "Choose an action: (C)ommit, (S)tash, or (A)bort"
        switch ($choice.ToUpper()) {
            'C' {
                Invoke-PSUGitCommit  
            }
            'S' {
                git stash push -m "Auto-stash before switching to $TargetBranch"
            }
            default {
                throw "Aborted due to uncommitted changes."
            }
        }
    }

    Write-Host "Fetching latest from origin/$TargetBranch..." -ForegroundColor Cyan
    git fetch origin $TargetBranch *> $null

    Write-Host "Checking out $TargetBranch..." -ForegroundColor Cyan
    git checkout $TargetBranch *> $null

    Write-Host "Pulling latest into $TargetBranch..." -ForegroundColor Cyan
    git pull origin $TargetBranch *> $null

    if ($ReturnToBranch -ne $TargetBranch) {
        Write-Host "Switching back to $ReturnToBranch..." -ForegroundColor Cyan
        git checkout $ReturnToBranch *> $null
    }
}