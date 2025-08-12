function Get-PSUk8sPodLabels--wip {
    <#
    .SYNOPSIS
    Gets pod labels from AKS clusters and namespaces, with optional cluster filtering.

    .DESCRIPTION
    Retrieves pod labels from AKS clusters and namespaces. You can filter clusters using the ClusterFilter parameter. Uses thread jobs for parallel processing.

    .PARAMETER ClusterFilter
    Optional. Only process clusters whose names match this filter (wildcards supported).

    .EXAMPLE
    Get-PSUk8sPodLabels--wip -ClusterFilter "*prod*"

    .NOTES
    Author: Lakshmanachari Panuganti
    Date  : 2025-08-11
    Requires kubectl to be installed and configured with access to AKS clusters.
    #>
    [CmdletBinding()]
    param(
        [string]$ClusterFilter = "*"
    )

    try {
        $kubeConfigPath = Join-Path $env:USERPROFILE ".kube\config"
        if (-not (Test-Path $kubeConfigPath)) {
            Write-Error "Kubeconfig file not found at $kubeConfigPath. Please configure kubectl before running this function."
            return
        }

        Write-Verbose "Getting all available clusters..."
        $clusters = kubectl config get-contexts -o name | Where-Object{$_ -like '*-admin'}
        if ($ClusterFilter -and $ClusterFilter -ne "*") {
            $clusters = $clusters | Where-Object { $_ -like $ClusterFilter }
        }
        if (-not $clusters) {
            Write-Warning "No Kubernetes clusters found in kubeconfig."
            return
        }

        $jobs = @()
        foreach ($cluster in $clusters) {
            $jobs += Start-ThreadJob -Name $cluster -ScriptBlock {
                param($cluster)
                try {
                    kubectl config use-context $cluster | Out-Null
                    $namespaces = kubectl get namespaces -o json | ConvertFrom-Json
                    $results = @()
                    foreach ($namespace in $namespaces.items) {
                        $namespaceName = $namespace.metadata.name
                        $pods = kubectl get pods -n $namespaceName -o json | ConvertFrom-Json
                        foreach ($pod in $pods.items) {
                            $labelString = ""
                            if ($pod.metadata.labels) {
                                $labelString = ($pod.metadata.labels.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ","
                            }
                            $results += [PSCustomObject]@{
                                Cluster   = $cluster
                                Namespace = $namespaceName
                                PodName   = $pod.metadata.name
                                Labels    = $labelString
                                Status    = $pod.status.phase
                                CreatedAt = $pod.metadata.creationTimestamp
                            }
                        }
                    }
                    return $results
                }
                catch {
                    Write-Warning "Failed to process cluster '$cluster': $($_.Exception.Message)"
                }
            } -ArgumentList $cluster
        }

        $totalJobs = $jobs.Count
        while ($true) {
            $completed = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
            $running   = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
            $failed    = ($jobs | Where-Object { $_.State -eq 'Failed' }).Count
            
            Write-Host "Jobs completed: $completed / $totalJobs | Running: $running | Failed: $failed"
            if ($completed + $failed -eq $totalJobs) { break }
            Start-Sleep -Seconds 2
        }

        $allResults = @()
        $completedJobs = $jobs | Where-Object { $_.State -eq 'Completed' }
        foreach ($job in $completedJobs) {
            $result = Receive-Job -Job $job
            if ($result) { $allResults += $result }
            Remove-Job -Job $job
        }

        if ($allResults.Count -eq 0) {
            Write-Warning "No pods found in any cluster or namespace."
            return
        }

        Write-Host "Found $($allResults.Count) pods across $($clusters.Count) clusters" -ForegroundColor Green
        return $allResults
    }
    catch {
        Write-Error "Failed to retrieve pod information: $($_.Exception.Message)"
    }
}