function Get-PSUAksWorkloadIdentityInventory {
    <#
    .SYNOPSIS
        Inventories Azure Workload Identity usage across AKS clusters.

    .DESCRIPTION
        This function scans AKS clusters across Azure subscriptions to identify pods that are using Azure Workload Identity.
        It provides detailed information about workload identity usage including cluster, namespace, pod details, and service account information.

    .PARAMETER SubscriptionId
        Specifies one or more Azure subscription IDs to scan. If not provided, all accessible subscriptions will be scanned.

    .PARAMETER ClusterName
        Specifies one or more AKS cluster names to scan. If not provided, all clusters in the specified subscriptions will be scanned.
        Supports wildcard patterns.

    .PARAMETER ExportToCsv
        If specified, exports the results to a CSV file.

    .PARAMETER OutputPath
        Specifies the path for the excel file to export. Default is "workload-identity-inventory.csv".

    .EXAMPLE
        az login --use-device-code
        Get-PSUAksWorkloadIdentityInventory
        
        Scans all accessible subscriptions and clusters for workload identity usage.

    .EXAMPLE
        az login --use-device-code
        Get-PSUAksWorkloadIdentityInventory
        Get-PSUAksWorkloadIdentityInventory -SubscriptionId "12345678-1234-1234-1234-123456789012"
        
        Scans only the specified subscription.

    .EXAMPLE
        az login --use-device-code
        Get-PSUAksWorkloadIdentityInventory
        Get-PSUAksWorkloadIdentityInventory -SubscriptionId "12345678-1234-1234-1234-123456789012" -ClusterName "prod-aks-*"
        
        Scans clusters matching the pattern in the specified subscription.

    .EXAMPLE
        az login --use-device-code
        Get-PSUAksWorkloadIdentityInventory
        Get-PSUAksWorkloadIdentityInventory -ClusterName "dev-aks-01", "staging-aks-01" -Export
        
        Scans specific clusters and exports results to Excel.
    #>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$SubscriptionId,

        [Parameter()]
        [string[]]$ClusterName,

        [Parameter()]
        [switch]$Export,

        [Parameter()]
        [string]$OutputPath = "C:\Temp\workload-identity-inventory.xlsx"
    )

    begin {
        # Initialize data collection
        $data = [System.Collections.ArrayList]::new()

        # Verify required tools
        $requiredCommands = @('kubectl', 'az')
        foreach ($cmd in $requiredCommands) {
            if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
                throw "Required command '$cmd' not found. Please ensure Azure CLI and kubectl are installed and in PATH."
            }
        }

        Write-Host "Starting Azure Workload Identity inventory..." -ForegroundColor Green
    }

    process {
        try {
            # Get subscriptions to process
            if ($SubscriptionId) {
                $subscriptions = @()
                foreach ($subId in $SubscriptionId) {
                    try {
                        $sub = Get-AzSubscription -SubscriptionId $subId -ErrorAction Stop
                        $subscriptions += $sub
                    } catch {
                        Write-Warning "Subscription '$subId' not found or not accessible: $($_.Exception.Message)"
                    }
                }
            } else {
                Write-Host "No specific subscriptions provided. Scanning all accessible subscriptions..." -ForegroundColor Yellow
                $subscriptions = Get-AzSubscription
            }

            if (-not $subscriptions) {
                Write-Warning "No subscriptions found to process."
                return
            }

            foreach ($sub in $subscriptions) {
                try {
                    Write-Host "Processing subscription: $($sub.Name) ($($sub.Id))" -ForegroundColor Green

                    # Set context for both PowerShell and CLI
                    $null = Set-AzContext -Subscription $sub.Id -ErrorAction Stop
                    az account set --subscription $sub.Id --only-show-errors

                    # Get AKS clusters
                    $aksClusters = Get-AzAksCluster

                    if (-not $aksClusters) {
                        Write-Host "  No AKS clusters found in subscription '$($sub.Name)'" -ForegroundColor Yellow
                        continue
                    }

                    # Filter clusters if ClusterName parameter is provided
                    if ($ClusterName) {
                        $filteredClusters = @()
                        foreach ($pattern in $ClusterName) {
                            $matchingClusters = $aksClusters | Where-Object { $_.Name -like $pattern }
                            $filteredClusters += $matchingClusters
                        }
                        $aksClusters = $filteredClusters | Sort-Object Name -Unique

                        if (-not $aksClusters) {
                            Write-Host "  No AKS clusters matching specified names found in subscription '$($sub.Name)'" -ForegroundColor Yellow
                            continue
                        }
                    }

                    foreach ($cluster in $aksClusters) {
                        try {
                            Write-Host "    Processing cluster: $($cluster.Name) in RG: $($cluster.ResourceGroupName)" -ForegroundColor Cyan

                            # Get AKS credentials
                            $credResult = az aks get-credentials --resource-group $cluster.ResourceGroupName --name $cluster.Name --overwrite-existing --admin --only-show-errors 2>&1

                            if ($LASTEXITCODE -ne 0) {
                                Write-Warning "    Failed to get credentials for cluster '$($cluster.Name)': $credResult"
                                continue
                            }

                            # Get pods with workload identity labels (more efficient than getting all pods)
                            #$podsJson = kubectl get pods --all-namespaces -l "azure.workload.identity/use" -o json 2>$null
                            $podsJson = kubectl get pods --all-namespaces -o json 2>$null


                            if ($LASTEXITCODE -ne 0 -or -not $podsJson) {
                                Write-Host "      No pods with workload identity found in cluster '$($cluster.Name)'" -ForegroundColor Yellow
                                continue
                            }

                            try {
                                $podsObj = $podsJson | ConvertFrom-Json -ErrorAction Stop

                                if ($podsObj.items.Count -eq 0) {
                                    Write-Host "         No pods with workload identity found in cluster '$($cluster.Name)'" -ForegroundColor Yellow
                                    continue
                                }

                                Write-Host "         Found $($podsObj.items.Count) pod(s) with workload identity label" -ForegroundColor Green

                                foreach ($pod in $podsObj.items) {
                                    $null = $data.Add([pscustomobject]@{
                                            SubscriptionName = $sub.Name
                                            SubscriptionId   = $sub.Id
                                            ClusterName      = $cluster.Name
                                            ResourceGroup    = $cluster.ResourceGroupName
                                            Location         = $cluster.Location
                                            Namespace        = $pod.metadata.namespace
                                            PodName          = $pod.metadata.name
                                            WorkloadIdentity = $pod.metadata.labels.'azure.workload.identity/use'
                                            ServiceAccount   = $pod.spec.serviceAccountName
                                            PodStatus        = $pod.status.phase
                                            CreationTime     = $pod.metadata.creationTimestamp
                                        })
                                }
                            } catch {
                                Write-Warning "         Failed to parse pod data for cluster '$($cluster.Name)': $($_.Exception.Message)"
                            }
                        } catch {
                            Write-Warning "         Failed to process cluster '$($cluster.Name)': $($_.Exception.Message)"
                        }
                    }
                } catch {
                    Write-Warning "Failed to process subscription '$($sub.Name)': $($_.Exception.Message)"
                }
            }
        } catch {
            Write-Error "Critical error during processing: $($_.Exception.Message)"
            throw
        }
    }

    end {
        # Output results
        if ($data.Count -gt 0) {
            Write-Host "`nInventory completed. Found $($data.Count) pod(s) using Azure Workload Identity." -ForegroundColor Green

            if ($Export) {
                try {
                    $data | Export-PSUExcel -ExcelPath $OutputPath -AutoOpen -AutoFilter
                    Write-Host "Results exported to: $OutputPath" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to export to CSV: $($_.Exception.Message)"
                }
            }

            # Return the data
            return $data | Sort-Object SubscriptionName, ClusterName, Namespace, PodName
        } else {
            Write-Host "`nNo pods with Azure Workload Identity found in the specified scope." -ForegroundColor Yellow
            return @()
        }
    }
}