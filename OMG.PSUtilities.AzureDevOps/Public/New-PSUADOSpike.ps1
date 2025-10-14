function New-PSUADOSpike {
    <#
    .SYNOPSIS
        Creates a new spike work item in Azure DevOps.

    .DESCRIPTION
        This function creates a new spike work item in Azure DevOps using the REST API. 
        Spikes are used for research, investigation, or proof-of-concept work where the outcome is knowledge rather than working software.
        Returns the created work item details including the work item ID.

    .PARAMETER Title
        The title of the spike work item.

    .PARAMETER Description
        The detailed description of the spike and what needs to be investigated.

    .PARAMETER TimeBox
        The time-boxed duration for the spike investigation (optional).

    .PARAMETER Priority
        The priority of the spike. Valid values: 1, 2, 3, 4. Default is 2 (optional).

    .PARAMETER StoryPoints
        The story points estimation for the spike (optional).

    .PARAMETER AssignedTo
        The email address of the person to assign the spike to (optional).

    .PARAMETER AreaPath
        The area path for the work item. If not specified, uses the project default (optional).

    .PARAMETER IterationPath
        The iteration path for the work item. If not specified, uses the project default (optional).

    .PARAMETER Tags
        Comma-separated tags to apply to the work item (optional).

    .PARAMETER Project
        The name of the Azure DevOps project.

    .PARAMETER Organization
        The Azure DevOps organization name. Defaults to the ORGANIZATION environment variable (optional).

    .PARAMETER PAT
        Personal Access Token for Azure DevOps authentication. Defaults to the PAT environment variable (optional).

    .EXAMPLE
        New-PSUADOSpike -Title "Research OAuth integration options" -Description "Investigate different OAuth providers for user authentication" -Project "MyProject"

        Creates a basic spike for OAuth research.

    .EXAMPLE
        New-PSUADOSpike -Title "Performance testing spike" -Description "Test database query performance with large datasets" -TimeBox "2 days" -Priority 1 -StoryPoints 3 -AssignedTo "researcher@company.com" -Project "MyProject"

        Creates a detailed spike with time-box and assignment.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date  : 2025-08-11

    .LINK
        https://github.com/lakshmanachari-panuganti
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/create
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter()]
        [string]$TimeBox,

        [Parameter()]
        [ValidateRange(1, 4)]
        [int]$Priority = 2,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$StoryPoints,

        [Parameter()]
        [string]$AssignedTo,

        [Parameter()]
        [string]$AreaPath,

        [Parameter()]
        [string]$IterationPath,

        [Parameter()]
        [string]$Tags,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    process {
        try {
            $headers = Get-PSUAdoAuthHeader -PAT $PAT
            $headers['Content-Type'] = 'application/json-patch+json'

            # Build the work item fields
            $fields = @(
                @{
                    op    = "add"
                    path  = "/fields/System.Title"
                    value = $Title
                },
                @{
                    op    = "add"
                    path  = "/fields/System.Description"
                    value = $Description
                },
                @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.Common.Priority"
                    value = $Priority
                }
            )

            # Add optional fields if provided
            if ($TimeBox) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.Common.TimeCriticality"
                    value = $TimeBox
                }
            }

            if ($StoryPoints) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.Scheduling.StoryPoints"
                    value = $StoryPoints
                }
            }

            if ($AssignedTo) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/System.AssignedTo"
                    value = $AssignedTo
                }
            }

            if ($AreaPath) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/System.AreaPath"
                    value = $AreaPath
                }
            }

            if ($IterationPath) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/System.IterationPath"
                    value = $IterationPath
                }
            }

            if ($Tags) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/System.Tags"
                    value = $Tags
                }
            }

            $body = $fields | ConvertTo-Json -Depth 3
            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            }
            else {
                [uri]::EscapeDataString($Project)
            }
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitems/`$Spike?api-version=7.1-preview.3"

            Write-Verbose "Creating spike in project: $Project"
            Write-Verbose "API URI: $uri"

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $body -ErrorAction Stop

            [PSCustomObject]@{
                Id               = $response.id
                Title            = $response.fields.'System.Title'
                Description      = $response.fields.'System.Description'
                State            = $response.fields.'System.State'
                Priority         = $response.fields.'Microsoft.VSTS.Common.Priority'
                StoryPoints      = $response.fields.'Microsoft.VSTS.Scheduling.StoryPoints'
                TimeBox          = $response.fields.'Microsoft.VSTS.Common.TimeCriticality'
                AssignedTo       = $response.fields.'System.AssignedTo'.displayName
                CreatedDate      = $response.fields.'System.CreatedDate'
                CreatedBy        = $response.fields.'System.CreatedBy'.displayName
                WorkItemType     = $response.fields.'System.WorkItemType'
                AreaPath         = $response.fields.'System.AreaPath'
                IterationPath    = $response.fields.'System.IterationPath'
                Url              = $response.url
                WebUrl           = $response._links.html.href
                PSTypeName       = 'PSU.ADO.Spike'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}