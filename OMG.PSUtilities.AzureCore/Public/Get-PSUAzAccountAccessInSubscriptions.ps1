function Get-PSUAzAccountAccessInSubscriptions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]  [string]   $UserPrincipalName,
        [Parameter(Mandatory = $false)] [string]   $OutputCsv           = "C:\Temp\account-access-by-subscription.csv",
        [Parameter(Mandatory = $false)] [switch]   $OutputJson,
        [Parameter(Mandatory = $false)] [int]      $JsonDepth           = 6,
        [Parameter(Mandatory = $false)] [string[]] $SubscriptionFilter  = @('*Non-Prod*')
    )

    # 1) Graph lookups
    $me      = Get-PSUGraphUser -Upn $UserPrincipalName
    $groups  = Get-PSUTransitiveGroups -UserId $me.Id
    $principalIdsToCheck = @($me.Id) + ($groups | Select-Object -ExpandProperty Id -ErrorAction SilentlyContinue | Where-Object { $_ })

    # 2) Subscriptions filter
    $subs     = Get-AzSubscription
    $patterns = if ($SubscriptionFilter -and $SubscriptionFilter.Count -gt 0) { $SubscriptionFilter } else { @('*') }
    $filteredSubs = $subs | Where-Object {
        foreach ($p in $patterns) {
            if ($null -ne $p -and $p -ne '' -and ($_.Name -like $p -or $_.Id -like $p)) { return $true }
        }
        return $false
    }
    if (-not $filteredSubs -or $filteredSubs.Count -eq 0) {
        Write-Warning "No subscriptions matched filter"
        return @()
    }

    # 3) Collect assignments & normalize principal IDs
    $assignmentsBySub    = @{}
    $unknownPrincipalIds = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($s in $filteredSubs) {
        $subScope = "/subscriptions/$($s.Id)"
        try {
            $assigns = Get-AzRoleAssignment -Scope $subScope -ErrorAction Stop
        } catch {
            Write-Host "Get-AzRoleAssignment failed for $($s.Id): $_"
            $assigns = @()
        }

        foreach ($a in $assigns) {
            # Try helper first
            $norm = Get-PSUAssignmentPrincipalId -Assignment $a

            # Fallback if PrincipalId missing but ObjectId exists
            if (-not $norm.PrincipalId -and $a.ObjectId) {
                $norm = [PSCustomObject]@{
                    PrincipalId   = $a.ObjectId
                    PrincipalType = $a.ObjectType
                    AssignmentId  = if ($a.Id) { $a.Id } else { $a.RoleAssignmentName }
                }
            }

            # Add normalized props to $a
            $a | Add-Member -NotePropertyName PSU_PrincipalId   -NotePropertyValue $norm.PrincipalId   -Force
            $a | Add-Member -NotePropertyName PSU_PrincipalType -NotePropertyValue $norm.PrincipalType -Force
            $a | Add-Member -NotePropertyName PSU_AssignmentId  -NotePropertyValue $norm.AssignmentId  -Force
        }

        $matched = $assigns | Where-Object { $_.PSU_PrincipalId -and $principalIdsToCheck -contains $_.PSU_PrincipalId }
        $assignmentsBySub[$s.Id] = $matched

        foreach ($a in $matched) {
            $PSU_PrincipalId = $a.PSU_PrincipalId
            if ($PSU_PrincipalId -and $PSU_PrincipalId -ne $me.Id -and -not ($groups | Where-Object { $_.Id -eq $PSU_PrincipalId })) {
                $null = $unknownPrincipalIds.Add($PSU_PrincipalId)
            }
        }
    }

    # 4) Resolve principals
    $resolvedCache = @{}
    $resolvedCache[$me.Id] = @{ DisplayName = $me.DisplayName; Type = 'User' }
    foreach ($g in $groups) {
        if ($g.Id) {
            $resolvedCache[$g.Id] = @{ DisplayName = $g.DisplayName; Type = 'Group' }
        }
    }

    if ($unknownPrincipalIds.Count -gt 0) {
        $objs = Get-PSUBatchDirectoryObjects -Ids $unknownPrincipalIds
        foreach ($o in $objs) {
            $odata   = $o.'@odata.type' -or ($o.AdditionalProperties.'@odata.type' -as [string])
            $display = $o.displayName -or $o.AdditionalProperties.displayName -or $o.userPrincipalName -or $o.mail
            $type    = if ($odata -like '*group*') { 'Group' }
                       elseif ($odata -like '*user*') { 'User' }
                       else { 'DirectoryObject' }
            $resolvedCache[$o.id] = @{ DisplayName = $display; Type = $type }
        }
    }

    # 5) Build output
    $rows = foreach ($s in $filteredSubs) {
        $matchedAssignments = $assignmentsBySub[$s.Id] | ForEach-Object {
            $roleDef = Get-AzRoleDefinition -Id $_.RoleDefinitionId -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                PrincipalId          = $_.PSU_PrincipalId
                PrincipalDisplayName = $resolvedCache[$_.PSU_PrincipalId].DisplayName
                PrincipalType        = $resolvedCache[$_.PSU_PrincipalId].Type
                RoleDefinitionName   = $_.RoleDefinitionName
                RoleDefinitionId     = $_.RoleDefinitionId
                RoleDefinition       = $roleDef
                Scope                = $_.Scope
                ScopeLevel           = if ($_.Scope -match '^/subscriptions/[^/]+$') { 'Subscription' }
                                        elseif ($_.Scope -match '^/subscriptions/[^/]+/resourceGroups/[^/]+$') { 'ResourceGroup' }
                                        else { 'Resource' }
                ResourceGroup        = if ($_.Scope -match '/resourceGroups/([^/]+)') { $matches[1] } else { '' }
                ResourceType         = if ($_.Scope -match 'providers/([^/]+/[^/]+)$') { $matches[1] } else { '' }
                ResourceName         = if ($_.Scope -match 'providers/[^/]+/[^/]+/(.+)$') { $matches[1] } else { '' }
                AssignmentObjectId   = if ($_.PSU_AssignmentId) { $_.PSU_AssignmentId } 
                                        elseif ($_.RoleAssignmentId) { $_.RoleAssignmentId } 
                                        elseif ($_.Id) { $_.Id } 
                                        else { $null }

                Condition            = $_.Condition
                Description          = $_.Description
            }
        }

        [PSCustomObject]@{
            SubscriptionId            = $s.Id
            SubscriptionName          = $s.Name
            MatchedAssignmentsCount   = $matchedAssignments.Count
            MatchedAssignmentsJson    = ($matchedAssignments | ConvertTo-Json -Depth $JsonDepth -Compress)
        }
    }

    # 6) Export
    try {
        $rows | Select-Object SubscriptionId, SubscriptionName, MatchedAssignmentsCount, MatchedAssignmentsJson |
            Export-Csv -Path $OutputCsv -NoTypeInformation -Force -Encoding UTF8
    } catch {
        Write-Warning "Export CSV failed: $_"
    }

    if ($OutputJson) {
        $full = @{ GeneratedAt = (Get-Date).ToString("o"); User = $UserPrincipalName; Results = $rows }
        $jsonPath = [System.IO.Path]::ChangeExtension($OutputCsv, '.full.json')
        try {
            $full | ConvertTo-Json -Depth ($JsonDepth + 2) | Out-File -FilePath $jsonPath -Encoding UTF8
            Write-Output "JSON: $(Resolve-Path $jsonPath)"
        } catch {
            Write-Warning "Failed to write JSON: $_"
        }
    }

    return $rows
}
