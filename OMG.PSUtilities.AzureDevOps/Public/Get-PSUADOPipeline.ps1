<#
.SYNOPSIS
    Retrieves Azure DevOps pipelines for a specified project or by pipeline ID.

.DESCRIPTION
    Connects to the Azure DevOps REST API and fetches pipeline details for the given project.
    Returns key properties including repository name (from API), YAML path, and a clickable web URL.
    Use -AddDetails to fetch additional details for each pipeline (slower).
    You can also retrieve a specific pipeline by its ID.

.PARAMETER Project
    (Mandatory) The Azure DevOps project name containing the pipelines.

.PARAMETER Organization
    (Optional) The Azure DevOps organization name under which the project resides.
    Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

.PARAMETER PAT
    (Optional) Personal Access Token for Azure DevOps authentication.
    Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

.PARAMETER Id
    (Optional) The ID of a specific pipeline to retrieve.
    If not provided, it will fetch all pipelines data in the specified project.

.PARAMETER AddDetails
    (Optional) Switch parameter to include additional details in the output.
    If specified, fetches additional details for each pipeline (may be slower).

.EXAMPLE
    Get-PSUADOPipeline -Organization "omg" -Project "psutilities"

    Retrieves all pipelines from the "psutilities" project.

.EXAMPLE
    Get-PSUADOPipeline -Organization "omg" -Project "psutilities" -Id 1234 -AddDetails

    Retrieves detailed information for pipeline ID 1234.

.OUTPUTS
    [PSCustomObject]

.NOTES
    Author: Lakshmanachari Panuganti
    Created: August 2025

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
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
        [int]$Id,

        [Parameter()]
        [switch]$AddDetails,

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

        $headers = Get-PSUAdoAuthHeader -PAT $PAT
    }

    process {
        try {
            # Escape project name for URI
            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            } else {
                [uri]::EscapeDataString($Project)
            }
            
            if ($Id) {
                $detailsUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/pipelines/$Id`?api-version=7.1-preview.1"
                $pipelineDetails = Invoke-RestMethod -Uri $detailsUri -Headers $headers -Method Get

                if (-not $pipelineDetails) {
                    throw "Failed to retrieve pipeline details for ID: $Id"
                }

                $webUrl = "https://dev.azure.com/$Organization/$escapedProject/_build?definitionId=$Id"

                [PSCustomObject]@{
                    Name           = $pipelineDetails.name
                    ID             = $pipelineDetails.id
                    URL            = $pipelineDetails._links.web.href
                    WebUrl         = $webUrl
                    Folder         = $pipelineDetails.folder
                    YamlPath       = $pipelineDetails.configuration.path
                    RepositoryType = $pipelineDetails.configuration.repository.type
                }
            } else {
                $listUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/pipelines?api-version=7.1-preview.1"
                $pipelineList = Invoke-RestMethod -Uri $listUri -Headers $headers -Method Get

                if (-not $pipelineList.value) {
                    Write-Verbose "No pipelines found."
                    return
                }

                $results = foreach ($pipeline in $pipelineList.value) {
                    $Id = $pipeline.id
                    $webUrl = "https://dev.azure.com/$Organization/$escapedProject/_build?definitionId=$Id"

                    if ($AddDetails) {
                        $detailsUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/pipelines/$Id`?api-version=7.1-preview.1"
                        $pipelineDetails = Invoke-RestMethod -Uri $detailsUri -Headers $headers -Method Get
                        
                        if (-not $pipelineDetails) {
                            Write-Warning "Failed to retrieve details for pipeline ID: $Id"
                            [PSCustomObject]@{
                                Name           = $pipeline.name
                                ID             = $pipeline.id
                                URL            = $pipeline._links.web.href
                                WebUrl         = $webUrl
                                Folder         = $pipeline.folder
                                YamlPath       = "Details unavailable"
                                RepositoryType = "Details unavailable"
                            }
                        } else {
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
                    } else {
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
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
