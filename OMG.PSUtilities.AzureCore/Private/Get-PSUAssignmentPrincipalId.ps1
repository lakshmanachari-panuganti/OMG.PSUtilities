function Get-PSUAssignmentPrincipalId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Assignment
    )

    # Try normal path first
    $principalId   = $Assignment.PrincipalId
    $principalType = $Assignment.PrincipalType
    $assignmentId  = if ($Assignment.Id) { $Assignment.Id } else { $Assignment.RoleAssignmentName }

    # Fallback if PrincipalId is missing
    if (-not $principalId -and $Assignment.ObjectId) {
        $principalId   = $Assignment.ObjectId
        if (-not $principalType -and $Assignment.ObjectType) {
            $principalType = $Assignment.ObjectType
        }
    }

    # If still blank, mark explicitly
    if (-not $principalId) {
        Write-Warning "Assignment [$assignmentId] has no PrincipalId or ObjectId."
    }

    [PSCustomObject]@{
        PrincipalId   = $principalId
        PrincipalType = $principalType
        AssignmentId  = $assignmentId
    }
}
