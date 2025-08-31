$subscriptionList = Get-AzSubscription |
    Where-Object { $_.State -eq 'Enabled' -and $_.Name -ilike "Ent*non-prod*" }

$result = New-Object System.Collections.Generic.List[Object]

$totalSubscriptions = $subscriptionList.Count
$subIndex = 0

foreach ($subscription in $subscriptionList) {
    $subIndex++
    $subProgressPercent = [math]::Round(($subIndex / $totalSubscriptions) * 100)

    Write-Progress -Activity "Processing Subscriptions" `
                   -Status "[$subIndex of $totalSubscriptions] $($subscription.Name)" `
                   -PercentComplete $subProgressPercent

    Set-AzContext -SubscriptionObject $subscription | Out-Null
    $azResourceList = Get-AzResource

    $totalResources = $azResourceList.Count
    $resIndex = 0

    foreach ($azResource in $azResourceList) {
        $resIndex++
        $resProgressPercent = [math]::Round(($resIndex / $totalResources) * 100)

        Write-Progress -Id 1 -ParentId 0 `
                       -Activity "   Processing Resources in $($subscription.Name)" `
                       -Status "[$resIndex of $totalResources] $($azResource.Name)" `
                       -PercentComplete $resProgressPercent

        $roleAssignments = Get-AzRoleAssignment -Scope $azResource.ResourceId

        foreach ($roleAssignment in $roleAssignments) {
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
    }

    # Clear inner progress bar after finishing a subscription
    Write-Progress -Id 1 -Activity "Processing Resources" -Completed
}

# Clear the outer progress bar after all subscriptions
Write-Progress -Activity "Processing Subscriptions" -Completed