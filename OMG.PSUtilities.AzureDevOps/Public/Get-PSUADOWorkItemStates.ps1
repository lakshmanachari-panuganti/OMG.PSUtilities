function Get-PSUADOWorkItemStates {
    <#
    .SYNOPSIS
        Retrieves all available states for Azure DevOps work item types in a project.

    .DESCRIPTION
        This function connects to Azure DevOps and retrieves the complete list of available states
        for each work item type in the specified project. This is useful for understanding valid
        state transitions when creating or updating work items.

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name where work item types are defined.

    .PARAMETER WorkItemType
        (Optional) Specific work item type to get states for (e.g., 'Bug', 'Task', 'User Story').
        If not specified, returns states for all work item types in the project.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        Get-PSUADOWorkItemStates -Organization "myorg" -Project "MyProject"

        Retrieves states for all work item types in the "MyProject" project.

    .EXAMPLE
        Get-PSUADOWorkItemStates -Organization "myorg" -Project "MyProject" -WorkItemType "Bug"

        Retrieves only the states available for Bug work items.

    .EXAMPLE
        Get-PSUADOWorkItemStates -Project "MyProject"

        Uses environment variables for organization and PAT.

    .OUTPUTS
        [PSCustomObject[]] - Array of work item types with their available states

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: October 16, 2025

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
        [string]$Project,

        [Parameter()]
        [string]$WorkItemType,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [string]$PAT = $env:PAT
    )

    begin {
        Write-PSUAdoParameterTrace -Invocation $MyInvocation -BoundParameters $PSBoundParameters
        Confirm-PSUAdoConnectionParameter -Organization $Organization -PAT $PAT

        $headers = Get-PSUAdoAuthHeader -PAT $PAT
    }

    process {
        try {
            # Escape project name for URI
            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            } else {
                [uri]::EscapeDataString($Project)
            }

            $allWorkItemStates = @()

            if ($WorkItemType) {
                # Get states for specific work item type
                Write-Verbose "Retrieving states for work item type: $WorkItemType"
                $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitemtypes/$WorkItemType/states?api-version=7.1-preview.1"

                $invokeParams = @{
                    Uri         = $uri
                    Headers     = $headers
                    Method      = 'Get'
                    ErrorAction = 'Stop'
                    Verbose     = $false
                }
                $response = Invoke-RestMethod @invokeParams

                $workItemStateInfo = [PSCustomObject]@{
                    WorkItemType = $WorkItemType
                    States       = $response.value | ForEach-Object {
                        [PSCustomObject]@{
                            Name        = $_.name
                            Category    = $_.category
                            PSTypeName  = 'PSU.ADO.WorkItemState'
                        }
                    }
                    PSTypeName   = 'PSU.ADO.WorkItemTypeStates'
                }

                $allWorkItemStates += $workItemStateInfo
            } else {
                # Get all work item types first, then get states for each
                Write-Verbose "Retrieving all work item types for project: $Project"
                $typesUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitemtypes?api-version=7.1-preview.1"

                $typesResponse = Invoke-RestMethod -Uri $typesUri -Headers $headers -Method Get -ErrorAction Stop

                foreach ($wit in $typesResponse.value) {
                    Write-Verbose "Retrieving states for work item type: $($wit.name)"
                    $statesUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitemtypes/$($wit.name)/states?api-version=7.1-preview.1"

                    try {
                        # Invoke states endpoint with splatting
                        $invokeParams = @{
                            Uri         = $statesUri
                            Headers     = $headers
                            Method      = 'Get'
                            ErrorAction = 'Stop'
                            Verbose     = $false
                        }
                        $statesResponse = Invoke-RestMethod @invokeParams

                        $workItemStateInfo = [PSCustomObject]@{
                            States       = $statesResponse.value | ForEach-Object {
                                [PSCustomObject]@{
                                    Name        = $_.name
                                    Category    = $_.category
                                    PSTypeName  = 'PSU.ADO.WorkItemState'
                                }
                            }
                            PSTypeName   = 'PSU.ADO.WorkItemTypeStates'
                        }

                        $allWorkItemStates += $workItemStateInfo
                    } catch {
                        Write-Warning "Failed to get states for work item type '$($wit.name)': $($_.Exception.Message)"
                    }
                }
            }

            Write-Verbose "Retrieved states for $($allWorkItemStates.Count) work item type(s)"
            return $allWorkItemStates

        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}