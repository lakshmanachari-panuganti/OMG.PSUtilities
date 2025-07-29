function Get-PSUGitFileChangeMetadata {
    <#
    .SYNOPSIS
    Gets metadata about file changes between two Git branches.

    .DESCRIPTION
    Compares two Git branches using `git diff --name-status` and returns structured metadata
    including the file path, type of change (New, Modify, Delete, Rename), and handles rename similarity.

    .PARAMETER BaseBranch
    The name of the base branch to compare from (e.g., 'main').

    .PARAMETER FeatureBranch
    The name of the feature or topic branch to compare against the base.

    .OUTPUTS
    [PSCustomObject] with properties: File (string), TypeOfChange (string)

    .NOTES
    Author: Lakshmanachari Panuganti
    Date: 2025-07-27
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$BaseBranch,

        [Parameter(Mandatory)]
        [string]$FeatureBranch
    )

    git diff --name-status $BaseBranch $FeatureBranch | ForEach-Object {
        $parts = $_ -split "`t"
        $status = $parts[0]

        if ($status -match "^R(\d{3})") {
            $similarity = [int]$matches[1]
            if ($similarity -ge 95) {
                [PSCustomObject]@{
                    File         = "$($parts[1]) → $($parts[2])"
                    TypeOfChange = "Rename"
                }
            } else {
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
        } else {
            $typeOfChange = switch ($status) {
                "A" { "New" }
                "M" { "Modify" }
                "D" { "Delete" }
                default { $status }
            }

            [PSCustomObject]@{
                File         = $parts[-1]
                TypeOfChange = $typeOfChange
            }
        }
    }
}