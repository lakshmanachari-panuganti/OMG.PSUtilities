<#
.SYNOPSIS
    Resolves the display name and type of a principal using in-memory cache and known objects.

.DESCRIPTION
    Given a principal ID, checks the known user object, group objects, and a cache hashtable
    to resolve the principal's display name and type (User, Group, or Unknown).
    This avoids repeated API calls for the same principal during bulk role assignment processing.

.PARAMETER PrincipalId
    The Object ID of the principal to resolve.

.PARAMETER UserObj
    The resolved user object (from Get-PSUGraphUser) to compare against.

.PARAMETER GroupObjs
    Array of known group objects to check against.

.PARAMETER Cache
    Hashtable cache keyed by principal ID with DisplayName and Type entries.

.OUTPUTS
    [PSCustomObject] with PrincipalId, PrincipalType, and PrincipalDisplayName properties.

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 11th August 2025
    Last Modified: 7th March 2026
    Version: 1.0
#>
function Resolve-PSUPrincipalDisplayFromCache {
    param(
        [string] $PrincipalId,
        [object] $UserObj,
        [array] $GroupObjs,
        [hashtable] $Cache   # cache: id -> @{ DisplayName = '', Type = '' }
    )
    if ($PrincipalId -eq $UserObj.Id) {
        return [PSCustomObject]@{ PrincipalId = $PrincipalId; PrincipalType = 'User'; PrincipalDisplayName = $UserObj.DisplayName }
    }
    if ($GroupObjs) {
        $g = $GroupObjs | Where-Object { $_.Id -eq $PrincipalId }
        if ($g) { return [PSCustomObject]@{ PrincipalId = $PrincipalId; PrincipalType = 'Group'; PrincipalDisplayName = $g.DisplayName } }
    }
    if ($Cache.ContainsKey($PrincipalId)) {
        $entry = $Cache[$PrincipalId]
        return [PSCustomObject]@{ PrincipalId = $PrincipalId; PrincipalType = $entry.Type; PrincipalDisplayName = $entry.DisplayName }
    }
    # fallback unknown
    return [PSCustomObject]@{ PrincipalId = $PrincipalId; PrincipalType = 'Unknown'; PrincipalDisplayName = $null }
}
