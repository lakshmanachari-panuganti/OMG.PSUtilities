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
        (Optional) The Azure DevOps organization name.
        Auto-detected from git remote origin URL, or uses $env:ORGANIZATION when set.

    .PARAMETER Project
        (Optional) The Azure DevOps project name.
        Auto-detected from git remote origin URL.

    .PARAMETER Repository
        (Optional) The repository name.
        Auto-detected from git remote origin URL.

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default is $env:PAT. Set using:
        Set-PSUUserEnvironmentVariable -Name "PAT" -Value "<value>"

    .EXAMPLE
        Set-PSUADOTask -Id 12345 -State "In Progress" -RemainingWork 4

        Updates the state and remaining work of task 12345 using auto-detected Organization/Project.

    .EXAMPLE
        Set-PSUADOTask -Id 12345 -Title "Updated Task Title" -Activity "Development" -AssignedTo "user@company.com"

        Updates multiple properties of the task.

    .EXAMPLE
        Set-PSUADOTask -Organization "myorg" -Project "myproject" -Id 12345 -State "Done" -RemainingWork 0

        Marks a task as done with explicit organization and project parameters.

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
        [string]$Title,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [ValidateSet('To Do', 'In Progress', 'Done', 'Removed')]
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
        [string]$AssignedTo,

        [Parameter()]
        [string]$AreaPath,

        [Parameter()]
        [string]$IterationPath,

        [Parameter()]
        [string]$Tags,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $(if ($env:ORGANIZATION) { $env:ORGANIZATION } else {
            git remote get-url origin 2>$null | ForEach-Object {
                if ($_ -match 'dev\.azure\.com/([^/]+)/') { $matches[1] }
            }
        }),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Project = $(git remote get-url origin 2>$null | ForEach-Object {
            if ($_ -match 'dev\.azure\.com/[^/]+/([^/]+)/_git/') { $matches[1] }
        }),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    process {
        try {
            # Display parameters
            Write-Host "Parameters:" -ForegroundColor Cyan
            foreach ($param in $PSBoundParameters.GetEnumerator()) {
                if ($param.Key -eq 'PAT') {
                    $maskedPAT = if ($param.Value -and $param.Value.Length -ge 3) { $param.Value.Substring(0, 3) + "********" } else { "***" }
                    Write-Host "  $($param.Key): $maskedPAT" -ForegroundColor Cyan
                } else {
                    $displayValue = $param.Value.ToString()
                    if ($displayValue.Length -gt 30) {
                        $displayValue = $displayValue.Substring(0, 27) + "..."
                    }
                    Write-Host "  $($param.Key): $displayValue" -ForegroundColor Cyan
                }
            }
            Write-Host ""

            if (-not $Organization) {
                throw "Organization is required. Set env var: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>' or ensure git remote is an Azure DevOps URL."
            }
            if (-not $Project) {
                throw "Project is required. Provide -Project or ensure the git remote contains the project segment."
            }

            $headers = Get-PSUAdoAuthHeader -PAT $PAT
            $headers['Content-Type'] = 'application/json-patch+json'

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
            }
            else {
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
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
