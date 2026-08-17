<#
.SYNOPSIS
    Gets pod labels from AKS clusters in parallel with minimal kubectl overhead.

.DESCRIPTION
    Retrieves pod labels from all namespaces in AKS clusters using a single optimized
    kubectl call per cluster. Shows live job progress and lists failed clusters for
    easy retry. Clusters are retrieved from the local kubeconfig file (~/.kube/config).
    Ensure all required cluster credentials are updated in the kubeconfig file before running.

.PARAMETER ClusterFilter
    (Optional) Filter clusters by name pattern using wildcards.
    Default: "*" (all clusters).
    Example: "*prod*" matches all production clusters.

.PARAMETER ThrottleLimit
    (Optional) Maximum number of parallel jobs to run simultaneously.
    Default: 8.

.EXAMPLE
    Get-PSUk8sPodLabel

    Retrieves pod labels from all clusters in the local kubeconfig.

.EXAMPLE
    Get-PSUk8sPodLabel -ClusterFilter "*prod*" -ThrottleLimit 15

    Retrieves pod labels from all production clusters with up to 15 parallel jobs.

.OUTPUTS
    [System.Object[]]

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 19th August 2025
    Last Modified: 7th March 2026
    Version: 1.1
    Requires: kubectl, ThreadJob module

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureCore
#>
function Get-PSUk8sPodLabel {
    [CmdletBinding()]
    param(
        [string]$ClusterFilter = "*",
        [int]$ThrottleLimit = 8
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Parameters:"
        Write-Verbose "  ClusterFilter = $ClusterFilter"
        Write-Verbose "  ThrottleLimit = $ThrottleLimit"

        # kubectl and ThreadJob are optional dependencies of this module and are resolved
        # here rather than declared in the manifest, so the other exports stay usable
        # without them. Never install anything implicitly; tell the caller what to do.
        if (-not (Get-Command -Name 'kubectl' -ErrorAction SilentlyContinue)) {
            throw "kubectl was not found on PATH. Install the Kubernetes CLI, confirm 'kubectl version --client' runs, then try again."
        }

        if (-not (Get-Command -Name 'Start-ThreadJob' -ErrorAction SilentlyContinue)) {
            throw "Start-ThreadJob is not available. Install the ThreadJob module with: Install-Module ThreadJob -Scope CurrentUser"
        }

        $kubeConfigPath = Join-Path $env:USERPROFILE ".kube\config"

        if (-not (Test-Path $kubeConfigPath)) {
            throw "Kubeconfig file not found at $kubeConfigPath."
        }

        Write-Host "Note: Retrieving clusters from kubeconfig: $kubeConfigPath" -ForegroundColor Cyan
        Write-Host "   Ensure all required cluster credentials are updated in the kubeconfig file before running." -ForegroundColor Yellow
    }

    process {
        try {
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

        $jobs = @()
        foreach ($cluster in $clusters) {
            while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $ThrottleLimit) {
                $completed = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
                $running   = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
                $failed    = ($jobs | Where-Object { $_.State -eq 'Failed' }).Count
                $percent   = [math]::Round(($completed / $clusters.Count) * 100, 1)

                $color = if ($percent -lt 50) { "Yellow" } elseif ($percent -lt 91) { "Cyan" } else { "Green" }
                Write-Host ("`rJobs completed: {0} / {1} ({4,5}%) | Running: {2} | Failed: {3}   " -f $completed, $clusters.Count, $running, $failed, $percent) -ForegroundColor $color -NoNewline

                Start-Sleep -Seconds 1
            }

            $jobs += Start-ThreadJob -Name $cluster -ArgumentList $cluster -ScriptBlock {
                param($cluster)
                try {
                    $output = kubectl --context $cluster get pods --all-namespaces `
                        -o jsonpath='{range .items[*]}{.metadata.namespace}{"|"}{.metadata.name}{"|"}{.metadata.labels}{"|"}{.status.phase}{"|"}{.metadata.creationTimestamp}{"\n"}{end}' 2>$null

                    $lines = $output -split "`n"
                    foreach ($line in $lines) {
                        if (-not $line) { continue }
                        $parts = $line -split '\|', 5
                        [PSCustomObject]@{
                            Cluster   = $cluster
                            Namespace = $parts[0]
                            PodName   = $parts[1]
                            Labels    = $parts[2] -replace '^map\[|\]$', '' -replace ' ', ','  | ConvertFrom-Json
                            Status    = $parts[3]
                            CreatedAt = [datetime]$parts[4]
                        }
                    }
                }
                catch {
                    Write-Error "Failed to process cluster '$cluster': $_"
                }
            }
        }

        # Wait for completion with progress
        $totalJobs = $jobs.Count
        while ($true) {
            $completed = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
            $running   = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
            $failed    = ($jobs | Where-Object { $_.State -eq 'Failed' }).Count
            $percent   = [math]::Round(($completed / $totalJobs) * 100, 1)

            $color = if ($percent -lt 50) { "Yellow" } elseif ($percent -lt 91) { "Cyan" } else { "Green" }
            Write-Host ("`rJobs completed: {0} / {1} ({4,5}%) | Running: {2} | Failed: {3}   " -f $completed, $totalJobs, $running, $failed, $percent) -ForegroundColor $color -NoNewline

            if ($completed + $failed -eq $totalJobs) { break }
            Start-Sleep -Seconds 1
        }
        Write-Host "" # Newline after loop

        # Gather results
        $allResults = @()
        $failedClusters = @()
        foreach ($job in $jobs) {
            if ($job.State -eq 'Completed') {
                $result = Receive-Job -Job $job
                if ($result) { $allResults += $result }
            } elseif ($job.State -eq 'Failed') {
                $failedClusters += $job.Name
            }
            Remove-Job -Job $job
        }

        # Summary
        if ($failedClusters.Count -gt 0) {
            Write-Host "Failed clusters: $($failedClusters -join ', ')" -ForegroundColor Red
        } else {
            Write-Host "All clusters processed successfully." -ForegroundColor Green
        }

        if (-not $allResults) {
            Write-Warning "No pods found in any cluster."
            return
        }

        Write-Host "Found $($allResults.Count) pods across $($clusters.Count) clusters" -ForegroundColor Green
        return $allResults

        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
