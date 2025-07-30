function Get-PSUGitFileChangeMetadata {
    <#
    .SYNOPSIS
        Gets metadata about file changes between two Git branches.

    .DESCRIPTION
        Compares two Git branches using `git diff --name-status` and returns structured metadata.
        It includes file paths, type of change (New, Modify, Delete, Rename), and supports rename detection with similarity scoring.

    .PARAMETER BaseBranch
        (Optional) The name of the base branch to compare from. 
        Defaults to the remote HEAD (e.g., 'main' or 'master').

    .PARAMETER FeatureBranch
        (Optional) The name of the feature or current working branch to compare against the base.
        Defaults to the currently checked-out branch.

    .EXAMPLE
        Get-PSUGitFileChangeMetadata
        Returns metadata comparing the current branch with the default remote HEAD branch (e.g., 'origin/main').

    .EXAMPLE
        Get-PSUGitFileChangeMetadata -BaseBranch 'main' -FeatureBranch 'feature/api-refactor'
        Compares changes between 'main' and 'feature/api-refactor' and returns structured change information.

    .EXAMPLE
        $changes = Get-PSUGitFileChangeMetadata
        $changes | Where-Object TypeOfChange -eq 'Rename'

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2025-07-27
    #>

    [CmdletBinding()]
    param (
        [string]$BaseBranch = $(git symbolic-ref refs/remotes/origin/HEAD | Split-Path -Leaf),
        [string]$FeatureBranch = $(git branch --show-current)
    )

    git diff --name-status $BaseBranch $FeatureBranch | ForEach-Object {
        $parts = $_ -split "`t"
        $status = $parts[0]

        if ($status -match "^R(\d{3})") {
            $similarity = [int]$matches[1]
            $OldFile = (($($parts[1])) -split('/'))[-1]
            $NewFile = (($($parts[2])) -split('/'))[-1]
            [PSCustomObject]@{
                File         = $($parts[2])
                TypeOfChange = "Rename"
                Comment      = "Renamed from '$OldFile' to '$NewFile' with $similarity % similarity in new file"
            }
            
            <# else {
                return @(
                    [PSCustomObject]@{
                        File         = $parts[1]
                        TypeOfChange = "Delete"
                    },
                    [PSCustomObject]@{
                        File         = $parts[2]
                        TypeOfChange = "New"
                    }
                )
            } 
            #>
        }
        else {
            $typeOfChange = switch ($status) {
                "A" { "New" }
                "M" { "Modify" }
                "D" { "Delete" }
                default { $status }
            }

            [PSCustomObject]@{
                File         = $parts[-1]
                TypeOfChange = $typeOfChange
                Comment      = $null
            }
        }
    }
}