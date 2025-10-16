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

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing the work item.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        Get-PSUADOWorkItem -Organization "omg" -Project "psutilities" -Id 12345

        Retrieves work item with ID 12345 from the psutilities project.

    .EXAMPLE
        Get-PSUADOWorkItem -Organization "omg" -Project "psutilities" -Id 67890

        Retrieves work item with ID 67890 from the psutilities project.

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
    }
    process {
        try {
            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            } else {
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
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
