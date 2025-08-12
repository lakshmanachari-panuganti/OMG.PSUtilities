function Get-PSUk8sPodLabels--wip {
    <#
    .SYNOPSIS
    Gets pod labels from AKS clusters in parallel using one API call per cluster, with live job status.

    .DESCRIPTION
    Retrieves pod labels from all namespaces in AKS clusters.
    Runs jobs in parallel using Start-ThreadJob and polls job status until complete.
    Displays a live progress indicator showing completed, running, failed jobs, and percentage done.

    Clusters are retrieved from the local kubeconfig file (~/.kube/config).
    Ensure all required cluster credentials are updated in the kubeconfig file before running.

    .PARAMETER ClusterFilter
    Optional. Only process clusters whose names match this filter (wildcards supported).

    .PARAMETER ThrottleLimit
    Maximum number of jobs to run in parallel.

    .EXAMPLE
    Get-PSUk8sPodLabels -ClusterFilter "*prod*" -ThrottleLimit 8
    #>

    [CmdletBinding()]
    param(
        [string]$ClusterFilter = "*",
        [int]$ThrottleLimit = 8
    )

    try {
        $kubeConfigPath = Join-Path $env:USERPROFILE ".kube\config"

        Write-Host "ℹ️  Retrieving clusters from the existing kubeconfig file: $kubeConfigPath" -ForegroundColor Cyan
        Write-Host "   Ensure all required cluster credentials are updated in the kubeconfig file before running this command." -ForegroundColor Yellow

        if (-not (Test-Path $kubeConfigPath)) {
            Write-Error "Kubeconfig file not found at $kubeConfigPath. Please configure kubectl before running."
            return
        }

        Write-Verbose "Getting all available clusters..."
        $clusters = kubectl config get-contexts -o name | Where-Object { $_ -like '*-admin' }
        if ($ClusterFilter -and $ClusterFilter -ne "*") {
            $clusters = $clusters | Where-Object { $_ -like $ClusterFilter }
        }
        if (-not $clusters) {
            Write-Warning "No Kubernetes clusters found in kubeconfig."
            return
        }

        Write-Host "Processing $($clusters.Count) clusters in parallel (ThrottleLimit: $ThrottleLimit)..."

        # Create jobs in batches based on ThrottleLimit
        $jobs = @()
        foreach ($cluster in $clusters) {
            while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $ThrottleLimit) {
                $completed = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
                $running   = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
                $failed    = ($jobs | Where-Object { $_.State -eq 'Failed' }).Count
                $percent   = [math]::Round(($completed / $clusters.Count) * 100, 1)

                if ($percent -lt 50) {
                    $color = "Yellow"
                } elseif ($percent -lt 91) {
                    $color = "Cyan"
                } else {
                    $color = "Green"
                }

                Write-Host ("`rJobs completed: {0} / {1} ({4}%) | Running: {2} | Failed: {3}   " -f $completed, $clusters.Count, $running, $failed, $percent) -ForegroundColor $color -NoNewline
                Start-Sleep -Seconds 1
            }

            $jobs += Start-ThreadJob -Name $cluster -ArgumentList $cluster -ScriptBlock {
                param($cluster)
                try {
                    $podsJson = kubectl --context $cluster get pods --all-namespaces -o json | ConvertFrom-Json
                    $podsJson.items | ForEach-Object {
                        [PSCustomObject]@{
                            Cluster   = $cluster
                            Namespace = $_.metadata.namespace
                            PodName   = $_.metadata.name
                            Labels    = if ($_.metadata.labels) {
                                            ($_.metadata.labels.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ","
                                        } else { "" }
                            Status    = $_.status.phase
                            CreatedAt = $_.metadata.creationTimestamp
                        }
                    }
                }
                catch {
                    Write-Warning "Failed to process cluster '$cluster': $_"
                }
            }
        }

        # Wait for all jobs to complete with status updates
        $totalJobs = $jobs.Count
        while ($true) {
            $completed = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
            $running   = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
            $failed    = ($jobs | Where-Object { $_.State -eq 'Failed' }).Count
            $percent   = [math]::Round(($completed / $totalJobs) * 100, 1)

            if ($percent -lt 50) {
                $color = "Yellow"
            } elseif ($percent -lt 91) {
                $color = "Cyan"
            } else {
                $color = "Green"
            }

            Write-Host ("`rJobs completed: {0} / {1} ({4}%) | Running: {2} | Failed: {3}   " -f $completed, $totalJobs, $running, $failed, $percent) -ForegroundColor $color -NoNewline
            if ($completed + $failed -eq $totalJobs) { break }
            Start-Sleep -Seconds 1
        }
        Write-Host "" # Move to a new line after status loop ends

        # Gather results
        $allResults = @()
        foreach ($job in ($jobs | Where-Object { $_.State -eq 'Completed' })) {
            $result = Receive-Job -Job $job
            if ($result) { $allResults += $result }
            Remove-Job -Job $job
        }

        if (-not $allResults) {
            Write-Warning "No pods found in any cluster."
            return
        }

        Write-Host "Found $($allResults.Count) pods across $($clusters.Count) clusters" -ForegroundColor Green
        return $allResults

    }
    catch {
        Write-Error "Failed to retrieve pod information: $($_.Exception.Message)"
    }
}
