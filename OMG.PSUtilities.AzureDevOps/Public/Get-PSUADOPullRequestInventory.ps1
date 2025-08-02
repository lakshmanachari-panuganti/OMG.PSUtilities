function Get-PSUADOPullRequestInventory {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [string]$PAT = $env:PAT,

        [Parameter()]
        [string[]]$Project = @('Technical Services'),

        [Parameter()]
        [string]$OutputFilePath,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]$ThrottleLimit = 10,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$TimeoutMinutes = 10
    )

    Write-Host "Fetching projects for organization '$Organization'..." -ForegroundColor Cyan
    Write-Host "Starting parallel collection with Start-ThreadJob (ThrottleLimit = $ThrottleLimit)" -ForegroundColor Cyan

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $allJobs = @()

    foreach ($proj in $Project) {
        $repos = Get-PSUADORepositories -Project $proj -Organization $Organization -PAT $PAT

        foreach ($repo in $repos) {
            $job = Start-ThreadJob -ScriptBlock {
                param ($projectName, $repoName, $org, $pat)

                Import-Module OMG.PSUtilities.AzureDevOps -Force

                $prs = Get-PSUADOPullRequests -Project $projectName -Repository $repoName -Organization $org -PAT $pat
                return $prs
            } -ArgumentList $proj, $repo.name, $Organization, $PAT

            $allJobs += $job

            # Throttle if needed
            while (@($allJobs | Where-Object { $_.State -eq 'Running' }).Count -ge $ThrottleLimit) {
                Start-Sleep -Seconds 1
            }
        }
    }

    # Wait for all jobs to complete or timeout
    $jobTimeout = [datetime]::Now.AddMinutes($TimeoutMinutes)
    while (($allJobs | Where-Object { $_.State -eq 'Running' }).Count -gt 0) {
        if ([datetime]::Now -gt $jobTimeout) {
            Write-Warning "Timeout reached. Stopping remaining jobs."
            $allJobs | Where-Object { $_.State -eq 'Running' } | ForEach-Object { Stop-Job $_ }
            break
        }
        Start-Sleep -Seconds 2
    }

    # Collect results
    foreach ($job in $allJobs) {
        try {
            $output = Receive-Job -Job $job -ErrorAction Stop
            if ($output) {
                foreach ($pr in $output) {
                    $results.Add($pr)
                }
            }
        }
        catch {
            Write-Warning "Job [$($job.Id)] failed: $_"
        }
        finally {
            Remove-Job -Job $job -Force
        }
    }

    Write-Host "Collected $($results.Count) pull requests."

    if ($OutputFilePath) {
        try {
            $results | Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding UTF8
            Write-Host "Saved to: $OutputFilePath"
        }
        catch {
            Write-Warning "Failed to export results to $OutputFilePath : $_"
        }
    }

    $results | ForEach-Object {
        [pscustomobject] @{
            Title        = $_.Title
            CreatedBy    = $_.Createdby.displayname
            CreationDate = $_.Creationdate
            BanchName    = $_.Sourcerefname
            Repository   = $_.Repository.Name
            Desription   = $_.Description
        }
    }
}
