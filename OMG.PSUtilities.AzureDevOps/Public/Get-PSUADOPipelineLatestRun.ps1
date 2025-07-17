function Get-PSUADOPipelineLatestRun {
<#
.SYNOPSIS
    Gets the latest Azure DevOps pipeline run information using pipeline ID or URL.

.DESCRIPTION
    This function retrieves the most recent run (and optionally the second most recent) of a specified Azure DevOps pipeline. 
    You can provide either the pipeline ID directly or a pipeline URL. The function uses a personal access token (PAT) 
    for authentication and returns key details about the run including status, result, and who triggered it.

    - Make sure your PAT has sufficient permissions (at least "Read & execute" for pipelines).
    - If the latest run is still in progress, the function falls back to the previous run's result if available.
    - This function uses Azure DevOps REST API version 7.1-preview.1.

.PARAMETER PipelineId
    The numeric ID of the Azure DevOps pipeline. Use this when you know the pipeline ID directly.

.PARAMETER PipelineUrl
    The full URL of the Azure DevOps pipeline. Use this if you don’t know the ID but have the URL. 
    The function will extract the pipeline ID automatically.

.PARAMETER Pat
    Your Azure DevOps Personal Access Token. This is used for authentication to make API calls.

.PARAMETER Organization
    The name of your Azure DevOps organization (i.e., the part before `.visualstudio.com` or `.dev.azure.com`).

.PARAMETER Project
    The name of the Azure DevOps project containing the pipeline.

.EXAMPLE
    Get-PSUADOPipelineLatestRun -PipelineId 2323 -Pat "YourADO PAT" -Organization "YourADOOrgName" -Project "YourADOProjectName"

    This command fetches the latest run for pipeline ID 2323 in the mentioned project under the mentioned organization.

.EXAMPLE
    Get-PSUADOPipelineLatestRun -PipelineUrl "https://dev.azure.com/myorg/myproject/_build?definitionId=23" -Pat "YourADO PAT" -Organization "YourADOOrgName" -Project "YourADOProjectName"

    This command extracts the pipeline ID from the given URL and fetches the latest run details.

.OUTPUTS
[PSCustomObject] 

.NOTES

Author: Lakshmanachari Panuganti
Date  : 2025-06-16

#>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(ParameterSetName = 'ById', Mandatory)]
        [int]$PipelineId,

        [Parameter(ParameterSetName = 'ByUrl', Mandatory)]
        [string]$PipelineUrl,

        [Parameter(Mandatory)]
        [string]$PAT,

        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Project
    )

    try {
        # Handle PipelineId from URL if that is the input set
        if ($PSCmdlet.ParameterSetName -eq 'ByUrl') {
            if ($PipelineUrl -match "pipelines/(\d+)") {
                $PipelineId = [int]$matches[1]
            }
            else {
                throw "Unable to extract Pipeline ID from URL: $PipelineUrl"
            }
        }

        $escapedProject = [uri]::EscapeDataString($Project)
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
        $headers = @{ Authorization = "Basic $base64AuthInfo" }

        # Get top 2 latest runs
        $runUrl = "https://dev.azure.com/$Organization/$escapedProject/_apis/pipelines/$PipelineId/runs?top=2&api-version=7.1-preview.1"
        $runs = (Invoke-RestMethod -Uri $runUrl -Headers $headers -Method Get -ErrorAction Stop).value

        if (-not $runs) {
            Write-Warning "No runs found for Pipeline ID: $PipelineId"
            return
        }

        $latestRun = $runs[0]
        if ($runs.Count -ge 2) { 
            $previousRun = $runs[1] 
        }
        else { 
            $previousRun = $null 
        }

        if ($latestRun.state -eq "inProgress" -or -not $latestRun.result) {
            if ($previousRun) { 
                $result = $previousRun.result 
            }
            else { 
                $result = "N/A" 
            }
            $state = "inProgress"
        }
        else {
            $result = $latestRun.result
            $state = $latestRun.state
        }
        $buildParams = @{
            BuildId      = $latestRun.id
            Pat          = $PAT
            Organization = $ORGANIZATION
            Project      = $PROJECT
        }
        $Build = Get-PSUADOPipelineBuildDetails @buildParams
        return [PSCustomObject]@{
            PipelineId  = $PipelineId
            BuildId     = $latestRun.id
            State       = $state
            Result      = $result
            StartDate   = $latestRun.createdDate
            EndDate     = $latestRun.finishedDate
            TriggeredBy = $Build.TriggeredBy
            RunWebUrl   = $latestRun._links.web.href
            Source      = if ($PSCmdlet.ParameterSetName -eq 'ByUrl') { 'ByUrl' } else { 'ById' }
        }
    }
    catch {
        Write-Error "Failed to get pipeline run details:"
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
