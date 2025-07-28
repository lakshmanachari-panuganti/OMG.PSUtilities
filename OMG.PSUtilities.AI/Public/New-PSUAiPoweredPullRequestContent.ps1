function New-PSUAiPoweredPullRequestContent {
    <#
    .SYNOPSIS
    Generates a professional Pull Request (PR) title and description from AI-powered Git change summaries.

    .DESCRIPTION
    This function takes input from `Get-PSUAiPoweredGitChangeSummary` via pipeline and builds a clear and concise PR title and description suitable for developers and DevOps engineers. It groups changes by type and summarizes affected files.

    .PARAMETER ChangeSummaries
    An array or pipeline input of Git file change summaries, each with properties: File, TypeOfChange, Summary.

    .OUTPUTS
    [PSCustomObject] with 'Title' and 'Description' properties.

    .EXAMPLE
    Get-PSUAiPoweredGitChangeSummary | New-PSUAiPoweredPullRequestContent

    .NOTES
    Author: Lakshmanachari Panuganti
    Date  : 2025-07-28
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject[]] $ChangeSummaries
    )

    begin {
        $allChanges = @()
    }

    process {
        $allChanges += $ChangeSummaries
    }

    end {
        if (-not $allChanges) {
            Write-Warning "No change summaries received."
            return
        }

        $changeGroups = $allChanges | Group-Object TypeOfChange

        $titleSegment = ($changeGroups | ForEach-Object {
            "$($_.Name): $($_.Count)"
        }) -join ", "

        $title = "Feature Update: $titleSegment"

        $description = @()
        $description += "### Summary of Changes"
        foreach ($group in $changeGroups) {
            $description += "`n**$($group.Name)**:"
            foreach ($item in $group.Group) {
                $description += "- `$($item.File)`: $($item.Summary)"
            }
        }

        $filesModified = ($allChanges.File | Sort-Object -Unique)
        $fileListString = ($filesModified | ForEach-Object { "`"$($_)`"" }) -join ", "

        $description += "`n---"
        $description += "### Affected Files"
        $description += $fileListString

        [PSCustomObject]@{
            Title       = $title
            Description = ($description -join "`n")
        }
    }
}
