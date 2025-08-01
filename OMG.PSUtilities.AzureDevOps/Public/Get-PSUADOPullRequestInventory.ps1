function Get-PSUADOPullRequestInventory {
    <#
    .SYNOPSIS
        Retrieves active pull requests across specified Azure DevOps projects using parallel jobs.

    .DESCRIPTION
        Connects to Azure DevOps using PAT and fetches metadata for active pull requests across repositories.
        Uses Start-ThreadJob with configurable throttling for performance.

    .PARAMETER Organization
        Your Azure DevOps organization name.

    .PARAMETER PAT
        Personal Access Token (PAT) with read access to code & projects.

    .PARAMETER Project
        Wildcard patterns to filter projects. Default: '*' (all projects).

    .PARAMETER OutputFilePath
        Optional file path to export results (.csv, .json, .xml).

    .PARAMETER ThrottleLimit
        Max number of parallel threads. Default: 20.

    .PARAMETER TimeoutMinutes
        Timeout in minutes for job completion. Default: 10.

    .PARAMETER WhatIf
        Shows what would be processed without actually executing.

    .OUTPUTS
        [PSCustomObject[]]
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if ($_ -match '^[a-zA-Z0-9-_]+$') { return $true }
            throw "Organization name contains invalid characters. Use only letters, numbers, hyphens, and underscores."
        })]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Project = @('*'),

        [Parameter()]
        [ValidateScript({
            $ext = [IO.Path]::GetExtension($_).ToLower()
            if ($ext -notin @('.csv', '.json', '.xml')) {
                throw "OutputFilePath must have .csv, .json, or .xml extension"
            }
            return $true
        })]
        [string]$OutputFilePath,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]$ThrottleLimit = 20,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$TimeoutMinutes = 10
    )

    begin {
        Write-Verbose "Initializing Azure DevOps pull request inventory..."

        # Validate required parameters
        if ([string]::IsNullOrWhiteSpace($Organization)) {
            throw "Organization parameter is required. Set via parameter or ORGANIZATION environment variable."
        }
        if ([string]::IsNullOrWhiteSpace($PAT)) {
            throw "PAT parameter is required. Set via parameter or PAT environment variable."
        }

        $authToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
        $headers = @{
            Authorization = "Basic $authToken"
            Accept        = "application/json"
        }

        $pullRequests = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
        $jobList = @()
    }

    process {
        try {
            # Get all projects
            Write-Verbose "Fetching projects from organization: $Organization"
            $projectsUri = "https://dev.azure.com/$Organization/_apis/projects?api-version=7.1-preview.4"
            
            if ($PSCmdlet.ShouldProcess("$Organization", "Fetch project list")) {
                $projectsResponse = Invoke-RestMethod -Uri $projectsUri -Headers $headers -Method Get -ErrorAction Stop
            } else {
                Write-Host "WhatIf: Would fetch projects from $projectsUri"
                return
            }

            # Match project patterns and deduplicate
            Write-Verbose "Filtering projects with patterns: $($Project -join ', ')"
            $matchedProjects = @()
            
            # Debug: Check for projects with null/empty names
            $emptyNameProjects = $projectsResponse.value | Where-Object { -not $_.name -or $_.name.Trim() -eq '' }
            if ($emptyNameProjects) {
                Write-Warning "Found $($emptyNameProjects.Count) projects with empty names. These will be skipped."
                foreach ($emptyProj in $emptyNameProjects) {
                    Write-Verbose "Skipping project with empty name - ID: $($emptyProj.id), State: $($emptyProj.state)"
                }
            }
            
            foreach ($pattern in $Project) {
                $matchedProjects += $projectsResponse.value | Where-Object { 
                    $_.name -and 
                    $_.name.Trim() -ne '' -and 
                    $_.name -like $pattern -and
                    $_.state -eq 'wellFormed'
                }
            }
            
            $filteredProjects = $matchedProjects | Sort-Object id -Unique
            
            Write-Verbose "After filtering: $($filteredProjects.Count) projects remain"

            if (-not $filteredProjects) {
                Write-Warning "No matching projects found for patterns: $($Project -join ', ')"
                return @()
            }

            Write-Host "Found $($filteredProjects.Count) matching projects" -ForegroundColor Green

            # Count total repositories for progress tracking
            Write-Verbose "Calculating total repositories across $($filteredProjects.Count) projects..."
            $totalRepos = 0
            $projectRepoData = @{}
            
            foreach ($project in $filteredProjects) {
                # Double-check project name safety
                if (-not $project -or -not $project.name -or $project.name.Trim() -eq '') {
                    Write-Warning "Skipping invalid project object during repository counting"
                    continue
                }

                $projectName = $project.name.Trim()
                Write-Verbose "Processing project: '$projectName' (ID: $($project.id))"
                
                try {
                    $escapedProject = [uri]::EscapeDataString($projectName)
                    $reposUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories?api-version=7.1-preview.1"
                    
                    $reposResponse = Invoke-RestMethod -Uri $reposUri -Headers $headers -Method Get -ErrorAction Stop
                    $repoCount = if ($reposResponse.value) { $reposResponse.value.Count } else { 0 }
                    
                    # Use a safe key for the hashtable
                    $safeKey = if ($projectName) { $projectName } else { "Unknown_$($project.id)" }
                    
                    $projectRepoData[$safeKey] = @{
                        Count = $repoCount
                        Repositories = if ($reposResponse.value) { $reposResponse.value } else { @() }
                        ProjectObject = $project
                        ProjectName = $projectName
                    }
                    $totalRepos += $repoCount
                    Write-Verbose "Project '$projectName': $repoCount repositories"
                }
                catch {
                    Write-Warning "Failed to get repositories for project '$projectName': $($_.Exception.Message)"
                    $safeKey = if ($projectName) { $projectName } else { "Error_$($project.id)" }
                    
                    $projectRepoData[$safeKey] = @{
                        Count = 0
                        Repositories = @()
                        ProjectObject = $project
                        ProjectName = $projectName
                    }
                }
            }
            
            Write-Host "Total repositories to process: $totalRepos across $($filteredProjects.Count) projects" -ForegroundColor Green

            if ($totalRepos -eq 0) {
                Write-Warning "No repositories found in any projects."
                return @()
            }

            # Process each project and repository
            $processedRepos = 0
            foreach ($projectKey in $projectRepoData.Keys) {
                $projectData = $projectRepoData[$projectKey]
                $projectName = $projectData.ProjectName
                $projectRepos = $projectData.Repositories
                
                # Skip if project name is still invalid
                if (-not $projectName -or $projectName.Trim() -eq '') {
                    Write-Warning "Skipping project with invalid name (Key: $projectKey)"
                    continue
                }
                
                if ($projectRepos.Count -eq 0) {
                    Write-Verbose "Skipping project '$projectName' - no repositories found"
                    continue
                }

                Write-Host "`nProcessing project: '$projectName' ($($projectRepos.Count) repositories)" -ForegroundColor Yellow

                foreach ($repo in $projectRepos) {
                    # Skip repositories with empty names
                    if (-not $repo -or -not $repo.name -or $repo.name.Trim() -eq '') {
                        Write-Warning "Skipping repository with empty name in project '$projectName'"
                        $processedRepos++  # Still increment to keep count accurate
                        continue
                    }

                    # Throttle jobs
                    while ((Get-Job -State Running).Count -ge $ThrottleLimit) {
                        Start-Sleep -Milliseconds 500
                    }

                    # Update progress
                    $processedRepos++
                    $progressParams = @{
                        Activity        = "Processing Azure DevOps Repositories"
                        Status          = "Repository '$($repo.name)' in project '$projectName' ($processedRepos of $totalRepos)"
                        PercentComplete = if ($totalRepos -gt 0) { [math]::Min(100, ($processedRepos / $totalRepos) * 100) } else { 0 }
                    }
                    Write-Progress @progressParams

                    if ($PSCmdlet.ShouldProcess("$projectName/$($repo.name)", "Fetch pull requests")) {
                        Write-Host "  Processing repository '$($repo.name)' [$processedRepos/$totalRepos]" -ForegroundColor Cyan

                        $job = Start-ThreadJob -ScriptBlock {
                            param (
                                $org, $projName, $repoId, $repoName, $token
                            )
                            
                            $localHeaders = @{
                                Authorization = "Basic $token"
                                Accept        = "application/json"
                            }

                            $results = @()
                            
                            # Add small random delay to avoid overwhelming the API
                            Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 500)
                            
                            try {
                                $escapedProject = [uri]::EscapeDataString($projName)
                                $prsUri = "https://dev.azure.com/$org/$escapedProject/_apis/git/repositories/$repoId/pullrequests?searchCriteria.status=active&api-version=7.1-preview.1"
                                $prsResponse = Invoke-RestMethod -Uri $prsUri -Headers $localHeaders -Method Get -ErrorAction Stop

                                foreach ($pr in $prsResponse.value) {
                                    $results += [PSCustomObject]@{
                                        OrganizationName = $org
                                        ProjectName      = $projName
                                        RepositoryName   = $repoName
                                        PullRequestId    = $pr.pullRequestId
                                        Title            = $pr.title
                                        SourceBranch     = ($pr.sourceRefName -replace '^refs/heads/', '')
                                        TargetBranch     = ($pr.targetRefName -replace '^refs/heads/', '')
                                        CreatedBy        = $pr.createdBy.displayName
                                        CreatedDate      = [datetime]$pr.creationDate
                                        Reviewers        = if ($pr.reviewers) { ($pr.reviewers | ForEach-Object { $_.displayName }) -join ', ' } else { '' }
                                        Status           = $pr.status
                                        WebLink          = $pr._links.web.href
                                        IsError          = $false
                                        ErrorMessage     = $null
                                        PSTypeName       = 'PSU.ADO.PullRequestInventory'
                                    }
                                }
                                
                                # If no PRs found, still return a record for tracking
                                if ($prsResponse.value.Count -eq 0) {
                                    $results += [PSCustomObject]@{
                                        OrganizationName = $org
                                        ProjectName      = $projName
                                        RepositoryName   = $repoName
                                        PullRequestId    = $null
                                        Title            = "No active pull requests"
                                        SourceBranch     = $null
                                        TargetBranch     = $null
                                        CreatedBy        = $null
                                        CreatedDate      = $null
                                        Reviewers        = $null
                                        Status           = "None"
                                        WebLink          = $null
                                        IsError          = $false
                                        ErrorMessage     = $null
                                        PSTypeName       = 'PSU.ADO.PullRequestInventory'
                                    }
                                }
                            }
                            catch {
                                $results += [PSCustomObject]@{
                                    OrganizationName = $org
                                    ProjectName      = $projName
                                    RepositoryName   = $repoName
                                    PullRequestId    = $null
                                    Title            = "ERROR"
                                    SourceBranch     = $null
                                    TargetBranch     = $null
                                    CreatedBy        = $null
                                    CreatedDate      = $null
                                    Reviewers        = $null
                                    Status           = "Error"
                                    WebLink          = $null
                                    IsError          = $true
                                    ErrorMessage     = $_.Exception.Message
                                    PSTypeName       = 'PSU.ADO.PullRequestInventory.Error'
                                }
                            }

                            return $results
                        } -ArgumentList $Organization, $projectName, $repo.id, $repo.name, $authToken

                        $jobList += $job
                    } else {
                        Write-Host "  WhatIf: Would process repository '$($repo.name)' [$processedRepos/$totalRepos]" -ForegroundColor Gray
                    }
                }
            }

            if ($jobList.Count -eq 0) {
                Write-Warning "No jobs were created. Check your parameters and permissions."
                return @()
            }

            # Wait for jobs to complete with timeout
            Write-Verbose "Waiting for $($jobList.Count) jobs to complete (timeout: $TimeoutMinutes minutes)..."
            Write-Progress -Activity "Processing Azure DevOps Repositories" -Status "Waiting for jobs to complete..." -PercentComplete 100
            
            try {
                $timeoutSeconds = $TimeoutMinutes * 60
                $waitResult = Wait-Job -Job $jobList -Timeout $timeoutSeconds
                
                # Check for jobs that didn't complete
                $runningJobs = $jobList | Where-Object { $_.State -eq 'Running' }
                if ($runningJobs) {
                    Write-Warning "Stopping $($runningJobs.Count) jobs that didn't complete within $TimeoutMinutes minutes"
                    $runningJobs | Stop-Job -ErrorAction SilentlyContinue
                }
                
                $completedJobs = $jobList | Where-Object { $_.State -eq 'Completed' }
                $failedJobs = $jobList | Where-Object { $_.State -eq 'Failed' }
                
                Write-Host "Job Summary: $($completedJobs.Count) completed, $($failedJobs.Count) failed, $($runningJobs.Count) timed out" -ForegroundColor Yellow
            }
            finally {
                Write-Progress -Activity "Processing Azure DevOps Repositories" -Completed
            }

            # Gather results from completed jobs
            $successCount = 0
            $errorCount = 0
            
            foreach ($job in $jobList) {
                try {
                    if ($job.State -eq 'Completed') {
                        $results = Receive-Job -Job $job -ErrorAction Stop
                        foreach ($item in $results) {
                            $pullRequests.Add($item)
                            if ($item.IsError) {
                                $errorCount++
                            } else {
                                $successCount++
                            }
                        }
                    } elseif ($job.State -eq 'Failed') {
                        $errorInfo = Receive-Job -Job $job -ErrorAction SilentlyContinue
                        Write-Warning "Job failed: $($job.Name) - $($errorInfo -join '; ')"
                        $errorCount++
                    }
                }
                catch {
                    Write-Warning "Failed to receive job results: $($_.Exception.Message)"
                    $errorCount++
                }
                finally {
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                }
            }

            $finalResults = $pullRequests.ToArray()
            Write-Host "Processing complete: $successCount successful, $errorCount errors" -ForegroundColor Green

            # Export results if requested
            if ($OutputFilePath -and $finalResults.Count -gt 0) {
                $ext = [IO.Path]::GetExtension($OutputFilePath).ToLower()
                Write-Verbose "Exporting $($finalResults.Count) results to $OutputFilePath"

                # Ensure output directory exists
                $outputDir = [IO.Path]::GetDirectoryName($OutputFilePath)
                if ($outputDir -and -not (Test-Path $outputDir)) {
                    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
                }

                try {
                    switch ($ext) {
                        '.csv'  { 
                            $finalResults | Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding UTF8 
                        }
                        '.json' { 
                            $finalResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFilePath -Encoding UTF8 
                        }
                        '.xml'  { 
                            $finalResults | Export-Clixml -Path $OutputFilePath -Encoding UTF8 
                        }
                    }
                    Write-Host "Exported $($finalResults.Count) results to: $OutputFilePath" -ForegroundColor Green
                }
                catch {
                    Write-Error "Failed to export results: $($_.Exception.Message)"
                }
            }

            return $finalResults
        }
        catch {
            # Clean up any remaining jobs on error
            if ($jobList) {
                Write-Verbose "Cleaning up $($jobList.Count) jobs due to error..."
                $jobList | Remove-Job -Force -ErrorAction SilentlyContinue
            }
            
            Write-Error "Fatal error during processing: $($_.Exception.Message)"
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}