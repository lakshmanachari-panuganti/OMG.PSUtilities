<#
.SYNOPSIS
    Retrieves all transitive group memberships for a given Azure AD user.

.DESCRIPTION
    Queries Microsoft Graph for all transitive group memberships of a user using
    Get-MgUserTransitiveMemberOf, with a fallback to Get-MgUserMemberOf. Returns
    a list of group objects with Id and DisplayName. Requires Connect-MgGraph.

.PARAMETER UserId
    The Object ID of the user whose transitive group memberships to retrieve.

.OUTPUTS
    [System.Object[]] Array of PSCustomObjects with Id and DisplayName properties.

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 11th August 2025
    Last Modified: 7th March 2026
    Version: 1.0
#>
function Get-PSUTransitiveGroups {
    param([string] $UserId)
    $results = @()
    try {
        $trans = Get-MgUserTransitiveMemberOf -UserId $UserId -All -ErrorAction Stop
    } catch {
        Write-Verbose "Get-MgUserTransitiveMemberOf failed; falling back to Get-MgUserMemberOf."
        try {
            $trans = Get-MgUserMemberOf -UserId $UserId -All -ErrorAction Stop
        } catch {
            $trans = @()
        }
    }

    foreach ($item in $trans) {
        $id = $item.Id
        if (-not $id) { continue }
        $odata = $null
        if ($item.PSObject.Properties.Match('@odata.type')) {
            $odata = $item.'@odata.type'
        } elseif ($item.AdditionalProperties -and $item.AdditionalProperties.'@odata.type') {
            $odata = $item.AdditionalProperties.'@odata.type'
        }
        $display = $null
        if ($item.PSObject.Properties.Match('displayName')) {
            $display = $item.displayName
        } elseif ($item.AdditionalProperties -and $item.AdditionalProperties.displayName) {
            $display = $item.AdditionalProperties.displayName
        }
        if ($odata -and $odata -like '*group*') {
            $results += [PSCustomObject]@{ Id = $id; DisplayName = $display }
            continue
        }
        try {
            $g = Get-MgGroup -GroupId $id -Property id,displayName -ErrorAction Stop
            if ($g) {
                $results += [PSCustomObject]@{ Id = $g.Id; DisplayName = $g.DisplayName }
                continue
            }
        } catch { }
        if ($item.GetType().Name -match 'Group') {
            $results += [PSCustomObject]@{ Id = $id; DisplayName = $display }
            continue
        }
    }
    return $results
}
