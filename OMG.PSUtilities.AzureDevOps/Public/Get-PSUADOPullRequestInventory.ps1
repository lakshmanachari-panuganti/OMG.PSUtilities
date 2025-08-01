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

    .OUTPUTS
        [PSCustomObject[]]
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Project = @('Technical Services'),

        [Parameter()]
        [string]$OutputFilePath,

        [Parameter()]
        [int]$ThrottleLimit = 20
    )


    begin {
        Write-Verbose "Starting pull request inventory for organization: $Organization"

        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
        $headers = @{
            Authorization  = "Basic $base64AuthInfo"
            "Content-Type" = "application/json"
            Accept         = "application/json"
        }

        $pullRequests = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
        $jobList = @()
    }

    process {
        try {
            # Get projects
            $projectsUri = "https://dev.azure.com/$Organization/_apis/projects?api-version=7.1-preview.4"
            $projectsResponse = Invoke-RestMethod -Uri $projectsUri -Headers $headers -Method Get -ErrorAction Stop

            $filteredProjects = foreach ($pattern in $Project) {
                $projectsResponse.value | Where-Object { $_.name -like $pattern} 
            }

                if (-not $filteredProjects) {
                    Write-Warning "No matching projects found."
                    return
                }

                foreach ($project in $filteredProjects) {
                    $escapedProject = [uri]::EscapeDataString($project.name)
                    $reposUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories?api-version=7.1-preview.1"
                    $reposResponse = Invoke-RestMethod -Uri $reposUri -Headers $headers -Method Get -ErrorAction Stop

                    foreach ($repo in $reposResponse.value) {
                        # Throttle jobs
                        while ((Get-Job -State Running | Measure-Object).Count -ge $ThrottleLimit) {
                            Start-Sleep -Seconds 1
                        }

                        $job = Start-ThreadJob -ScriptBlock {
                            param (
                                $org, $projName, $escapedProj, $repoId, $repoName, $authHeaders
                            )

                            $result = @()
                            $prsUri = "https://dev.azure.com/$org/$escapedProj/_apis/git/repositories/$repoId/pullrequests?searchCriteria.status=active&api-version=7.1-preview.1"

                            try {
                                $prsResponse = Invoke-RestMethod -Uri $prsUri -Headers $authHeaders -Method Get -ErrorAction Stop
                                foreach ($pr in $prsResponse.value) {
                                    $result += [PSCustomObject]@{
                                        OrganizationName = $org
                                        ProjectName      = $projName
                                        RepositoryName   = $repoName
                                        PullRequestId    = $pr.pullRequestId
                                        Title            = $pr.title
                                        SourceBranch     = ($pr.sourceRefName -replace '^refs/heads/', '')
                                        TargetBranch     = ($pr.targetRefName -replace '^refs/heads/', '')
                                        CreatedBy        = $pr.createdBy.displayName
                                        CreatedDate      = if ($pr.creationDate) { [datetime]$pr.creationDate } else { $null }
                                        Reviewers        = if ($pr.reviewers) { ($pr.reviewers | ForEach-Object { $_.displayName }) -join ', ' } else { '' }
                                        Status           = $pr.status
                                        WebLink          = $pr._links.web.href
                                        PSTypeName       = 'PSU.ADO.PullRequestInventory'
                                    }
                                }
                            }
                            catch {
                                Write-Warning "[$repoName] in [$projName] failed: $($_.Exception.Message)"
                            }

                            return $result
                        } -ArgumentList $Organization, $project.name, $escapedProject, $repo.id, $repo.name, $headers

                        $jobList += $job
                    }
                }

                # Wait for all jobs to complete
                Write-Verbose "Waiting for all jobs to finish..."
                $null = Wait-Job -Job $jobList

                foreach ($job in $jobList) {
                    try {
                        $results = Receive-Job -Job $job -ErrorAction Stop
                        $results | ForEach-Object { $pullRequests.Add($_) }
                    }
                    catch {
                        Write-Warning "Job failed: $($_.Exception.Message)"
                    }
                    finally {
                        Remove-Job -Job $job -Force
                    }
                }

                if ($OutputFilePath) {
                    $ext = [IO.Path]::GetExtension($OutputFilePath).ToLower()
                    Write-Verbose "Exporting results to $OutputFilePath"

                    switch ($ext) {
                        '.csv' { $pullRequests | Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding UTF8 }
                        '.json' { $pullRequests | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFilePath -Encoding UTF8 }
                        '.xml' { $pullRequests | Export-Clixml -Path $OutputFilePath -Encoding UTF8 }
                    }

                    Write-Output "Exported results to: $OutputFilePath"
                }

                return $pullRequests.ToArray()
        }
        catch {
            Write-Error "Fatal error during processing: $($_.Exception.Message)"
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}