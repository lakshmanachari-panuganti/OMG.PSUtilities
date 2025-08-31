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
        Connect-AzAccount -UseDeviceAuthentication
        Get-PSUAzSubscriptionRoleAssignments -SubscriptionName '*Non-Prod*'

    .EXAMPLE
        Connect-AzAccount -UseDeviceAuthentication
        Get-PSUAzSubscriptionRoleAssignments -ResourceGroup 'MyResourceGroup' -Role 'Reader' -AssignedToType 'User'

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 30th August 2025
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionName = '*Enterprise Non-Prod*',

        [Parameter()]
        [string]$ResourceGroup,

        [Parameter()]
        [string]$Role,

        [Parameter()]
        [string]$AssignedToType,

        [Parameter()]
        [string]$ResourceType
    )

    try {
        $results = @()

        # Get target subscriptions
        $subscriptions = Get-AzSubscription | Where-Object {
            $_.State -eq 'Enabled' -and
            $_.Name -like $SubscriptionName
        }

        if (-not $subscriptions) {
            throw "No subscription found matching '$SubscriptionName'."
        }

        foreach ($subscription in $subscriptions) {
            Set-AzContext -SubscriptionObject $subscription | Out-Null
            Write-Host "Processing subscription: $($subscription.Name) [$($subscription.Id)]"

            $roleDefinitions = Get-AzRoleDefinition
            $roleAssignments = Get-AzRoleAssignment

            foreach ($assignment in $roleAssignments) {
                $roleDefinition = $roleDefinitions | Where-Object { $_.Id -eq $assignment.RoleDefinitionId }
                $scope = $assignment.Scope

                # Extract values from scope
                $resourceName = ($scope -split "/")[-1]
                $rg = if ($scope -match "/resourceGroups/([^/]+)") { $matches[1] } else { $null }

                # Improved resource type parsing
                if ($scope -match "/providers/([^/]+/[^/]+)") {
                    $parsedResourceType = $matches[1]
                }
                elseif ($scope -match "^/subscriptions/[^/]+$") {
                    $parsedResourceType = "Microsoft.Resources/subscriptions"
                }
                elseif ($scope -match "^/providers/Microsoft.Management/managementGroups/[^/]+$") {
                    $parsedResourceType = "Microsoft.Management/managementGroups"
                }
                else {
                    $parsedResourceType = "Unknown"
                }

                # AssignedTo fallback logic
                $assignedTo = $assignment.SignInName
                if (-not $assignedTo) { $assignedTo = $assignment.DisplayName }
                if (-not $assignedTo) { $assignedTo = $assignment.ObjectId }

                $results += [PSCustomObject]@{
                    ResourceName   = $resourceName
                    ResourceGroup  = $rg
                    ResourceType   = $parsedResourceType
                    AssignedTo     = $assignedTo
                    AssignedToType = $assignment.ObjectType
                    Role           = $roleDefinition.Name
                    Subscription   = $subscription.Name
                    PSTypeName     = 'PSU.Az.RoleAssignment'
                }
            }
        }

        # Apply filters
        if ($ResourceGroup)     { $results = $results | Where-Object { $_.ResourceGroup -eq $ResourceGroup } }
        if ($Role)              { $results = $results | Where-Object { $_.Role -eq $Role } }
        if ($AssignedToType)    { $results = $results | Where-Object { $_.AssignedToType -eq $AssignedToType } }
        if ($ResourceType)      { $results = $results | Where-Object { $_.ResourceType -eq $ResourceType } }

        return $results | Sort-Object ResourceName
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}