function Parse-PSUScopePath {
    param([string] $Scope)
    $r = [PSCustomObject]@{
        Scope = $Scope
        SubscriptionId = $null
        ResourceGroup = $null
        ResourceType = $null
        ResourceName = $null
        ScopeLevel = 'Unknown'
    }
    if (-not $Scope) { return $r }
    $parts = $Scope -split '/' | Where-Object { $_ -ne '' }
    if ($parts.Count -ge 2 -and $parts[0] -eq 'subscriptions') {
        $r.SubscriptionId = $parts[1]
        if ($parts.Count -ge 4 -and $parts[2] -eq 'resourceGroups') {
            $r.ResourceGroup = $parts[3]; $r.ScopeLevel = 'ResourceGroupOrBelow'
            $pIndex = [Array]::IndexOf($parts,'providers')
            if ($pIndex -gt -1 -and $pIndex + 1 -lt $parts.Count) {
                $resourceSegments = $parts[($pIndex+1)..($parts.Count - 1)]
                $r.ResourceType = ($resourceSegments -join '/')
                $r.ResourceName = $resourceSegments[-1]
            }
        } else { $r.ScopeLevel = 'Subscription' }
    }
    return $r
}
