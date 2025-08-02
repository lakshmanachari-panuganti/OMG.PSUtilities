function Get-PSUADOPullRequestInventory {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT,

        [Parameter()]
        [string[]]$Project,

        [Parameter()]
        [string]$OutputFilePath,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]$ThrottleLimit = 20,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$TimeoutMinutes = 10
    )

    begin {
        Write-Host "Fetching projects for organization '$Organization'..." -ForegroundColor Cyan

        if (-not $Project) {
            $Project = (Get-PSUADOProjectList -Organization $Organization -PAT $PAT).Name
        }

        Write-Host "Processing repositories across $($Project.Count) projects..." -ForegroundColor Yellow

        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        $allParallelResults = $Project | ForEach-Object -Parallel {
            param (
                [string]$ProjectName,
                [string]$Organization,
                [string]$PAT
            )

            $repoResults = @()
            try {
                $repos = Get-PSUADORepositories -Project $ProjectName -Organization $Organization -PAT $PAT
                foreach ($repo in $repos) {
                    try {
                        $prs = Get-PSUADOPullRequests -Project $ProjectName -RepositoryId $repo.Id -Organization $Organization -PAT $PAT
                        foreach ($pr in $prs) {
                            $repoResults += [PSCustomObject]@{
                                Project       = $ProjectName
                                Repository    = $repo.Name
                                PullRequestId = $pr.PullRequestId
                                Title         = $pr.Title
                                CreatedBy     = $pr.CreatedBy.displayName
                                CreatedDate   = $pr.CreationDate
                                SourceBranch  = $pr.SourceRefName
                                TargetBranch  = $pr.TargetRefName
                                Status        = $pr.Status
                                Url           = $pr.Url
                            }
                        }
                    }
                    catch {
                        Write-Error "❌ Failed to get PRs for repo '$($repo.Name)' in project '$ProjectName': $_"
                    }
                }
            }
            catch {
                Write-Error "❌ Failed to get repositories for project '$ProjectName': $_"
            }

            return $repoResults
        } -ArgumentList { $_ }, $Organization, $PAT -ThrottleLimit $ThrottleLimit

        foreach ($item in $allParallelResults) {
            $results.Add($item)
        }
    }

    end {
        if ($OutputFilePath) {
            try {
                $results | Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding UTF8
                Write-Host "✅ Pull request inventory exported to: $OutputFilePath" -ForegroundColor Green
            }
            catch {
                Write-Error "❌ Failed to export results to CSV: $_"
            }
        }

        return $results
    }
}
