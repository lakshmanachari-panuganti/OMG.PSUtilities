function New-PSUADOUserStory {
    <#
    .SYNOPSIS
        Creates a new user story in Azure DevOps.

    .DESCRIPTION
        This function creates a new user story in Azure DevOps using the REST API. 
        It allows you to specify the title, description, acceptance criteria, priority, and other properties.
        Returns the created user story details as follows.
            ID
            Title
            Description
            State
            Priority
            StoryPoints
            AssignedTo
            CreatedDate
            CreatedBy
            WorkItemType
            AreaPath
            IterationPath
            Url
            WebUrl

    .PARAMETER Title
        The title of the user story.

    .PARAMETER Description
        The detailed description of the user story.

    .PARAMETER AcceptanceCriteria
        The acceptance criteria for the user story (optional).

    .PARAMETER Priority
        The priority of the user story. Valid values: 1, 2, 3, 4. Default is 2 (optional).

    .PARAMETER StoryPoints
        The story points estimation for the user story (optional).

    .PARAMETER AssignedTo
        The email address of the person to assign the user story to (optional).

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
        New-PSUADOUserStory -Title "Implement user authentication" -Description "As a user, I want to log in securely" -Project "MyProject"

        Creates a basic user story with title and description.

    .EXAMPLE
        New-PSUADOUserStory -Title "Add search functionality" -Description "Users need to search products" -AcceptanceCriteria "Search returns relevant results" -Priority 1 -StoryPoints 5 -AssignedTo "user@company.com" -Project "MyProject"

        Creates a detailed user story with all properties specified.

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
        [string]$AcceptanceCriteria,

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
            if ($AcceptanceCriteria) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.Common.AcceptanceCriteria"
                    value = $AcceptanceCriteria
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
            $escapedProject = [uri]::EscapeDataString($Project)
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitems/`$User%20Story?api-version=7.1-preview.3"

            Write-Verbose "Creating user story in project: $Project"
            Write-Verbose "API URI: $uri"

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $body -ErrorAction Stop

            [PSCustomObject]@{
                Id               = $response.id
                Title            = $response.fields.'System.Title'
                Description      = $response.fields.'System.Description'
                State            = $response.fields.'System.State'
                Priority         = $response.fields.'Microsoft.VSTS.Common.Priority'
                StoryPoints      = $response.fields.'Microsoft.VSTS.Scheduling.StoryPoints'
                AssignedTo       = $response.fields.'System.AssignedTo'.displayName
                CreatedDate      = $response.fields.'System.CreatedDate'
                CreatedBy        = $response.fields.'System.CreatedBy'.displayName
                WorkItemType     = $response.fields.'System.WorkItemType'
                AreaPath         = $response.fields.'System.AreaPath'
                IterationPath    = $response.fields.'System.IterationPath'
                Url              = $response.url
                WebUrl           = $response._links.html.href
                PSTypeName       = 'PSU.ADO.UserStory'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}