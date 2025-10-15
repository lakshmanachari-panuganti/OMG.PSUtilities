function Set-PSUADOBug {
    <#
    .SYNOPSIS
        Updates an existing bug in Azure DevOps.

    .DESCRIPTION
        This function updates an existing bug in Azure DevOps using the REST API.
        It allows you to modify title, description, state, priority, severity, repro steps,
        assignments, area path, iteration path, and tags.

        Requires: Azure DevOps PAT with work item write permissions

    .PARAMETER Id
        (Mandatory) The ID of the bug to update.

    .PARAMETER Title
        (Optional) The new title for the bug.

    .PARAMETER Description
        (Optional) The new description for the bug.

    .PARAMETER ReproSteps
        (Optional) Steps to reproduce the bug.

    .PARAMETER State
        (Optional) The state of the bug.
        Common values: 'New', 'Active', 'Resolved', 'Closed', 'Removed'.

    .PARAMETER Priority
        (Optional) The priority of the bug. Valid values: 1, 2, 3, 4.

    .PARAMETER Severity
        (Optional) The severity of the bug.
        Common values: '1 - Critical', '2 - High', '3 - Medium', '4 - Low'.

    .PARAMETER AssignedTo
        (Optional) The email address or display name of the person to assign the bug to.

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
        Set-PSUADOBug -Organization "omg" -Project "psutilities" -Id 12345 -State "Active" -Severity "1 - Critical" -Priority 1

        Updates the state, severity, and priority of bug 12345.

    .EXAMPLE
        Set-PSUADOBug -Organization "omg" -Project "psutilities" -Id 12345 -Title "Updated Bug Title" -ReproSteps "1. Do this\n2. Do that" -AssignedTo "user@company.com"

        Updates multiple properties of the bug.

    .EXAMPLE
        Set-PSUADOBug -Organization "omg" -Project "psutilities" -Id 12345 -State "Resolved" -Tags "ui,regression"

        Marks a bug as resolved and adds tags.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 15th October 2025
        Requires: Azure DevOps PAT with work item write permissions

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
        [string]$ReproSteps,

        [Parameter()]
        [ValidateSet('New', 'Active', 'Resolved', 'Closed', 'Removed')]
        [string]$State,

        [Parameter()]
        [ValidateRange(1, 4)]
        [int]$Priority,

        [Parameter()]
        [ValidateSet('1 - Critical', '2 - High', '3 - Medium', '4 - Low')]
        [string]$Severity,

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

            if ($PSBoundParameters.ContainsKey('ReproSteps')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/Microsoft.VSTS.TCM.ReproSteps'
                    value = $ReproSteps
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

            if ($PSBoundParameters.ContainsKey('Severity')) {
                $patchDocument += @{
                    op    = 'add'
                    path  = '/fields/Microsoft.VSTS.Common.Severity'
                    value = $Severity
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

            Write-Verbose "Updating bug ID: $Id in project: $Project"
            Write-Verbose "API URI: $uri"
            Write-Verbose "Patch operations: $($patchDocument.Count)"

            $body = $patchDocument | ConvertTo-Json -Depth 10
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Patch -Body $body -ErrorAction Stop

            [PSCustomObject]@{
                Id            = $response.id
                Title         = $response.fields.'System.Title'
                Description   = $response.fields.'System.Description'
                ReproSteps    = $response.fields.'Microsoft.VSTS.TCM.ReproSteps'
                State         = $response.fields.'System.State'
                Priority      = $response.fields.'Microsoft.VSTS.Common.Priority'
                Severity      = $response.fields.'Microsoft.VSTS.Common.Severity'
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
                PSTypeName    = 'PSU.ADO.Bug'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
