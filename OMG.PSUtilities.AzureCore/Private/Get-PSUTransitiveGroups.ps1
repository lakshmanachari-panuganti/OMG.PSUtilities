function Get-PSUTransitiveGroups {
    param([string] $UserId)
    $results = @()
    try { $trans = Get-MgUserTransitiveMemberOf -UserId $UserId -All -ErrorAction Stop }
    catch {
        Write-Verbose "Get-MgUserTransitiveMemberOf failed; falling back to Get-MgUserMemberOf."
        try { $trans = Get-MgUserMemberOf -UserId $UserId -All -ErrorAction Stop } catch { $trans = @() }
    }

    foreach ($item in $trans) {
        $id = $item.Id
        if (-not $id) { continue }
        $odata = $null
        if ($item.PSObject.Properties.Match('@odata.type')) { $odata = $item.'@odata.type' }
        elseif ($item.AdditionalProperties -and $item.AdditionalProperties.'@odata.type') { $odata = $item.AdditionalProperties.'@odata.type' }
        $display = $null
        if ($item.PSObject.Properties.Match('displayName')) { $display = $item.displayName }
        elseif ($item.AdditionalProperties -and $item.AdditionalProperties.displayName) { $display = $item.AdditionalProperties.displayName }
        if ($odata -and $odata -like '*group*') { $results += [PSCustomObject]@{ Id=$id; DisplayName=$display }; continue }
        try {
            $g = Get-MgGroup -GroupId $id -Property id,displayName -ErrorAction Stop
            if ($g) { $results += [PSCustomObject]@{ Id=$g.Id; DisplayName=$g.DisplayName }; continue }
        } catch { }
        if ($item.GetType().Name -match 'Group') { $results += [PSCustomObject]@{ Id=$id; DisplayName=$display }; continue }
    }
    return $results
}
