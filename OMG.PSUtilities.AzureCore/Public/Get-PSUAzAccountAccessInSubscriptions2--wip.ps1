function Get-PSUAzAccountAccessInSubscriptions2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]  [string]   $UserPrincipalName,
        [Parameter(Mandatory = $false)] [string]   $OutputCsv           = "C:\Temp\account-access-by-resource.csv",
        [Parameter(Mandatory = $false)] [switch]   $OutputJson,
        [Parameter(Mandatory = $false)] [int]      $JsonDepth           = 6,
        [Parameter(Mandatory = $false)] [string[]] $SubscriptionFilter  = @('*Non-Prod*')
    )

    # 1) Graph lookups
    Write-Host "Looking up user and group memberships..."
    $me      = Get-PSUGraphUser -Upn $UserPrincipalName
    $groups  = Get-PSUTransitiveGroups -UserId $me.Id
    $principalIdsToCheck = @($me.Id) + ($groups | Select-Object -ExpandProperty Id -ErrorAction SilentlyContinue | Where-Object { $_ })

    # 2) Subscriptions filter
    Write-Host "Filtering subscriptions..."
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

    Write-Host "Processing $($filteredSubs.Count) subscription(s)..."

    # 3) Collect all role assignments across all scopes
    $allAssignments = @()
    $unknownPrincipalIds = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($s in $filteredSubs) {
        Write-Host "Processing subscription: $($s.Name)"
        
        # Set subscription context
        try {
            Set-AzContext -SubscriptionId $s.Id -ErrorAction Stop | Out-Null
        } catch {
            Write-Warning "Failed to set context for subscription $($s.Id): $_"
            continue
        }

        # Get ALL role assignments in the subscription (all scopes)
        try {
            $assigns = Get-AzRoleAssignment -ErrorAction Stop
        } catch {
            Write-Host "Get-AzRoleAssignment failed for $($s.Id): $_"
            continue
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

            # Add normalized props and subscription info
            $a | Add-Member -NotePropertyName PSU_PrincipalId     -NotePropertyValue $norm.PrincipalId   -Force
            $a | Add-Member -NotePropertyName PSU_PrincipalType   -NotePropertyValue $norm.PrincipalType -Force
            $a | Add-Member -NotePropertyName PSU_AssignmentId    -NotePropertyValue $norm.AssignmentId  -Force
            $a | Add-Member -NotePropertyName PSU_SubscriptionId  -NotePropertyValue $s.Id               -Force
            $a | Add-Member -NotePropertyName PSU_SubscriptionName -NotePropertyValue $s.Name            -Force
        }

        # Filter for assignments that match our user/groups
        $matched = $assigns | Where-Object { $_.PSU_PrincipalId -and $principalIdsToCheck -contains $_.PSU_PrincipalId }
        $allAssignments += $matched

        # Track unknown principals for resolution
        foreach ($a in $matched) {
            $PSU_PrincipalId = $a.PSU_PrincipalId
            if ($PSU_PrincipalId -and $PSU_PrincipalId -ne $me.Id -and -not ($groups | Where-Object { $_.Id -eq $PSU_PrincipalId })) {
                $null = $unknownPrincipalIds.Add($PSU_PrincipalId)
            }
        }
    }

    Write-Host "Found $($allAssignments.Count) matching role assignments"

    # 4) Resolve principals
    Write-Host "Resolving principal names..."
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

    # 5) Build detailed output with resource-level information
    Write-Host "Building detailed resource access report..."
    $rows = foreach ($assignment in $allAssignments) {
        # Parse scope to extract resource information
        $scope = $assignment.Scope
        $subscriptionId = $assignment.PSU_SubscriptionId
        $subscriptionName = $assignment.PSU_SubscriptionName
        
        # Initialize resource details
        $resourceGroup = ""
        $resourceType = ""
        $azResourceName = ""
        $scopeLevel = ""

        # Parse the scope to extract resource information
        if ($scope -match '^/subscriptions/[^/]+$') {
            $scopeLevel = 'Subscription'
            $azResourceName = $subscriptionName
            $resourceType = 'Subscription'
        }
        elseif ($scope -match '^/subscriptions/[^/]+/resourceGroups/([^/]+)$') {
            $scopeLevel = 'ResourceGroup'
            $resourceGroup = $matches[1]
            $azResourceName = $resourceGroup
            $resourceType = 'ResourceGroup'
        }
        elseif ($scope -match '^/subscriptions/[^/]+/resourceGroups/([^/]+)/providers/([^/]+/[^/]+)/?(.*)$') {
            $scopeLevel = 'Resource'
            $resourceGroup = $matches[1]
            $resourceType = $matches[2]
            $resourcePath = $matches[3]
            
            # Extract the final resource name from the path
            if ($resourcePath) {
                $pathParts = $resourcePath -split '/'
                $azResourceName = $pathParts[-1]  # Take the last part as the resource name
            } else {
                $azResourceName = "Unknown Resource"
            }
        }
        else {
            $scopeLevel = 'Other'
            $azResourceName = $scope
            $resourceType = 'Unknown'
        }

        # Get role definition for access type mapping
        $roleDef = Get-AzRoleDefinition -Id $assignment.RoleDefinitionId -ErrorAction SilentlyContinue
        
        # Map role to access type (simplified categorization)
        $typeOfAccess = switch -Wildcard ($assignment.RoleDefinitionName) {
            "*Owner*"        { "Owner" }
            "*Contributor*"  { "Contributor" }
            "*Reader*"       { "Reader" }
            "*Writer*"       { "Write" }
            "*Admin*"        { "Admin" }
            "*Viewer*"       { "Read" }
            "*Manager*"      { "Manage" }
            "*Operator*"     { "Operate" }
            "*Developer*"    { "Develop" }
            "*User Access*"  { "User Access Management" }
            default          { $assignment.RoleDefinitionName }
        }

        # Create output row
        [PSCustomObject]@{
            UserPrincipalName    = $UserPrincipalName
            AzResourceName       = $azResourceName
            ResourceGroup        = $resourceGroup
            ResourceType         = $resourceType
            TypeOfAccess         = $typeOfAccess
            RoleDefinitionName   = $assignment.RoleDefinitionName
            ScopeLevel          = $scopeLevel
            Scope               = $scope
            SubscriptionName    = $subscriptionName
            SubscriptionId      = $subscriptionId
            PrincipalDisplayName = $resolvedCache[$assignment.PSU_PrincipalId].DisplayName
            PrincipalType       = $resolvedCache[$assignment.PSU_PrincipalId].Type
            PrincipalId         = $assignment.PSU_PrincipalId
            AssignmentId        = $assignment.PSU_AssignmentId
            Condition           = $assignment.Condition
            Description         = $assignment.Description
        }
    }

    # 6) Export results
    Write-Host "Exporting results..."
    try {
        # Export with the requested columns first, then additional details
        $rows | Select-Object UserPrincipalName, AzResourceName, ResourceGroup, ResourceType, TypeOfAccess, 
                             RoleDefinitionName, ScopeLevel, Scope, SubscriptionName, SubscriptionId, 
                             PrincipalDisplayName, PrincipalType, PrincipalId, AssignmentId, Condition, Description |
            Export-Csv -Path $OutputCsv -NoTypeInformation -Force -Encoding UTF8
        
        Write-Host "CSV exported to: $OutputCsv"
    } catch {
        Write-Warning "Export CSV failed: $_"
    }

    if ($OutputJson) {
        $full = @{ 
            GeneratedAt = (Get-Date).ToString("o")
            User = $UserPrincipalName
            TotalAssignments = $rows.Count
            Results = $rows 
        }
        $jsonPath = [System.IO.Path]::ChangeExtension($OutputCsv, '.full.json')
        try {
            $full | ConvertTo-Json -Depth ($JsonDepth + 2) | Out-File -FilePath $jsonPath -Encoding UTF8
            Write-Host "JSON exported to: $jsonPath"
        } catch {
            Write-Warning "Failed to write JSON: $_"
        }
    }

    Write-Host "Processing complete. Found $($rows.Count) resource access assignments."
    return $rows
}