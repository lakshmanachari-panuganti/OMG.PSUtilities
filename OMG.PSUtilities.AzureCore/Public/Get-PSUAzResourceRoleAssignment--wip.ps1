param(
    [string]$SubscriptionNameFilter = "*",
    [string]$ResourceTypeFilter,
    [string]$ResourceGroupFilter,
    [ValidateSet("User", "Group", "ServicePrincipal", "Unknown")]
    [string]$RoleAssignedToTypeFilter
)

$subscriptionList = Get-AzSubscription |
    Where-Object { $_.State -eq 'Enabled' -and $_.Name -ilike $SubscriptionNameFilter }

if (-not $subscriptionList) {
    Write-Warning "No matching subscriptions found for filter: '$SubscriptionNameFilter'"
    return
}

$totalSubscriptions = $subscriptionList.Count
$subIndex = 0

foreach ($subscription in $subscriptionList) {
    $subIndex++
    $result = New-Object System.Collections.Generic.List[Object]
    $subProgressPercent = [math]::Round(($subIndex / $totalSubscriptions) * 100)

    Write-Progress -Activity "Processing Subscriptions" `
                   -Status "[$subIndex of $totalSubscriptions] $($subscription.Name)" `
                   -PercentComplete $subProgressPercent

    Set-AzContext -SubscriptionObject $subscription | Out-Null
    $azResourceList = Get-AzResource

    # Apply resource-level filters early
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
        $resProgressPercent = [math]::Round(($resIndex / [math]::Max($totalResources, 1)) * 100)

        Write-Progress -Id 1 -ParentId 0 `
                       -Activity "Processing Resources in $($subscription.Name)" `
                       -Status "[$resIndex of $totalResources] $($azResource.Name)" `
                       -PercentComplete $resProgressPercent

        $roleAssignments = Get-AzRoleAssignment -Scope $azResource.ResourceId 

        $totalAssignments = $roleAssignments.Count
        $assignIndex = 0

        foreach ($roleAssignment in $roleAssignments) {
            $assignIndex++
            $assignProgressPercent = [math]::Round(($assignIndex / [math]::Max($totalAssignments, 1)) * 100)

            Write-Progress -Id 2 -ParentId 1 `
                           -Activity "Role Assignments for $($azResource.Name)" `
                           -Status "[$assignIndex of $totalAssignments] $($roleAssignment.DisplayName)" `
                           -PercentComplete $assignProgressPercent

            # Apply RoleAssignedToType filter
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
            })
        }

        # Clear role assignment progress after each resource
        Write-Progress -Id 2 -Activity "Role Assignments" -Completed
    }

    [array]$result | Sort-Object ResourceGroup,ResourceType, ResourceName | Export-PSUExcel -ExcelPath C:\Temp\RoleAssignments.xlsx -WorksheetName $subscription.Name
    # Clear resource progress after each subscription
    Write-Progress -Id 1 -Activity "Resources" -Completed
}

# Clear subscription progress after all done
Write-Progress -Activity "Processing Subscriptions" -Completed