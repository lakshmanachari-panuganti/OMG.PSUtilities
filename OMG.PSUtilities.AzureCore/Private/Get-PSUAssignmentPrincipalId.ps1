<#
.SYNOPSIS
    Resolves the principal ID and type from an Azure role assignment object.

.DESCRIPTION
    Extracts PrincipalId, PrincipalType, and AssignmentId from a role assignment,
    with fallback logic for assignments that use ObjectId instead of PrincipalId.
    Issues a warning if neither PrincipalId nor ObjectId is present.

.PARAMETER Assignment
    The Azure role assignment object returned by Get-AzRoleAssignment.

.OUTPUTS
    [PSCustomObject] with PrincipalId, PrincipalType, and AssignmentId properties.

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 11th August 2025
    Last Modified: 7th March 2026
    Version: 1.0
#>
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
