function New-PSUADOTask {
    <#
    .SYNOPSIS
        Creates a new task work item in Azure DevOps and optionally links it to a parent work item.

    .DESCRIPTION
        This function creates a new task work item in Azure DevOps using the REST API.
        It can create standalone tasks or link them to parent work items (User Story, Bug, Spike, etc.) as child work items.
        Returns the created task details including the work item ID and parent relationship.

    .PARAMETER Title
        The title of the task work item.

    .PARAMETER Description
        The detailed description of the task.

    .PARAMETER ParentWorkItemId
        The work item ID of the parent work item (User Story, Bug, Spike, etc.) to link this task to (optional).

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
        (Mandatory) The Azure DevOps project name where the task will be created.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        New-PSUADOTask -Organization "omg" -Project "psutilities" -Title "Setup database schema" -Description "Create initial database tables"

        Creates a standalone task without linking to a parent work item.

    .EXAMPLE
        New-PSUADOTask -Organization "omg" -Project "psutilities" -Title "Implement login API" -Description "Create REST API for user authentication" -ParentWorkItemId 1234 -EstimatedHours 8 -AssignedTo "dev@company.com"

        Creates a task and links it to work item ID 1234 (could be User Story, Bug, or Spike) with estimated hours and assignment.

    .EXAMPLE
        # Create a user story and then add tasks to it
        $userStory = New-PSUADOUserStory -Organization "omg" -Project "psutilities" -Title "User login feature" -Description "Implement secure login"
        New-PSUADOTask -Organization "omg" -Project "psutilities" -Title "Create login form" -Description "Build HTML login form" -ParentWorkItemId $userStory.Id
        New-PSUADOTask -Organization "omg" -Project "psutilities" -Title "Implement authentication" -Description "Add backend auth logic" -ParentWorkItemId $userStory.Id

        Creates a user story and adds two tasks as children.

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
        [int]$ParentWorkItemId,

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
        try {
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
            $headers['Content-Type'] = 'application/json-patch+json'
            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            }
            else {
                [uri]::EscapeDataString($Project)
            }
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

            # Add parent link if specified (works with any work item type)
            if ($ParentWorkItemId) {
                $fields += @{
                    op    = "add"
                    path  = "/relations/-"
                    value = @{
                        rel = "System.LinkTypes.Hierarchy-Reverse"
                        url = "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workItems/$ParentWorkItemId"
                    }
                }
            }

            $body = $fields | ConvertTo-Json -Depth 4
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitems/`$Task?api-version=7.1-preview.3"

            Write-Verbose "Creating task in project: $Project"
            if ($ParentWorkItemId) {
                Write-Verbose "Linking to parent work item ID: $ParentWorkItemId"
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
                ParentId         = $ParentWorkItemId
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
