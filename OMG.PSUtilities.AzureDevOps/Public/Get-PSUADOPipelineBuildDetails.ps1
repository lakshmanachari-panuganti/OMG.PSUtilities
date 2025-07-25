function Get-PSUADOPipelineBuildDetails {
    <#
    .SYNOPSIS
        Get details about a specific Azure DevOps pipeline build.

    .DESCRIPTION
        This function connects to Azure DevOps using your Personal Access Token (PAT) and fetches information about a particular pipeline build. It returns details like the build ID, pipeline name, when it was queued, its status, result, and a link to view the build in Azure DevOps.

    .PARAMETER BuildId
        The build ID of the pipeline run.

    .PARAMETER Pat
        Your Personal Access Token for Azure DevOps REST API authentication.

    .PARAMETER Organization
        The name of your Azure DevOps organization.

    .PARAMETER Project
        The name of your Azure DevOps project.

    .EXAMPLE
        Get-PSUADOPipelineBuildDetails -BuildId 12345 -Pat 'xxxxxxxxxx' -Organization 'Organizationxyz' -Project 'ProjectZ'

        This example gets details for build ID 12345 in the given organization and project.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date  : 2025-06-16
        Updated: 2025-07-22 - Refactored for better error handling and validation
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Pat,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project
    )
    
    process {
        try {
            Write-Verbose "Processing build ID: $BuildId"
            Write-Verbose "Escaping project name for the URL..."
            $escapedProject = [uri]::EscapeDataString($Project)

            Write-Verbose "Setting up authentication header..."
            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
            $headers = @{ 
                Authorization = "Basic $base64AuthInfo"
                'Content-Type' = 'application/json'
            }

            $buildUrl = "https://dev.azure.com/$Organization/$escapedProject/_apis/build/builds/$BuildId" + 
                       "?api-version=7.1-preview.7"
            Write-Verbose "Calling Azure DevOps API at: $buildUrl"

            $build = Invoke-RestMethod -Uri $buildUrl -Headers $headers -Method Get -ErrorAction Stop

            if (-not $build) {
                throw "No build found with ID: $BuildId"
            }

            [PSCustomObject]@{
                BuildId       = $build.id
                BuildNumber   = $build.buildNumber
                PipelineName  = $build.definition.name
                Status        = $build.status
                Result        = $build.result
                QueueTime     = if ($build.queueTime) { [datetime]$build.queueTime } else { $null }
                StartTime     = if ($build.startTime) { [datetime]$build.startTime } else { $null }
                FinishTime    = if ($build.finishTime) { [datetime]$build.finishTime } else { $null }
                SourceBranch  = $build.sourceBranch
                SourceVersion = $build.sourceVersion
                TriggeredBy   = $build.requestedFor.displayName
                Reason        = $build.reason
                LogsUrl       = $build.logs.url
                WebLink       = $build._links.web.href
                Repository    = $build.repository.name
                RepositoryUrl = $build.repository.url
                PSTypeName    = 'PSU.ADO.BuildDetails'
            }
        }
        catch {
            $errorMessage = "Failed to get build details for Build ID $BuildId`: $($_.Exception.Message)"
            Write-Error $errorMessage
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}