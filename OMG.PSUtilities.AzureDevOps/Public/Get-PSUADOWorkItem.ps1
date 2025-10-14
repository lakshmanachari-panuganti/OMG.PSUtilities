function Get-PSUADOWorkItem {
    <#
    .SYNOPSIS
        Retrieves a work item from Azure DevOps.

    .DESCRIPTION
        This function retrieves a work item from Azure DevOps using the REST API.
        It fetches detailed information about the work item including title, description,
        state, priority, assigned user, and other properties. Works with all work item types
        (User Story, Bug, Task, Feature, Epic, etc.).

        Requires: Azure DevOps PAT with work item read permissions

    .PARAMETER Id
        (Mandatory) The ID of the work item to retrieve.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name.
        Auto-detected from git remote origin URL, or uses $env:ORGANIZATION when set.

    .PARAMETER Project
        (Optional) The Azure DevOps project name.
        Auto-detected from git remote origin URL.

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default is $env:PAT

    .EXAMPLE
        Get-PSUADOWorkItem -Id 12345

        Uses auto-detected Organization/Project to retrieve work item with ID 12345.

    .EXAMPLE
        Get-PSUADOWorkItem -Organization "psutilities" -Project "AI" -Id 12345

        Uses explicit Organization and Project parameters to retrieve the work item.

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
        [string]$Organization = $(
            if ($env:ORGANIZATION) { $env:ORGANIZATION }
            else {
                git remote get-url origin 2>$null | ForEach-Object {
                    if ($_ -match 'dev\.azure\.com/([^/]+)/') { $matches[1] }
                }
            }
        ),

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
            if (-not $Organization) {
                throw "Organization is required. Set env var: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>' or ensure git remote is an Azure DevOps URL."
            }
            if (-not $Project) {
                throw "Project is required. Provide -Project or ensure the git remote contains the project segment."
            }

            $headers = Get-PSUAdoAuthHeader -PAT $PAT

            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            }
            else {
                [uri]::EscapeDataString($Project)
            }
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitems/$Id" + "?api-version=7.1-preview.3"

            Write-Verbose "Retrieving work item ID: $Id from project: $Project"
            Write-Verbose "API URI: $uri"

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop

            $workItemType = $response.fields.'System.WorkItemType'
            Write-Verbose "Work item type: $workItemType"

            [PSCustomObject]@{
                Id                 = $response.id
                WorkItemType       = $workItemType
                Title              = $response.fields.'System.Title'
                Description        = $response.fields.'System.Description'
                State              = $response.fields.'System.State'
                Reason             = $response.fields.'System.Reason'
                Priority           = $response.fields.'Microsoft.VSTS.Common.Priority'
                Severity           = $response.fields.'Microsoft.VSTS.Common.Severity'
                StoryPoints        = $response.fields.'Microsoft.VSTS.Scheduling.StoryPoints'
                Effort             = $response.fields.'Microsoft.VSTS.Scheduling.Effort'
                RemainingWork      = $response.fields.'Microsoft.VSTS.Scheduling.RemainingWork'
                OriginalEstimate   = $response.fields.'Microsoft.VSTS.Scheduling.OriginalEstimate'
                CompletedWork      = $response.fields.'Microsoft.VSTS.Scheduling.CompletedWork'
                AssignedTo         = $response.fields.'System.AssignedTo'.displayName
                CreatedDate        = $response.fields.'System.CreatedDate'
                CreatedBy          = $response.fields.'System.CreatedBy'.displayName
                ChangedDate        = $response.fields.'System.ChangedDate'
                ChangedBy          = $response.fields.'System.ChangedBy'.displayName
                AreaPath           = $response.fields.'System.AreaPath'
                IterationPath      = $response.fields.'System.IterationPath'
                Tags               = $response.fields.'System.Tags'
                AcceptanceCriteria = $response.fields.'Microsoft.VSTS.Common.AcceptanceCriteria'
                ReproSteps         = $response.fields.'Microsoft.VSTS.TCM.ReproSteps'
                ValueArea          = $response.fields.'Microsoft.VSTS.Common.ValueArea'
                Organization       = $Organization
                Project            = $Project
                Url                = $response.url
                WebUrl             = $response._links.html.href
                PSTypeName         = 'PSU.ADO.WorkItem'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
