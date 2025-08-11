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
        The full URL of the Azure DevOps pipeline. Use this if you don't know the ID but have the URL.
        The function will extract the pipeline ID automatically.

    .PARAMETER PAT
        Your Azure DevOps Personal Access Token. This is used for authentication to make API calls.

    .PARAMETER Organization
        The name of your Azure DevOps organization (i.e., the part before `.visualstudio.com` or `.dev.azure.com`).

    .PARAMETER Project
        The name of the Azure DevOps project containing the pipeline.

    .EXAMPLE
        Get-PSUADOPipelineLatestRun -PipelineId 2323 -Pat "YourADO PAT" -Organization "YourADOOrgName" -Project "YourADOProjectName"

        This command fetches the latest run for pipeline ID 2323 in the mentioned project under the mentioned organization.

    .EXAMPLE
        Get-PSUADOPipelineLatestRun -PipelineUrl "https://dev.azure.com/myorg/myproject/_build?definitionId=23" -PAT "YourADO PAT" -Organization "YourADOOrgName" -Project "YourADOProjectName"

        This command extracts the pipeline ID from the given URL and fetches the latest run details.

    .EXAMPLE
        Get-PSUADOPipelineLatestRun -PipelineUrl "https://dev.azure.com/myorg/myproject/_build/results?buildId=456&view=results" -PAT "YourADO PAT" -Organization "YourADOOrgName" -Project "YourADOProjectName"

        This command works with build results URLs that contain pipeline information.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date  : 2025-06-16
        Updated: 2025-07-22 - Refactored for better URL parsing, error handling, and variable consistency

    .LINK
        https://github.com/lakshmanachari-panuganti
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(ParameterSetName = 'ById', Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$PipelineId,

        [Parameter(ParameterSetName = 'ByUrl', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PipelineUrl,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION
    )

    process {
        try {
            $headers = Get-PSUAdoAuthHeader -PAT $PAT
            # Handle PipelineId extraction from URL if that is the input set
            if ($PSCmdlet.ParameterSetName -eq 'ByUrl') {
                Write-Verbose "Extracting Pipeline ID from URL: $PipelineUrl"

                # Enhanced URL pattern matching to handle multiple Azure DevOps URL formats
                $patterns = @(
                    'pipelines/(\d+)',                    # New format: /pipelines/123
                    'definitionId=(\d+)',                 # Classic format: ?definitionId=123
                    '_build/results\?buildId=(\d+)',      # Build results: ?buildId=123
                    '_build\?definitionId=(\d+)',         # Direct build: ?definitionId=123
                    'buildId=(\d+)'                       # Simple buildId parameter
                )

                $extractedId = $null
                foreach ($pattern in $patterns) {
                    if ($PipelineUrl -match $pattern) {
                        $extractedId = [int]$matches[1]
                        Write-Verbose "Successfully extracted Pipeline ID: $extractedId using pattern: $pattern"
                        break
                    }
                }

                if (-not $extractedId) {
                    throw "Unable to extract Pipeline ID from URL: $PipelineUrl. Supported formats include pipelines/ID, definitionId=ID, or buildId=ID"
                }

                $PipelineId = $extractedId
            }

            Write-Verbose "Processing Pipeline ID: $PipelineId"
            Write-Verbose "Escaping project name for URL..."
            $escapedProject = [uri]::EscapeDataString($Project)

            # Get top 2 latest runs for fallback logic
            $runUrl = "https://dev.azure.com/$Organization/$escapedProject/_apis/pipelines/$PipelineId/runs" +
            "?`$top=2&api-version=7.1-preview.1"
            Write-Verbose "Calling Azure DevOps API at: $runUrl"

            $response = Invoke-RestMethod -Uri $runUrl -Headers $headers -Method Get -ErrorAction Stop
            $runs = $response.value

            if (-not $runs -or $runs.Count -eq 0) {
                Write-Warning "No runs found for Pipeline ID: $PipelineId"
                return $null
            }

            Write-Verbose "Found $($runs.Count) run(s) for pipeline $PipelineId"
            $latestRun = $runs[0]
            $previousRun = if ($runs.Count -ge 2) { $runs[1] } else { $null }

            # Determine state and result with improved logic
            if ($latestRun.state -eq "inProgress" -or -not $latestRun.result) {
                $state = "inProgress"
                $result = if ($previousRun -and $previousRun.result) {
                    Write-Verbose "Latest run in progress, using previous run result: $($previousRun.result)"
                    $previousRun.result
                }
                else {
                    Write-Verbose "No previous run available, result set to N/A"
                    "N/A"
                }
            }
            else {
                $state = $latestRun.state
                $result = $latestRun.result
            }

            Write-Verbose "Getting detailed build information..."
            $buildParams = @{
                BuildId      = $latestRun.id
                Pat          = $PAT
                Organization = $Organization  # Fixed: was $ORGANIZATION
                Project      = $Project       # Fixed: was $PROJECT
            }

            try {
                $Build = Get-PSUADOPipelineBuild @buildParams
            }
            catch {
                Write-Warning "Could not retrieve detailed build information: $($_.Exception.Message)"
                $Build = [PSCustomObject]@{ TriggeredBy = "Unknown" }
            }

            [PSCustomObject]@{
                PipelineId     = $PipelineId
                BuildId        = $latestRun.id
                State          = $state
                Result         = $result
                StartDate      = if ($latestRun.createdDate) { [datetime]$latestRun.createdDate } else { $null }
                EndDate        = if ($latestRun.finishedDate) { [datetime]$latestRun.finishedDate } else { $null }
                TriggeredBy    = $Build.TriggeredBy
                RunWebUrl      = $latestRun._links.web.href
                Source         = if ($PSCmdlet.ParameterSetName -eq 'ByUrl') { 'ByUrl' } else { 'ById' }
                HasPreviousRun = $null -ne $previousRun
                PSTypeName     = 'PSU.ADO.PipelineRun'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
