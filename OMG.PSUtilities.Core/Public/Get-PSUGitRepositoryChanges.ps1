function Get-PSUGitRepositoryChanges {
<#
.SYNOPSIS
    Shows the specific modifications, additions, and deletions made in your Git working directory since the last commit.

.DESCRIPTION
    This function gives you a super clear report for every change it finds.
    For each change, it tells you the name of the file or folder.
    It also says what kind of item it is (like a file, a folder, or if it's been removed).
    Then, it explains how it changed – was it modified, added, deleted, or renamed?
    Finally, it gives you the full location of that item, making everything easy to understand.

    It is especially useful for automated module building, tagging, changelogs, and version control workflows.

.PARAMETER RootPath
    The root path of your Git repository. If not specified, it defaults to the current directory.

.OUTPUTS
    [PSCustomObject]

.EXAMPLE
    Get-PSUGitRepositoryChanges -RootPath "C:\repos\OMG.PSUtilities"
    [PSCustomObject] containing:
        - Name       : Name of the file or folder
        - ItemType   : File, Folder, Removed, or Unknown
        - ChangeType : Type of change detected (Modified, Added, Deleted, Renamed, New, etc.)
        - Path       : Full path to the changed item

.NOTES
    Author: Lakshmanachari Panuganti
    Date  : 2025-07-16
#>

    [CmdletBinding()]
    param (
        [string]$RootPath = (Get-Location).Path
    )

    Push-Location $RootPath
    try {
        $gitOutput = git status --porcelain

        $changedItems = foreach ($line in $gitOutput) {
            $line = $line.Trim()

            $changeCode = $line.Split(' ')[0].Trim()
            $path       = $line.Split(' ', 2)[1].Trim() -replace '"'
            $fullPath   = Join-Path -Path $RootPath -ChildPath $path

            $itemInfo = Get-Item $fullPath -ErrorAction SilentlyContinue

            $itemType = if ($changeCode -eq 'D' -or -not $itemInfo) {
                'File/Folder'
            }
            elseif ($itemInfo -is [System.IO.DirectoryInfo]) {
                'Folder'
            }
            elseif ($itemInfo -is [System.IO.FileInfo]) {
                'File'
            }
            else {
                'Unknown'
            }

            [pscustomobject]@{
                Name       = Split-Path $path -Leaf
                ItemType   = $itemType
                ChangeType = switch ($changeCode) {
                    'M'  { 'Modified' }
                    'A'  { 'Added' }
                    'D'  { 'Deleted' }
                    'R'  { 'Renamed' }
                    'C'  { 'Copied ' }
                    'U'  { 'Unmerged' }
                    '??' { 'New' }
                    default { "Other: $changeCode" }
                }
                Path       = $fullPath
            }
        }

        return $changedItems
    }
    Catch {
        Pop-Location
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
