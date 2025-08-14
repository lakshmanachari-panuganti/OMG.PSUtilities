function New-PSUADOTask {
    <#
    .SYNOPSIS
        Creates a new task work item in Azure DevOps and optionally links it to a parent user story.

    .DESCRIPTION
        This function creates a new task work item in Azure DevOps using the REST API.
        It can create standalone tasks or link them to parent user stories as child work items.
        Returns the created task details including the work item ID and parent relationship.

    .PARAMETER Title
        The title of the task work item.

    .PARAMETER Description
        The detailed description of the task.

    .PARAMETER ParentUserStoryId
        The work item ID of the parent user story to link this task to (optional).

    .PARAMETER EstimatedHours
        The estimated hours to complete the task (optional).

    .PARAMETER RemainingHours
        The remaining hours to complete the task (optional).

    .PARAMETER Priority
        The priority of the task. Valid values: 1, 2, 3, 4. Default is 2 (optional).

    .PARAMETER AssignedTo
        The email address of the person to assign the task to (optional).

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
        New-PSUADOTask -Title "Setup database schema" -Description "Create initial database tables" -Project "MyProject"

        Creates a standalone task without linking to a parent user story.

    .EXAMPLE
        New-PSUADOTask -Title "Implement login API" -Description "Create REST API for user authentication" -ParentUserStoryId 1234 -EstimatedHours 8 -AssignedTo "dev@company.com" -Project "MyProject"

        Creates a task and links it to user story ID 1234 with estimated hours and assignment.

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
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ParentUserStoryId,

        [Parameter()]
        [ValidateRange(0.1, 999.9)]
        [decimal]$EstimatedHours,

        [Parameter()]
        [ValidateRange(0, 999.9)]
        [decimal]$RemainingHours,

        [Parameter()]
        [ValidateRange(1, 4)]
        [int]$Priority = 2,

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
            if ($EstimatedHours) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.Scheduling.OriginalEstimate"
                    value = $EstimatedHours
                }
            }

            if ($RemainingHours) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.Scheduling.RemainingWork"
                    value = $RemainingHours
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

            # Add parent link if specified
            if ($ParentUserStoryId) {
                $fields += @{
                    op    = "add"
                    path  = "/relations/-"
                    value = @{
                        rel = "System.LinkTypes.Hierarchy-Reverse"
                        url = "https://dev.azure.com/$Organization/$Project/_apis/wit/workItems/$ParentUserStoryId"
                    }
                }
            }

            $body = $fields | ConvertTo-Json -Depth 4
            $escapedProject = [uri]::EscapeDataString($Project)
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitems/`$Task?api-version=7.1-preview.3"

            Write-Verbose "Creating task in project: $Project"
            if ($ParentUserStoryId) {
                Write-Verbose "Linking to parent user story ID: $ParentUserStoryId"
            }
            Write-Verbose "API URI: $uri"

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $body -ErrorAction Stop

            [PSCustomObject]@{
                Id               = $response.id
                Title            = $response.fields.'System.Title'
                Description      = $response.fields.'System.Description'
                State            = $response.fields.'System.State'
                Priority         = $response.fields.'Microsoft.VSTS.Common.Priority'
                EstimatedHours   = $response.fields.'Microsoft.VSTS.Scheduling.OriginalEstimate'
                RemainingHours   = $response.fields.'Microsoft.VSTS.Scheduling.RemainingWork'
                AssignedTo       = $response.fields.'System.AssignedTo'.displayName
                CreatedDate      = $response.fields.'System.CreatedDate'
                CreatedBy        = $response.fields.'System.CreatedBy'.displayName
                WorkItemType     = $response.fields.'System.WorkItemType'
                AreaPath         = $response.fields.'System.AreaPath'
                IterationPath    = $response.fields.'System.IterationPath'
                ParentId         = $ParentUserStoryId
                Url              = $response.url
                WebUrl           = $response._links.html.href
                PSTypeName       = 'PSU.ADO.Task'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}