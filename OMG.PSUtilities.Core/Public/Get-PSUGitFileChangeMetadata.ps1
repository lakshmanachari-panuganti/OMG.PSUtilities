function Get-PSUGitFileChangeMetadata {
    <#
    .SYNOPSIS
        Gets metadata about file changes between two Git branches.

    .DESCRIPTION
        Compares two Git branches using `git diff --name-status` and returns structured metadata.
        It includes file paths, type of change (New, Modify, Delete, Rename), and supports rename detection with similarity scoring.
        By default, untracked files are automatically staged using `git add .` and marked as "New".
        Use -ExcludeUntrackedFiles to prevent auto-staging and exclude untracked files from output.

    .PARAMETER BaseBranch
        (Optional) The name of the base branch to compare from.
        Defaults to the remote HEAD (e.g., 'main' or 'master').

    .PARAMETER FeatureBranch
        (Optional) The name of the feature or current working branch to compare against the base.
        Defaults to the currently checked-out branch.

    .PARAMETER ExcludeUntrackedFiles
        (Optional) When specified, prevents automatic staging of untracked files.
        Untracked files will appear in the output with TypeOfChange = "Untracked" without being staged.

    .EXAMPLE
        Get-PSUGitFileChangeMetadata
        Returns metadata comparing the current branch with the default remote HEAD branch (e.g., 'origin/main').

    .EXAMPLE
        Get-PSUGitFileChangeMetadata -BaseBranch 'main' -FeatureBranch 'feature/api-refactor'
        Compares changes between 'main' and 'feature/api-refactor' and returns structured change information.

    .EXAMPLE
        $changes = Get-PSUGitFileChangeMetadata
        $changes | Where-Object TypeOfChange -eq 'Rename'

    .EXAMPLE
        Get-PSUGitFileChangeMetadata -ExcludeUntrackedFiles
        Returns all changes without staging untracked files. Untracked files appear as TypeOfChange = "Untracked".

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 27th July 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>

    [CmdletBinding()]
    param (
        [string]$BaseBranch = $(git symbolic-ref refs/remotes/origin/HEAD | Split-Path -Leaf),
        [string]$FeatureBranch = $(git branch --show-current),
        [switch]$ExcludeUntrackedFiles
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

    # Get untracked files and stage them by default
    $untrackedFiles = git ls-files --others --exclude-standard
    if ($untrackedFiles) {
        if ($ExcludeUntrackedFiles) {
            $untrackedFiles | ForEach-Object {
                [PSCustomObject]@{
                    File         = $_
                    TypeOfChange = "Untracked"
                    Comment      = "New file not yet added to git"
                }
            }
        }
        else {
            Write-Verbose "Staging $(@($untrackedFiles).Count) untracked file(s)..."
            git add .

            $untrackedFiles | ForEach-Object {
                [PSCustomObject]@{
                    File         = $_
                    TypeOfChange = "New"
                    Comment      = "New file staged to git"
                }
            }
        }
    }
}