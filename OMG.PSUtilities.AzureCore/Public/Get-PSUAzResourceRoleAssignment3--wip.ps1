param(
    [string]$SubscriptionNameFilter = "*",
    [string]$ResourceTypeFilter,
    [string]$ResourceGroupFilter,
    [ValidateSet("User", "Group", "ServicePrincipal", "Unknown")]
    [string]$RoleAssignedToTypeFilter,
    [int]$ThrottleLimit = 15
)

try {
    $azureCred = Get-RSMCred "AzureAutomationSVC" -UserNameFormat { "$username@$domain" }
    $azConnectParam = @{
        Credential    = $azureCred
        TenantId      = '1e3e71be-fcca-4284-9031-688cc8f37b6b'
        WarningAction = 'SilentlyContinue'
        ErrorAction   = 'Stop'
    }

    $null = Connect-AzAccount @azConnectParam
}
catch {
    $errorMsg = "$($_.CategoryInfo.activity): $($_.Exception.Message)"
    Write-ErrorLog $errorMsg
    throw $errorMsg
}

$outputDirectory = 'C:\Temp\RoleAssignments'

# Check $outputDirectory existance, if not create
if (-not (Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$subscriptionList = Get-AzSubscription |
Where-Object { $_.State -eq 'Enabled' -and $_.Name -ilike $SubscriptionNameFilter }

if (-not $subscriptionList) {
    Write-Warning "No matching subscriptions found for filter: '$SubscriptionNameFilter'"
    return
}

$totalSubscriptions = $subscriptionList.Count
$subIndex = 0

foreach ($subscription in $subscriptionList) {
    $RoleAssignmentDirectory = Join-Path -Path $outputDirectory -ChildPath $subscription.Name
    # check if $RoleAssignmentDirectory exist, if not create a folder for this subscription
    if (-not (Test-Path -Path $RoleAssignmentDirectory)) {
        New-Item -ItemType Directory -Path $RoleAssignmentDirectory | Out-Null
    }
    $subIndex++
    $subProgressPercent = [math]::Round(($subIndex / $totalSubscriptions) * 100)

    Write-Progress -Activity "Processing Subscriptions" `
        -Status "[$subIndex of $totalSubscriptions] $($subscription.Name)" `
        -PercentComplete $subProgressPercent

    Set-AzContext -SubscriptionObject $subscription | Out-Null
    
    # Build filter hashtable for Get-AzResource
    $resourceFilter = @{}
    if ($ResourceTypeFilter) { $resourceFilter['ResourceType'] = $ResourceTypeFilter }
    if ($ResourceGroupFilter) { $resourceFilter['ResourceGroupName'] = $ResourceGroupFilter }
    
    $azResourceList = Get-AzResource @resourceFilter

    if ($azResourceList.Count -eq 0) {
        Write-Host "No resources found in subscription $($subscription.Name) with current filters"
        continue
    }

    Write-Host "Processing $($azResourceList.Count) resources in subscription: $($subscription.Name)"
    $startTime = Get-Date
    
    # Use ConcurrentBag for thread-safe collection
    $result = New-Object System.Collections.Concurrent.ConcurrentBag[Object]
    
    # Process all resources in parallel
    $azResourceList | ForEach-Object -Parallel {
        $azResource = $_
        $subscription = $using:subscription
        $RoleAssignedToTypeFilter = $using:RoleAssignedToTypeFilter
        $result = $using:result
        $RoleAssignmentDirectory = $using:RoleAssignmentDirectory

        try {
            # Get all role assignments for this resource in one call
            $roleAssignments = Get-AzRoleAssignment -Scope $azResource.ResourceId -ErrorAction SilentlyContinue
            
            if ($roleAssignments) {
                # Filter role assignments if needed
                if ($RoleAssignedToTypeFilter) {
                    $roleAssignments = $roleAssignments | Where-Object { $_.ObjectType -eq $RoleAssignedToTypeFilter }
                }
                
                # Process all role assignments for this resource
                $resourceData = @()
                foreach ($roleAssignment in $roleAssignments) {
                    $resourceData += [PSCustomObject]@{
                        ResourceName         = $azResource.Name
                        ResourceType         = $azResource.ResourceType
                        ResourceGroup        = $azResource.ResourceGroupName
                        ResourceLocation     = $azResource.Location
                        ResourceSubscription = $subscription.Name
                        RoleAssignedTo       = $roleAssignment.DisplayName
                        RoleAssignedToId     = $roleAssignment.ObjectId 
                        RoleAssignedToType   = $roleAssignment.ObjectType
                        RoleAssignmentId     = $roleAssignment.RoleAssignmentName
                        RoleDefinitionName   = $roleAssignment.RoleDefinitionName
                    }
                }

                $resTypeShort = ($azResource.ResourceType) -split '/' | Select-Object -Last 1
                $filename = "$($azResource.Name)" -replace '\\', '.'
                # Replace all non-standard filename characters with '-'
                $filename = $filename -replace '[^a-zA-Z0-9\-]', '-'
                $filename = "$($azResource.ResourceGroupName).$resTypeShort.$filename"
                $resourceData | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path $RoleAssignmentDirectory -ChildPath "$filename.json") -Encoding UTF8NoBOM
            }
        }
        catch {
            # Log errors but don't stop processing
            Write-Warning "Failed to get role assignments for resource: $($azResource.Name). Error: $($_.Exception.Message)"
        }
    } -ThrottleLimit $ThrottleLimit
}

$subscriptions = Get-Childitem $outputDirectory -Directory

foreach ($subscription in $subscriptions) {
    $SubscriptionName = $subscription.Name
    $fullname = $subscription.FullName
    $subscriptionFiles = Get-ChildItem -Path $fullname -File -Filter "*.json"

    $roleAssignmentsInfo = [System.Collections.Generic.List[object]]::new()

    foreach ($file in $subscriptionFiles) {
        try {
            # Read entire file as a single string and parse it directly
            $jsonContent = Get-Content -Path $file.FullName -Raw
            $jsonObjects = $jsonContent | ConvertFrom-Json -Depth 10

            # Handle case where the JSON is either an object or an array
            if ($jsonObjects -is [System.Collections.IEnumerable]) {
                foreach ($obj in $jsonObjects) {
                    $roleAssignmentsInfo.Add($obj)
                }
            } else {
                $roleAssignmentsInfo.Add($jsonObjects)
            }
        }
        catch {
            Write-Warning "Failed to process $($file.Name): $($_.Exception.Message)"
        }
    }

    Write-Host "Processed $($roleAssignmentsInfo.Count) role assignments for subscription: $SubscriptionName" -NoNewline
    $exportPath = Join-Path -Path $outputDirectory -ChildPath "RoleAssignments-$SubscriptionName.csv"
    $roleAssignmentsInfo | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8

    Write-Host " - Exported to worksheet $SubscriptionName" -ForegroundColor Green
}
