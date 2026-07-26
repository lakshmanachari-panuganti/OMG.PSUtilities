<#
.SYNOPSIS
    Parses an Azure resource scope path into its component parts.

.DESCRIPTION
    Breaks down an Azure scope path (e.g. /subscriptions/{id}/resourceGroups/{rg}/...)
    into structured properties: SubscriptionId, ResourceGroup, ResourceType,
    ResourceName, and ScopeLevel. Returns a PSCustomObject with these fields.

.PARAMETER Scope
    The Azure scope path string to parse.
    Example: "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myRG"

.OUTPUTS
    [PSCustomObject] with Scope, SubscriptionId, ResourceGroup, ResourceType,
    ResourceName, and ScopeLevel properties.

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 11th August 2025
    Last Modified: 7th March 2026
    Version: 1.0
    Note: "Parse" is used here as the function is private. Consider
          ConvertFrom-PSUScopePath if this is ever promoted to public.
#>
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
