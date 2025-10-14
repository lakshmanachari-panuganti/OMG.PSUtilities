function New-PSUADOBug {
    <#
    .SYNOPSIS
        Creates a new bug work item in Azure DevOps.

    .DESCRIPTION
        This function creates a new bug work item in Azure DevOps using the REST API. 
        It allows you to specify bug-specific fields like reproduction steps, system info, severity, and priority.
        Returns the created work item details including the work item ID.

    .PARAMETER Title
        The title of the bug work item.

    .PARAMETER Description
        The detailed description of the bug.

    .PARAMETER ReproductionSteps
        The steps to reproduce the bug (optional).

    .PARAMETER SystemInfo
        Information about the system where the bug was found (optional).

    .PARAMETER Severity
        The severity of the bug. Valid values: 1, 2, 3, 4. Default is 3 (optional).

    .PARAMETER Priority
        The priority of the bug. Valid values: 1, 2, 3, 4. Default is 2 (optional).

    .PARAMETER FoundInBuild
        The build version where the bug was found (optional).

    .PARAMETER AssignedTo
        The email address of the person to assign the bug to (optional).

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
        New-PSUADOBug -Title "Login button not working" -Description "Users cannot click the login button on Chrome" -Project "MyProject"

        Creates a basic bug report.

    .EXAMPLE
        New-PSUADOBug -Title "Database connection timeout" -Description "Application crashes when database is slow" -ReproductionSteps "1. Start app 2. Wait 30 seconds 3. Click save" -SystemInfo "Windows 10, Chrome 91" -Severity 1 -Priority 1 -AssignedTo "dev@company.com" -Project "MyProject"

        Creates a detailed bug report with all fields specified.

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
        [string]$ReproductionSteps,

        [Parameter()]
        [string]$SystemInfo,

        [Parameter()]
        [ValidateRange(1, 4)]
        [int]$Priority = 2,

        [Parameter()]
        [string]$FoundInBuild,

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
            if ($ReproductionSteps) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.TCM.ReproSteps"
                    value = $ReproductionSteps
                }
            }

            if ($SystemInfo) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.TCM.SystemInfo"
                    value = $SystemInfo
                }
            }

            if ($FoundInBuild) {
                $fields += @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.Build.FoundIn"
                    value = $FoundInBuild
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
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitems/`$Bug?api-version=7.1-preview.3"

            Write-Verbose "Creating bug in project: $Project"
            Write-Verbose "API URI: $uri"

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $body -ErrorAction Stop

            [PSCustomObject]@{
                Id               = $response.id
                Title            = $response.fields.'System.Title'
                Description      = $response.fields.'System.Description'
                State            = $response.fields.'System.State'
                Severity         = $response.fields.'Microsoft.VSTS.Common.Severity'
                Priority         = $response.fields.'Microsoft.VSTS.Common.Priority'
                ReproductionSteps = $response.fields.'Microsoft.VSTS.TCM.ReproSteps'
                SystemInfo       = $response.fields.'Microsoft.VSTS.TCM.SystemInfo'
                FoundInBuild     = $response.fields.'Microsoft.VSTS.Build.FoundIn'
                AssignedTo       = $response.fields.'System.AssignedTo'.displayName
                CreatedDate      = $response.fields.'System.CreatedDate'
                CreatedBy        = $response.fields.'System.CreatedBy'.displayName
                WorkItemType     = $response.fields.'System.WorkItemType'
                AreaPath         = $response.fields.'System.AreaPath'
                IterationPath    = $response.fields.'System.IterationPath'
                Url              = $response.url
                WebUrl           = $response._links.html.href
                PSTypeName       = 'PSU.ADO.Bug'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}