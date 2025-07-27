function Invoke-SafeGitCheckout {
    <#
    .SYNOPSIS
    Safely switches to a specified Git branch by checking for uncommitted changes and prompting for action.

    .DESCRIPTION
    This function attempts to switch to a specified Git branch. If uncommitted local changes would be overwritten during checkout,
    it prompts the user to either:
    - Commit the changes with a custom message,
    - Stash the changes (optionally with a stash message), or
    - Abort the operation.

    This is useful when automating Git workflows or when ensuring the local working directory stays consistent across branch switches.

    .PARAMETER TargetBranch
    The name of the Git branch to switch to. This should be a valid local or remote branch name.

    .EXAMPLE
    Invoke-SafeGitCheckout -TargetBranch "main"

    Attempts to switch to the "main" branch. If uncommitted changes exist, prompts to commit, stash, or abort.

    .OUTPUTS
    String output from git commands and warnings based on action taken.

    .NOTES
    Author      : Lakshmanachari Panuganti
    Date        : 2025-07-27
    Version     : 1.0
    Git Required: Yes (CLI must be available in environment)

    .LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AI

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$TargetBranch
    )

    try {
        git checkout $TargetBranch 2>&1 | ForEach-Object {
            if ($_ -match "would be overwritten by checkout") {
                Write-Warning "Uncommitted changes would be overwritten by switching to '$TargetBranch'."
                
                $choice = Read-Host "Choose an action: (C)ommit, (S)tash, or (A)bort"

                switch ($choice.ToUpper()) {
                    "C" {
                        $commitMessage = Read-Host "Enter a commit message"
                        git add .
                        git commit -m "$commitMessage"
                        git checkout $TargetBranch
                    }
                    "S" {
                        $msg = Read-Host "Enter stash message (or leave empty)"
                        if ($msg) {
                            git stash push -m "$msg"
                        } else {
                            git stash
                        }
                        git checkout $TargetBranch
                    }
                    default {
                        Write-Host "Aborted switching branches." -ForegroundColor Yellow
                    }
                }
            }
            else {
                Write-Output $_
            }
        }
    } catch {
        Write-Error "Error while checking out branch: $_"
    }
}
