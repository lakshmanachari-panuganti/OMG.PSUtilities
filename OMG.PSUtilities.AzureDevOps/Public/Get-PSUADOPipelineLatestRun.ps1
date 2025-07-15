function Get-PSUADOPipelineLatestRun {
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(ParameterSetName = 'ById', Mandatory)]
        [int]$PipelineId,

        [Parameter(ParameterSetName = 'ByUrl', Mandatory)]
        [string]$PipelineUrl,

        [Parameter(Mandatory)]
        [string]$Pat,

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
            } else {
                throw "❌ Unable to extract Pipeline ID from URL: $PipelineUrl"
            }
        }

        $escapedProject = [uri]::EscapeDataString($Project)
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
        $headers = @{ Authorization = "Basic $base64AuthInfo" }

        # Get top 2 latest runs
        $runUrl = "https://dev.azure.com/$Organization/$escapedProject/_apis/pipelines/$PipelineId/runs?top=2&api-version=7.1-preview.1"
        $runs = (Invoke-RestMethod -Uri $runUrl -Headers $headers -Method Get -ErrorAction Stop).value

        if (-not $runs) {
            Write-Warning "⚠️ No runs found for Pipeline ID: $PipelineId"
            return
        }

        $latestRun = $runs[0]
        if ($runs.Count -ge 2) { 
            $previousRun = $runs[1] 
        } else { 
            $previousRun = $null 
        }

        if ($latestRun.state -eq "inProgress" -or -not $latestRun.result) {
            if ($previousRun) { 
                $result = $previousRun.result 
            } else { 
                $result = "N/A" 
            }
            $state = "inProgress"
        } else {
            $result = $latestRun.result
            $state = $latestRun.state
        }

        return [PSCustomObject]@{
            PipelineId  = $PipelineId
            RunId       = $latestRun.id
            State       = $state
            Result      = $result
            CreatedDate = $latestRun.createdDate
            RunWebUrl   = $latestRun._links.web.href
            Source      = if ($PSCmdlet.ParameterSetName -eq 'ByUrl') { 'ByUrl' } else { 'ById' }
        }
    }
    catch {
        Write-Error "❌ Failed to get pipeline run details: $_"
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
