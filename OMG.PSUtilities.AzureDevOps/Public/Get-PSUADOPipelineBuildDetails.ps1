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
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            valuefrompipelinebypropertyname)]
        [ValidateNotNullOrEmpty()]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Project
    )
    process {
        try {
            Write-Verbose "Escaping project name for the URL..."
            $escapedProject = [uri]::EscapeDataString($Project)

            Write-Verbose "Setting up authentication header..."
            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
            $headers = @{ Authorization = "Basic $base64AuthInfo" }

            $buildUrl = "https://dev.azure.com/$Organization/$escapedProject/_apis/build/builds/$($BuildId)?api-version=7.1-preview.7"
            Write-Verbose "Calling Azure DevOps API at: $buildUrl"

            $build = Invoke-RestMethod -Uri $buildUrl -Headers $headers -Method Get -ErrorAction Stop

            [PSCustomObject]@{
                BuildId       = $build.id
                BuildNumber   = $build.buildNumber
                PipelineName  = $build.definition.name
                Status        = $build.status
                Result        = $build.result
                QueueTime     = $build.queueTime
                StartTime     = $build.startTime
                FinishTime    = $build.finishTime
                SourceBranch  = $build.sourceBranch
                SourceVersion = $build.sourceVersion
                TriggeredBy   = $build.requestedFor.displayName
                Reason        = $build.reason
                LogsUrl       = $build.logs.url
                WebLink       = $build._links.web.href
                Repository    = $build.repository.name
                RepositoryUrl = $build.repository.url
            }
        }
        catch {
            Write-Error "Couldn't get build details for Build ID $BuildId. $_"
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
