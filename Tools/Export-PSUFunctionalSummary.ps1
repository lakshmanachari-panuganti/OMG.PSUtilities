function Export-PSUFunctionalSummary {
    <#
.SYNOPSIS
    Generates a functional test summary JSON file for an OMG.PSUtilities.AzureDevOps test run.

.DESCRIPTION
    This helper consolidates captured runtime artifacts (work item IDs, PR Id, variable group data,
    feature branch, etc.) from an in-memory hashtable (default: $PSUFuncTest) into a persisted JSON
    summary file. It can optionally attempt to recover missing fields (PullRequestId, VariableGroupId,
    VariableGroupName) by querying Azure DevOps if they were not previously populated.

    Intended for use at the end of a functional validation session described in
    COPILOT-INSTRUCTIONS-FUNCTIONALITY-TEST.MD.

.PARAMETER OutputPath
    Destination file path for the JSON summary. If only a directory is supplied, a filename will be generated.

.PARAMETER Project
    Azure DevOps project name (used for recovery of PR and variable groups if missing).

.PARAMETER Repository
    Azure DevOps repository name (used for PR recovery if missing).

.PARAMETER SummaryTable
    Hashtable (Ordered recommended) storing previously captured values. Default: $PSUFuncTest (if present).

.PARAMETER AttemptRecovery
    When set, will attempt to discover missing PullRequestId and VariableGroupName/Id.

.PARAMETER Force
    Overwrite existing OutputPath if it already exists.

.EXAMPLE
    Export-PSUFunctionalSummary -Project 'OMG.PSUtilities' -Repository 'Test-Repo1' -OutputPath .\FunctionalRun-Summary.json -AttemptRecovery

    Creates (or overwrites) FunctionalRun-Summary.json with recovered and captured values.

.OUTPUTS
    PSCustomObject (also written to disk as JSON)

.NOTES
    Author: Automation Assistant
    Created: 2025-10-15
    Version: 1.0
    .NOTES
        Author: Automation Assistant
        Created: 2025-10-15
        Version: 1.0
    #>
    [CmdletBinding()] param(
        [Parameter()] [string]$OutputPath = '.',
        [Parameter(Mandatory)] [string]$Project,
        [Parameter(Mandatory)] [string]$Repository,
        [Parameter()] [hashtable]$SummaryTable,
        [Parameter()] [switch]$AttemptRecovery,
        [Parameter()] [switch]$Force
    )

    begin {
        if(-not $SummaryTable){
            if (Get-Variable -Name PSUFuncTest -Scope Global -ErrorAction SilentlyContinue){
                $SummaryTable = $Global:PSUFuncTest
            } else {
                $SummaryTable = [ordered]@{}
            }
        }

        $org = $env:ORGANIZATION
        if (-not $org) { throw "Environment variable ORGANIZATION not set." }
        $timestamp = if ($SummaryTable.Timestamp) { $SummaryTable.Timestamp } else { (Get-Date -Format 'yyyyMMdd-HHmmss') }
    }
    process {
        # Recovery logic
        if ($AttemptRecovery) {
            try {
                if (-not $SummaryTable.PullRequestId) {
                    $pr = Get-PSUADOPullRequest -Project $Project -RepositoryName $Repository -State Completed |
                        Sort-Object CreationDate -Descending | Select-Object -First 1
                    if ($pr) { $SummaryTable.PullRequestId = $pr.Id }
                }
            } catch { Write-Verbose "PR recovery failed: $($_.Exception.Message)" }

            try {
                if (-not $SummaryTable.VariableGroupId -or -not $SummaryTable.VariableGroupName) {
                    $vgList = Get-PSUADOVariableGroupInventory -Organization $org -Verbose:$false 2>$null
                    if ($vgList) {
                        $match = $vgList | Where-Object VariableGroupName -like 'PSU-Test-VG-*' | Sort-Object VariableGroupId -Descending | Select-Object -First 1
                        if ($match) {
                            $SummaryTable.VariableGroupId   = $match.VariableGroupId
                            $SummaryTable.VariableGroupName = $match.VariableGroupName
                        }
                    }
                }
            } catch { Write-Verbose "Variable group recovery failed: $($_.Exception.Message)" }
        }

        # Build summary object
        $summary = [pscustomobject]@{
            Timestamp         = (Get-Date)
            Organization      = $org
            Project           = $Project
            Repository        = $Repository
            FeatureBranch     = $SummaryTable.FeatureBranch
            PullRequestId     = $SummaryTable.PullRequestId
            PRStatus          = $SummaryTable.PRStatus ?? 'completed'
            MergeStrategy     = $SummaryTable.MergeStrategy ?? 'squash'
            UserStoryId       = $SummaryTable.UserStoryId
            BugId             = $SummaryTable.BugId
            TaskId            = $SummaryTable.TaskId
            SpikeId           = $SummaryTable.SpikeId
            VariableGroupId   = $SummaryTable.VariableGroupId
            VariableGroupName = $SummaryTable.VariableGroupName
            VariableName      = $SummaryTable.VariableName
            CloneValidated    = $SummaryTable.CloneValidated
        }

        # Resolve output path
        $isDirTarget = Test-Path -Path $OutputPath -PathType Container
        if ($isDirTarget) {
            $fileName = "FunctionalRun-Summary-$timestamp.json"
            $OutputPath = Join-Path $OutputPath $fileName
        } elseif ([IO.Path]::GetExtension($OutputPath) -eq '') {
            # Provided path without extension - treat as directory (create) then append filename
            if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }
            $fileName = "FunctionalRun-Summary-$timestamp.json"
            $OutputPath = Join-Path $OutputPath $fileName
        } else {
            # Has extension - ensure directory exists
            $parent = Split-Path -Parent $OutputPath
            if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
        }

        if (Test-Path $OutputPath -PathType Leaf -and -not $Force) {
            throw "Output file already exists: $OutputPath (use -Force to overwrite)."
        }

        $summary | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding utf8
        Write-Host "Functional summary written: $OutputPath" -ForegroundColor Cyan
        return $summary
    }
}
# End of Export-PSUFunctionalSummary.ps1