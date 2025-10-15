function Get-PSUADOPullRequestInventory {
    <#
    .SYNOPSIS
        Retrieves all active pull requests from accessible Azure DevOps repositories across all projects in the organization.

    .DESCRIPTION
        This function loops through each project in the specified Azure DevOps organization, retrieves repositories from each project,
        and then gathers all active pull requests from each repository. Results are returned as a flattened array of pull request objects.
        Permission errors are handled gracefully to skip projects the user cannot access.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the projects reside.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        $PRInventory = Get-PSUADOPullRequestInventory -Organization "omg"

        Retrieves all active pull requests across all repositories and projects under the "omg" organization.

    .OUTPUTS
        System.Object[] 

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2 August 2025 - Initial development

    .LINK
        https://github.com/lakshmanachari-panuganti
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    begin {
        # Display parameters
        Write-Verbose "Parameters:"
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            if ($param.Key -eq 'PAT') {
                $maskedPAT = if ($param.Value -and $param.Value.Length -ge 3) { $param.Value.Substring(0, 3) + "********" } else { "***" }
                Write-Verbose "  $($param.Key): $maskedPAT"
            } else {
                Write-Verbose "  $($param.Key): $($param.Value)"
            }
        }

        # Validate Organization (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
        if (-not $Organization) {
            throw "The default value for the 'ORGANIZATION' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>' or provide via -Organization parameter."
        }

        # Validate PAT (required because ValidateNotNullOrEmpty doesn't check default values from environment variables)
        if (-not $PAT) {
            throw "The default value for the 'PAT' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<pat>' or provide via -PAT parameter."
        }
    }

    process {
        $PullRequests = [System.Collections.Generic.List[PSCustomObject]]::new()
        Write-Verbose "Fetching project list for organization [$Organization]..."
        $ProjectList = Get-PSUADOProjectList -Organization $Organization -PAT $PAT
    
        $projectCount = $ProjectList.Count
        $projectIndex = 0

        foreach ($project in $ProjectList) {
            $projectIndex++
            $progressActivity = "Processing project [$($project.Name)] ($projectIndex of $projectCount)"
            Write-Progress -Activity $progressActivity -Status "Fetching repositories..." -PercentComplete (($projectIndex / $projectCount) * 100)

            try {
                Write-Verbose "Fetching repositories for project [$($project.Name)]..."
                $Repositories = Get-PSUADORepositories -Project $project.Name -Organization $Organization -PAT $PAT
                Write-Verbose "[$($Repositories.Count)] repositories found in [$($project.Name)]"

                $repoCount = $Repositories.Count
                $repoIndex = 0

                foreach ($Repository in $Repositories) {
                    $repoIndex++
                    Write-Progress -Activity $progressActivity -Status "Fetching PRs from repo [$($Repository.name)] ($repoIndex of $repoCount)" -PercentComplete (($repoIndex / $repoCount) * 100)

                    $prs = Get-PSUADOPullRequest -RepositoryId $Repository.id -Project $project.Name -Organization $Organization -PAT $PAT   
                    foreach ($pr in $prs) {
                        $PullRequests.Add($pr)
                    }
                }

            } catch {
                $exceptionMessage = $_.Exception.Message
                if ($exceptionMessage -notlike "*you do not have permissions*") {
                    $PSCmdlet.ThrowTerminatingError($_)
                } else {
                    Write-Warning "Skipped project [$($project.Name)] due to insufficient permissions."
                }
            }
        }
    } # End of process block
    
    end {
        Write-Verbose "Completed pull request inventory collection."
        $PullRequests.ToArray() | Select-Object *
    }
}