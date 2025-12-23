<#
.SYNOPSIS
    Updates an existing Azure DevOps Variable Group.

.DESCRIPTION
    Updates Variable Group metadata (Name, Description) and values of existing variables.
    Designed to accept pipeline input from Get-PSUADOVariableGroup.

.PARAMETER InputObject
    Variable Group object returned from Get-PSUADOVariableGroup.

.PARAMETER Organization
    (Optional) Azure DevOps organization name.
    Default value is $env:ORGANIZATION.

.PARAMETER PAT
    (Optional) Personal Access Token for Azure DevOps authentication.
    Default value is $env:PAT.

.EXAMPLE
    $vg = Get-PSUADOVariableGroup -Project "EnterpriseData" -Name "IaC-EnterpriseData-Terraform-Stage2"
    $vg.Description = "Updated description"
    $vg | Set-PSUADOVariableGroup

.EXAMPLE
    $vg = Get-PSUADOVariableGroup -Project "EnterpriseData" -Name "IaC-EnterpriseData-Terraform-Stage2"
    $vg.Variables["location"].value = "centralus"
    $vg | Set-PSUADOVariableGroup

.OUTPUTS
    [PSCustomObject]

.NOTES
    Author: Lakshmanachari Panuganti
    Created: August 2025

.LINK
    https://learn.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/update
#>
function Set-PSUADOVariableGroup {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [ValidateNotNull()]
        [psobject]$InputObject,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    begin {
        # Validate Organization
        if (-not $Organization) {
            throw "The default value for the 'ORGANIZATION' environment variable is not set."
        }

        # Validate PAT
        if (-not $PAT) {
            throw "The default value for the 'PAT' environment variable is not set."
        }

        $headers = Get-PSUAdoAuthHeader -PAT $PAT
    }

    process {
        try {
            # Required fields validation
            foreach ($field in 'Id', 'Name', 'Project', 'Variables') {
                if (-not $InputObject.$field) {
                    throw "InputObject is missing required property: '$field'. Ensure it comes from Get-PSUADOVariableGroup."
                }
            }

            # Escape project name
            $escapedProject = if ($InputObject.Project -match '%[0-9A-Fa-f]{2}') {
                $InputObject.Project
            } else {
                [uri]::EscapeDataString($InputObject.Project)
            }

            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/distributedtask/variablegroups/$($InputObject.Id)?api-version=7.1-preview.2"

            # Build variables payload (existing variables only)
            $variables = @{}
            foreach ($key in $InputObject.Variables.Keys) {
                $var = $InputObject.Variables[$key]

                $variables[$key] = @{
                    value     = $var.value
                    isSecret  = [bool]$var.isSecret
                }
            }

            $body = @{
                id          = $InputObject.Id
                name        = $InputObject.Name
                description = $InputObject.Description
                type        = "Vsts"
                variables   = $variables
            }

            if ($PSCmdlet.ShouldProcess($InputObject.Name, "Update Variable Group")) {
                $json = $body | ConvertTo-Json -Depth 10
                Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Body $json -ContentType "application/json"
            }

            # Return updated object
            Get-PSUADOVariableGroup `
                -Project $InputObject.Project `
                -Id $InputObject.Id `
                -Organization $Organization `
                -PAT $PAT

        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
