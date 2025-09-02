param(
    [string]$SubscriptionNameFilter = "*",
    [string]$ResourceTypeFilter,
    [string]$ResourceGroupFilter,
    [ValidateSet("User", "Group", "ServicePrincipal", "Unknown")]
    [string]$RoleAssignedToTypeFilter
)

# Get filtered, enabled subscriptions
$subscriptionList = Get-AzSubscription |
    Where-Object { $_.State -eq 'Enabled' -and $_.Name -ilike $SubscriptionNameFilter }

if (-not $subscriptionList) {
    Write-Warning "No matching subscriptions found for filter: '$SubscriptionNameFilter'"
    return
}

# Use fast .NET list for performance
$result = New-Object System.Collections.Generic.List[Object]

$totalSubscriptions = $subscriptionList.Count
$subIndex = 0

foreach ($subscription in $subscriptionList) {
    $subIndex++
    Write-Progress -Id 0 -Activity "Processing Subscriptions" `
        -Status "[$subIndex of $totalSubscriptions] $($subscription.Name)" `
        -PercentComplete (($subIndex / $totalSubscriptions) * 100)

    Set-AzContext -SubscriptionObject $subscription | Out-Null

    # Pull all role assignments in subscription ONCE
    $roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$($subscription.Id)"

    # Get resources (apply early filters)
    $azResourceList = Get-AzResource

    if ($ResourceTypeFilter) {
        $azResourceList = $azResourceList | Where-Object { $_.ResourceType -eq $ResourceTypeFilter }
    }
    if ($ResourceGroupFilter) {
        $azResourceList = $azResourceList | Where-Object { $_.ResourceGroupName -eq $ResourceGroupFilter }
    }

    $totalResources = $azResourceList.Count
    $resIndex = 0

    foreach ($azResource in $azResourceList) {
        $resIndex++
        Write-Progress -Id 1 -ParentId 0 -Activity "Resources in $($subscription.Name)" `
            -Status "[$resIndex of $totalResources] $($azResource.Name)" `
            -PercentComplete (($resIndex / [math]::Max($totalResources, 1)) * 100)

        $resourceId = $azResource.ResourceId

        # Match only role assignments scoped to this resource
        $matchingAssignments = $roleAssignments | Where-Object { $_.Scope -eq $resourceId }

        $totalAssignments = $matchingAssignments.Count
        $assignIndex = 0

        foreach ($roleAssignment in $matchingAssignments) {
            $assignIndex++
            Write-Progress -Id 2 -ParentId 1 -Activity "Role Assignments for $($azResource.Name)" `
                -Status "[$assignIndex of $totalAssignments] $($roleAssignment.DisplayName)" `
                -PercentComplete (($assignIndex / [math]::Max($totalAssignments, 1)) * 100)

            if ($RoleAssignedToTypeFilter -and $roleAssignment.ObjectType -ne $RoleAssignedToTypeFilter) {
                continue
            }

            $result.Add([PSCustomObject]@{
                ResourceName          = $azResource.Name
                ResourceType          = $azResource.ResourceType
                ResourceGroup         = $azResource.ResourceGroupName
                ResourceLocation      = $azResource.Location
                ResourceSubscription  = $subscription.Name
                RoleAssignedTo        = $roleAssignment.DisplayName
                RoleAssignedToId      = $roleAssignment.ObjectId 
                RoleAssignedToType    = $roleAssignment.ObjectType
                RoleAssignmentId      = $roleAssignment.RoleAssignmentName
                RoleDefinitionName    = $roleAssignment.RoleDefinitionName
                Scope                 = $roleAssignment.Scope
            })
        }

        Write-Progress -Id 2 -Activity "Role Assignments" -Completed
    }

    # Now also get assignments that are at the **subscription or RG level**, not tied to a specific resource
    $nonResourceAssignments = $roleAssignments | Where-Object {
        ($_ -notmatch "/providers/") -or ($_ -match "/resourceGroups/[^/]+$")  # subscription or RG level
    }

    foreach ($roleAssignment in $nonResourceAssignments) {
        if ($RoleAssignedToTypeFilter -and $roleAssignment.ObjectType -ne $RoleAssignedToTypeFilter) {
            continue
        }

        $scope = $roleAssignment.Scope
        $resourceGroup = if ($scope -match "/resourceGroups/([^/]+)") { $matches[1] } else { $null }
        if ($ResourceGroupFilter -and $resourceGroup -ne $ResourceGroupFilter) {
            continue
        }

        $result.Add([PSCustomObject]@{
            ResourceName          = "(scope-level)"
            ResourceType          = "(none)"
            ResourceGroup         = $resourceGroup
            ResourceLocation      = "(n/a)"
            ResourceSubscription  = $subscription.Name
            RoleAssignedTo        = $roleAssignment.DisplayName
            RoleAssignedToId      = $roleAssignment.ObjectId 
            RoleAssignedToType    = $roleAssignment.ObjectType
            RoleAssignmentId      = $roleAssignment.RoleAssignmentName
            RoleDefinitionName    = $roleAssignment.RoleDefinitionName
            Scope                 = $roleAssignment.Scope
        })
    }

    Write-Progress -Id 1 -Activity "Resources" -Completed
}

Write-Progress -Id 0 -Activity "Processing Subscriptions" -Completed

# Output sorted result
return $result | Sort-Object ResourceName
