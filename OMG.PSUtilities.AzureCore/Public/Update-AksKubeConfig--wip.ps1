function Update-AksKubeConfig {
    [CmdletBinding()]
    param(
        [int]$ThrottleLimit = 8,
        [switch]$Admin,
        [string]$SubscriptionFilter = "*non-prod*"
    )

    try {
        foreach ($tool in @("az", "kubelogin", "kubectl")) {
            if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
                Write-Error "'$tool' is not installed or not in PATH."
                return
            }
        }

        Write-Host "Retrieving Azure subscriptions using az CLI..." -ForegroundColor Cyan
        $allSubsJson = az account list --output json | ConvertFrom-Json

        if (-not $allSubsJson) {
            Write-Warning "No Azure subscriptions found."
            return
        }

        $subs = $allSubsJson | Where-Object { $_.name -like $SubscriptionFilter }
        if (-not $subs) {
            Write-Warning "No subscriptions matched filter '$SubscriptionFilter'."
            return
        }

        $jobs = @()
        foreach ($sub in $subs) {
            while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $ThrottleLimit) {
                $completed = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
                $running   = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
                $failed    = ($jobs | Where-Object { $_.State -eq 'Failed' }).Count
                $percent   = [math]::Round(($completed / $subs.Count) * 100, 1)
                $color     = if ($percent -lt 50) { "Yellow" } elseif ($percent -lt 91) { "Cyan" } else { "Green" }

                Write-Host ("`rJobs completed: {0}/{1} ({4,5}%) | Running: {2} | Failed: {3}   " -f $completed, $subs.Count, $running, $failed, $percent) -ForegroundColor $color -NoNewline
                Start-Sleep -Seconds 1
            }

            $jobs += Start-ThreadJob -Name $sub.name -ArgumentList $sub, $Admin -ScriptBlock {
                param($sub, $adminFlag)
                try {
                    az account set --subscription $sub.id | Out-Null
                    $aksClustersJson = az aks list --subscription $sub.id --output json | ConvertFrom-Json
                    if (-not $aksClustersJson) {
                        Write-Host "No AKS clusters found in subscription $($sub.name)." -ForegroundColor Yellow
                        return
                    }

                    foreach ($cluster in $aksClustersJson) {
                        $adminParam = if ($adminFlag) { "--admin" } else { "" }
                        # Run az aks get-credentials capturing stderr
                        $stderrFile = [System.IO.Path]::GetTempFileName()
                        $azGetCreds = Start-Process az -ArgumentList @("aks", "get-credentials", "--resource-group", $cluster.resourceGroup, "--name", $cluster.name, "--overwrite-existing", $adminParam) -NoNewWindow -PassThru -RedirectStandardError $stderrFile -Wait

                        $errorText = Get-Content $stderrFile -Raw
                        Remove-Item $stderrFile -Force

                        if ($errorText -and $errorText -match "AADSTS50173") {
                            Write-Host "Token expired or revoked error detected for subscription $($sub.name). Please run 'az login' to refresh credentials." -ForegroundColor Red
                            return
                        }
                        elseif ($errorText) {
                            Write-Host "Error updating credentials for cluster $($cluster.name) in subscription $($sub.name): $errorText" -ForegroundColor Red
                            return
                        }

                        # Convert kubeconfig for azurecli login if kubelogin installed
                        try {
                            kubelogin convert-kubeconfig -l azurecli | Out-Null
                        }
                        catch {
                            Write-Host "kubelogin convert-kubeconfig failed for cluster $($cluster.name): $_" -ForegroundColor Yellow
                        }
                    }

                    [pscustomobject]@{
                        Subscription = $sub.name
                        ClusterCount = $aksClustersJson.Count
                        Status       = "Updated"
                        UsedAdmin    = $adminFlag.IsPresent
                    }
                }
                catch {
                    Write-Error "Failed to process subscription '$($sub.name)': $_"
                }
            }
        }

        $totalJobs = $jobs.Count
        while ($true) {
            $completed = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
            $running   = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
            $failed    = ($jobs | Where-Object { $_.State -eq 'Failed' }).Count
            $percent   = [math]::Round(($completed / $totalJobs) * 100, 1)
            $color     = if ($percent -lt 50) { "Yellow" } elseif ($percent -lt 91) { "Cyan" } else { "Green" }

            Write-Host ("`rJobs completed: {0}/{1} ({4,5}%) | Running: {2} | Failed: {3}   " -f $completed, $totalJobs, $running, $failed, $percent) -ForegroundColor $color -NoNewline

            if ($completed + $failed -eq $totalJobs) { break }
            Start-Sleep -Seconds 1
        }
        Write-Host ""

        $results = @()
        $failedSubs = @()
        foreach ($job in $jobs) {
            if ($job.State -eq 'Completed') {
                $res = Receive-Job -Job $job
                if ($res) {
                    $results += $res
                }
            }
            elseif ($job.State -eq 'Failed') {
                $failedSubs += $job.Name
            }
            Remove-Job -Job $job
        }

        if ($failedSubs.Count -gt 0) {
            Write-Host "Failed subscriptions: $($failedSubs -join ', ')" -ForegroundColor Red
        }
        else {
            Write-Host "All subscriptions processed successfully." -ForegroundColor Green
        }

        return $results
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
