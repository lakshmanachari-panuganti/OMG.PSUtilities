function Get-PSURoleDefDetails {
    param([string] $RoleDefId, [string] $RoleDefName)
    try { $rd = Get-AzRoleDefinition -Id $RoleDefId -ErrorAction Stop } catch { try { $rd = Get-AzRoleDefinition -Name $RoleDefName -ErrorAction SilentlyContinue } catch { $rd = $null } }
    if (-not $rd) { return $null }
    return [PSCustomObject]@{
        Name = $rd.RoleName; Id = $rd.Id; Description = $rd.Description;
        Actions = ($rd.Actions -join ';'); NotActions = ($rd.NotActions -join ';');
        DataActions = ($rd.DataActions -join ';'); NotDataActions = ($rd.NotDataActions -join ';');
        AssignableScopes = $rd.AssignableScopes
    }
}
