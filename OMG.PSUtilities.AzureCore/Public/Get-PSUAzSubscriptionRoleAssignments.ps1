function Get-PSUAzSubscriptionRoleAssignments {
    <#
    .SYNOPSIS
        Gets Azure role assignments for a subscription, with optional filtering.

    .DESCRIPTION
        Retrieves Azure role assignments scoped under a subscription. Supports filtering by resource group, role name, assignee type, and resource type. Useful for RBAC audits and reporting.

    .PARAMETER SubscriptionName
        (Optional) The name (or wildcard pattern) of the subscription to target. Default: '*Enterprise Non-Prod*'.

    .PARAMETER ResourceGroup
        (Optional) Filter results to a specific resource group name.

    .PARAMETER Role
        (Optional) Filter results to a specific role name.

    .PARAMETER AssignedToType
        (Optional) Filter by assignee type: User, Group, ServicePrincipal, or Unknown.

    .PARAMETER ResourceType
        (Optional) Filter by Azure resource type (e.g. 'Microsoft.Compute/virtualMachines').

    .EXAMPLE
        Connect-AzAccount -UseDeviceAuthentication # requires a successfull connection with Azure
        Get-PSUAzSubscriptionRoleAssignments -SubscriptionName '*Non-Prod*'

    .EXAMPLE
        Connect-AzAccount -UseDeviceAuthentication # requires a successfull connection with Azure
        Get-PSUAzSubscriptionRoleAssignments -ResourceGroup 'MyResourceGroup' -Role 'Reader' -AssignedToType 'User'

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 30th August 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureCore
        https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-list
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionName = 'Entropy',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroup,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Role,

        [Parameter()]
        #[ValidateSet('User', 'Group', 'ServicePrincipal')]
        [string]$AssignedToType,

        [Parameter()]
        [string]$ResourceType
    )

    try {
        $results = @()
        # Set subscription context
        $subscriptions = Get-AzSubscription | Where-Object {
            $_.State -eq 'Enabled' -and
            $_.Name -like $SubscriptionName
        }

        if (-not $subscriptions) {
            throw "No subscription found matching '$SubscriptionName'."
        }

        foreach ($subscription in $subscriptions) {
            Set-AzContext -SubscriptionObject $subscription | Out-Null
            Write-Host "Processing the subscription: $($subscription.Name) [$($subscription.Id)]"

            # Cache all role definitions
            $roleDefinitions = Get-AzRoleDefinition

            # Get filtered role assignments (filter early)
            $roleAssignments = Get-AzRoleAssignment
            foreach ($assignment in $roleAssignments) {
                $roleDefinition = $roleDefinitions | Where-Object { $_.Id -eq $assignment.RoleDefinitionId }

                $scopes = @($assignment.Scope)

                foreach ($scope in $scopes) {
                    $resourceName = ($scope -split "/")[-1]
                    $rg = if ($scope -match "/resourceGroups/([^/]+)") { $matches[1] } else { $null }
                    $resourceType = if ($scope -match "/providers/([^/]+/[^/]+)") { $matches[1] } else { $null }
                    $assignedToType = $assignment.ObjectType
                    $assignedTo = $assignment.SignInName ?? $assignment.DisplayName ?? $assignment.ObjectId ?? $null

                    $results += [PSCustomObject]@{
                        ResourceName   = $resourceName
                        ResourceGroup  = $rg
                        ResourceType   = $resourceType
                        AssignedTo     = $assignedTo
                        AssignedToType = $assignedToType
                        Role           = $roleDefinition.Name
                        Subscription   = $subscription.Name
                        PSTypeName     = 'PSU.Az.RoleAssignment'
                    }
                }
            }
        }
        # Apply  all the filters
        if ($ResourceGroup) { $results = $results | Where-Object { $_.ResourceGroup -eq $ResourceGroup } }
        if ($Role) { $results = $results | Where-Object { $_.Role -eq $Role } }
        if ($AssignedToType) { $results = $results | Where-Object { $_.AssignedToType -eq $AssignedToType } }
        if ($ResourceType) { $results = $results | Where-Object { $_.ResourceType -eq $ResourceType } }

        return $results | Sort-Object ResourceName
    }

    catch { 
        $PSCmdlet.ThrowTerminatingError($_)
    }
}