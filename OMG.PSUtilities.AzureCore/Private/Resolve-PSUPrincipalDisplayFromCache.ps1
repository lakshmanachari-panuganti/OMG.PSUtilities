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
