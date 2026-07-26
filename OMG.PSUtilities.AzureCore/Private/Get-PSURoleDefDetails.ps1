<#
.SYNOPSIS
    Retrieves details of an Azure role definition by ID or name.

.DESCRIPTION
    Attempts to fetch an Azure role definition by ID first, then falls back to name
    lookup. Returns a normalized PSCustomObject with key role definition properties.
    Returns $null if the role definition cannot be found.

.PARAMETER RoleDefId
    The ID of the role definition to retrieve.

.PARAMETER RoleDefName
    The name of the role definition to retrieve (used as fallback if ID lookup fails).

.OUTPUTS
    [PSCustomObject] with Name, Id, Description, Actions, NotActions, DataActions,
    NotDataActions, and AssignableScopes properties. Returns $null if not found.

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 11th August 2025
    Last Modified: 7th March 2026
    Version: 1.0
#>
function Get-PSURoleDefDetails {
    param([string] $RoleDefId, [string] $RoleDefName)
    try {
        $rd = Get-AzRoleDefinition -Id $RoleDefId -ErrorAction Stop
    } catch {
        try {
            $rd = Get-AzRoleDefinition -Name $RoleDefName -ErrorAction SilentlyContinue
        } catch {
            $rd = $null
        }
    }
    if (-not $rd) { return $null }
    return [PSCustomObject]@{
        Name             = $rd.RoleName
        Id               = $rd.Id
        Description      = $rd.Description
        Actions          = ($rd.Actions -join ';')
        NotActions       = ($rd.NotActions -join ';')
        DataActions      = ($rd.DataActions -join ';')
        NotDataActions   = ($rd.NotDataActions -join ';')
        AssignableScopes = $rd.AssignableScopes
    }
}
