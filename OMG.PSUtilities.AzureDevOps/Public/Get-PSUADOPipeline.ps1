<#
.SYNOPSIS
    Retrieves Azure DevOps pipelines for a specified project or by pipeline ID.

.DESCRIPTION
    Connects to the Azure DevOps REST API and fetches pipeline details for the given project.
    Returns key properties including repository name (from API), YAML path, and a clickable web URL.
    Use -AddDetails to fetch additional details for each pipeline (slower).
    You can also retrieve a specific pipeline by its ID.

.PARAMETER Organization
    The Azure DevOps organization name.

.PARAMETER Project
    The Azure DevOps project name.

.PARAMETER PAT
    Personal Access Token for Azure DevOps authentication.

.PARAMETER Id
    The ID of a specific pipeline to retrieve.

.PARAMETER AddDetails
    If specified, fetches additional details for each pipeline (may be slower).

.EXAMPLE
    Get-PSUADOPipeline -Organization "OmgITSolutions" -Project "PSUtilities" -PAT $env:PAT

.EXAMPLE
    Get-PSUADOPipeline -Organization "OmgITSolutions" -Project "PSUtilities" -PAT $env:PAT -Id 1234 -AddDetails

.OUTPUTS
    [PSCustomObject]

.NOTES
    Author: Lakshmanachari Panuganti
    Created: August 2025

.LINK
    https://github.com/lakshmanachari-panuganti
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    https://learn.microsoft.com/en-us/rest/api/azure/devops/pipelines/pipelines/list
#>
function Get-PSUADOPipeline {
    [CmdletBinding(DefaultParameterSetName = 'ByProject')]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$Id,

        [Parameter()]
        [switch]$AddDetails
    )

    $headers = Get-PSUAdoAuthHeader -PAT $PAT

    try {
        if ($Id) {
            $detailsUri = "https://dev.azure.com/$Organization/$Project/_apis/pipelines/$Id`?api-version=7.1-preview.1"
            $pipelineDetails = Invoke-RestMethod -Uri $detailsUri -Headers $headers -Method Get

            $webUrl = "https://dev.azure.com/$Organization/$Project/_build?definitionId=$Id"

            [PSCustomObject]@{
                Name           = $pipelineDetails.name
                ID             = $pipelineDetails.id
                URL            = $pipelineDetails._links.web.href
                WebUrl         = $webUrl
                Folder         = $pipelineDetails.folder
                YamlPath       = $pipelineDetails.configuration.path
                RepositoryType = $pipelineDetails.configuration.repository.type
            }
        }
        else {
            $listUri = "https://dev.azure.com/$Organization/$Project/_apis/pipelines?api-version=7.1-preview.1"
            $pipelineList = Invoke-RestMethod -Uri $listUri -Headers $headers -Method Get

            if (-not $pipelineList.value) {
                Write-Verbose "No pipelines found."
                return
            }

            $results = foreach ($pipeline in $pipelineList.value) {
                $Id = $pipeline.id
                $webUrl = "https://dev.azure.com/$Organization/$Project/_build?definitionId=$Id"

                if ($AddDetails) {
                    $detailsUri = "https://dev.azure.com/$Organization/$Project/_apis/pipelines/$Id`?api-version=7.1-preview.1"
                    $pipelineDetails = Invoke-RestMethod -Uri $detailsUri -Headers $headers -Method Get

                    [PSCustomObject]@{
                        Name           = $pipeline.name
                        ID             = $pipeline.id
                        URL            = $pipeline._links.web.href
                        WebUrl         = $webUrl
                        Folder         = $pipeline.folder
                        YamlPath       = $pipelineDetails.configuration.path
                        RepositoryType = $pipelineDetails.configuration.repository.type
                    }
                }
                else {
                    [PSCustomObject]@{
                        Name   = $pipeline.name
                        ID     = $pipeline.id
                        URL    = $pipeline._links.web.href
                        WebUrl = $webUrl
                        Folder = $pipeline.folder
                    }
                }
            }

            return $results
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
