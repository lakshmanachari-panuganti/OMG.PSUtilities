function Get-PSUADOVariableGroup {
<#
.SYNOPSIS
    Retrieves Azure DevOps Variable Groups for a specified project, or by Variable Group ID or Name.

.DESCRIPTION
    Connects to the Azure DevOps REST API and retrieves Variable Group details.
    The returned objects are designed to be directly piped into Set-PSUADOVariableGroup
    for safe updates of metadata and variable configurations.

.PARAMETER Project
    (Mandatory) The Azure DevOps project name containing the variable groups.

.PARAMETER Organization
    (Optional) Azure DevOps organization name.
    Defaults to the value of the ORGANIZATION environment variable.

.PARAMETER PAT
    (Optional) Personal Access Token (PAT) for Azure DevOps authentication.
    Defaults to the value of the PAT environment variable.

.PARAMETER Id
    (Optional) Variable Group ID to retrieve.
    When specified, retrieves a single Variable Group.

.PARAMETER Name
    (Optional) Variable Group name to retrieve.
    When specified, filters Variable Groups by name.

.EXAMPLE
    Get-PSUADOVariableGroup -Project "EnterpriseData"

.EXAMPLE
    Get-PSUADOVariableGroup -Project "EnterpriseData" -Name "APPSettings"

.EXAMPLE
    Get-PSUADOVariableGroup -Project "EnterpriseData" -Id 12

.OUTPUTS
    [PSCustomObject]

.NOTES
    Author  : Lakshmanachari Panuganti
    Created : 23 Dec 2025

.LINK
    https://www.github.com/lakshmanachari-panuganti
    https://www.linkedin.com/in/lakshmanachari-panuganti
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    Install-Module -Name OMG.PSUtilities.AzureDevOps -Repository PSGallery
    https://learn.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/list
#>

    [CmdletBinding(DefaultParameterSetName = 'ByProject')]
    param (
        [Parameter(
            Mandatory,
            ParameterSetName = 'ByProject'
        )]
        [Parameter(
            Mandatory,
            ParameterSetName = 'ById'
        )]
        [Parameter(
            Mandatory,
            ParameterSetName = 'ByName'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(
            Mandatory,
            ParameterSetName = 'ById'
        )]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Id,

        [Parameter(
            Mandatory,
            ParameterSetName = 'ByName'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    begin {
        if (-not $Organization) {
            throw "The 'ORGANIZATION' environment variable is not set."
        }

        if (-not $PAT) {
            throw "The 'PAT' environment variable is not set."
        }

        $headers = Get-PSUAdoAuthHeader -PAT $PAT
    }

    process {
        try {
            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            } else {
                [uri]::EscapeDataString($Project)
            }

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/distributedtask/variablegroups/$Id?api-version=7.1-preview.2"
                $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
                $groups = @($response)
            }
            else {
                $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
                $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
                $groups = $response.value
            }

            foreach ($vg in $groups) {

                if ($PSCmdlet.ParameterSetName -eq 'ByName' -and $vg.name -ne $Name) {
                    continue
                }

                [PSCustomObject]@{
                    Name         = $vg.name
                    Id           = $vg.id
                    Description  = $vg.description
                    Type         = $vg.type

                    # Required for Set-PSUADOVariableGroup
                    Project      = $Project
                    Organization = $Organization
                    Variables    = $vg.variables

                    VariableCount = $vg.variables.Count
                    IsShared      = $vg.isShared
                    CreatedBy     = $vg.createdBy.displayName
                    CreatedOn     = $vg.createdOn
                    ModifiedBy    = $vg.modifiedBy.displayName
                    ModifiedOn    = $vg.modifiedOn
                }
            }

        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
