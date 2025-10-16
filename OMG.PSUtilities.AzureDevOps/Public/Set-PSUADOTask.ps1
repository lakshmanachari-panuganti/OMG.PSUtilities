function Set-PSUADOTask {
    <#
    .SYNOPSIS
        Updates an existing task in Azure DevOps.

    .DESCRIPTION
        This function updates an existing task in Azure DevOps using the REST API.
        It allows you to modify title, description, state, priority, remaining work, assignments,
        area path, iteration path, and tags.

        Requires: Azure DevOps PAT with work item write permissions

    .PARAMETER Id
        (Mandatory) The ID of the task to update.

    .PARAMETER Title
        (Optional) The new title for the task.

    .PARAMETER Description
        (Optional) The new description for the task.

    .PARAMETER State
        (Optional) The state of the task.
        Common values: 'To Do', 'In Progress', 'Done', 'Removed'.

    .PARAMETER Priority
        (Optional) The priority of the task. Valid values: 1, 2, 3, 4.

    .PARAMETER RemainingWork
        (Optional) The remaining work in hours for the task.

    .PARAMETER Activity
        (Optional) The activity type for the task.
        Common values: 'Development', 'Testing', 'Documentation', 'Design', 'Deployment', 'Requirements'.

    .PARAMETER AssignedTo
        (Optional) The email address or display name of the person to assign the task to.

    .PARAMETER AreaPath
        (Optional) The area path for the work item.

    .PARAMETER IterationPath
        (Optional) The iteration path for the work item.

    .PARAMETER Tags
        (Optional) Comma-separated tags to apply to the work item.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing the work item.

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        Set-PSUADOTask -Organization "omg" -Project "psutilities" -Id 12345 -State "In Progress" -RemainingWork 4

        Updates the state and remaining work of task 12345.

    .EXAMPLE
        Set-PSUADOTask -Organization "omg" -Project "psutilities" -Id 12345 -Title "Updated Task Title" -Activity "Development" -AssignedTo "user@company.com"

        Updates multiple properties of the task.

    .EXAMPLE
        Set-PSUADOTask -Organization "omg" -Project "psutilities" -Id 12345 -State "Done" -RemainingWork 0

        Marks a task as done.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 15th October 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://learn.microsoft.com/en-us/rest/api/azure/devops
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]$Id,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [ValidateSet('New', 'Active', 'To Do', 'In Progress', 'Done', 'Removed', 'Closed', 'Resolved', 'Approved', 'Committed')]
        [string]$State,

        [Parameter()]
        [ValidateRange(1, 4)]
        [int]$Priority,

        [Parameter()]
        [ValidateRange(0, 1000)]
        [double]$RemainingWork,

        [Parameter()]
        [ValidateSet('Development', 'Testing', 'Documentation', 'Design', 'Deployment', 'Requirements')]
        [string]$Activity,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$AssignedTo,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$AreaPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$IterationPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
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
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Parameters:"
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
    }
    process {
        try {

            # Build the patch document
            $patchDocument = @()

            if ($PSBoundParameters.ContainsKey('Title')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/System.Title'
                    value = $Title
                }
            }

            if ($PSBoundParameters.ContainsKey('Description')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/System.Description'
                    value = $Description
                }
            }

            if ($PSBoundParameters.ContainsKey('State')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/System.State'
                    value = $State
                }
            }

            if ($PSBoundParameters.ContainsKey('Priority')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/Microsoft.VSTS.Common.Priority'
                    value = $Priority
                }
            }

            if ($PSBoundParameters.ContainsKey('RemainingWork')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/Microsoft.VSTS.Scheduling.RemainingWork'
                    value = $RemainingWork
                }
            }

            if ($PSBoundParameters.ContainsKey('Activity')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/Microsoft.VSTS.Common.Activity'
                    value = $Activity
                }
            }

            if ($PSBoundParameters.ContainsKey('AssignedTo')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/System.AssignedTo'
                    value = $AssignedTo
                }
            }

            if ($PSBoundParameters.ContainsKey('AreaPath')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/System.AreaPath'
                    value = $AreaPath
                }
            }

            if ($PSBoundParameters.ContainsKey('IterationPath')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/System.IterationPath'
                    value = $IterationPath
                }
            }

            if ($PSBoundParameters.ContainsKey('Tags')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/System.Tags'
                    value = $Tags
                }
            }

            if ($patchDocument.Count -eq 0) {
                throw "At least one property must be specified to update."
            }

            # Construct API URI
            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            } else {
                [uri]::EscapeDataString($Project)
            }
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitems/$Id" + "?api-version=7.1-preview.3"

            Write-Verbose "Updating task ID: $Id in project: $Project"
            Write-Verbose "API URI: $uri"
            Write-Verbose "Patch operations: $($patchDocument.Count)"

            $body = $patchDocument | ConvertTo-Json -Depth 10
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Patch -Body $body -ErrorAction Stop

            [PSCustomObject]@{
                Id            = $response.id
                Title         = $response.fields.'System.Title'
                Description   = $response.fields.'System.Description'
                State         = $response.fields.'System.State'
                Priority      = $response.fields.'Microsoft.VSTS.Common.Priority'
                RemainingWork = $response.fields.'Microsoft.VSTS.Scheduling.RemainingWork'
                Activity      = $response.fields.'Microsoft.VSTS.Common.Activity'
                AssignedTo    = $response.fields.'System.AssignedTo'.displayName
                WorkItemType  = $response.fields.'System.WorkItemType'
                AreaPath      = $response.fields.'System.AreaPath'
                IterationPath = $response.fields.'System.IterationPath'
                Tags          = $response.fields.'System.Tags'
                ChangedDate   = $response.fields.'System.ChangedDate'
                ChangedBy     = $response.fields.'System.ChangedBy'.displayName
                Organization  = $Organization
                Project       = $Project
                Url           = $response.url
                WebUrl        = $response._links.html.href
                PSTypeName    = 'PSU.ADO.Task'
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
