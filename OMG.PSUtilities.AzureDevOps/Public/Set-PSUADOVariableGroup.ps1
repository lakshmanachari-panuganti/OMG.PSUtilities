function Set-PSUADOVariableGroup {
<#
.SYNOPSIS
    Updates an existing Azure DevOps Variable Group.

.DESCRIPTION
    Updates Variable Group metadata (Name, Description) and variable configurations.
    This cmdlet replaces the entire variable set of the Variable Group.
    Designed to accept pipeline input from Get-PSUADOVariableGroup.

.PARAMETER InputObject
    Variable Group object returned from Get-PSUADOVariableGroup.

.PARAMETER Organization
    (Optional) Azure DevOps organization name.
    Defaults to the value of the ORGANIZATION environment variable.

.PARAMETER PAT
    (Optional) Personal Access Token (PAT) for Azure DevOps authentication.
    Defaults to the value of the PAT environment variable.

.EXAMPLE
    $vg = Get-PSUADOVariableGroup -Project "EnterpriseData" -Name "IaC-Stage2"
    $vg.Description = "Updated description"
    $vg | Set-PSUADOVariableGroup

.EXAMPLE
    $vg = Get-PSUADOVariableGroup -Project "EnterpriseData" -Name "IaC-Stage2"
    $vg.Variables["location"].value = "centralus"
    $vg | Set-PSUADOVariableGroup

.OUTPUTS
    [PSCustomObject]

.NOTES
    Author  : Lakshmanachari Panuganti
    Created : August 2025

    This cmdlet replaces the entire Variables object in Azure DevOps.
    Ensure all existing variables are present to avoid accidental deletion.

    Secret variable values are preserved unless explicitly changed.

.LINK
    https://www.github.com/lakshmanachari-panuganti
    https://www.linkedin.com/in/lakshmanachari-panuganti
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    Install-Module -Name OMG.PSUtilities.AzureDevOps -Repository PSGallery
    https://learn.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/update
#>

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
        if (-not $Organization) {
            throw "The 'ORGANIZATION' environment variable is not set."
        }

        if (-not $PAT) {
            throw "The 'PAT' environment variable is not set."
        }

        $headers = Get-PSUAdoAuthHeader -PAT $PAT
    }

    process {
        try {
            foreach ($field in 'Id', 'Name', 'Project', 'Variables') {
                if (-not $InputObject.PSObject.Properties[$field]) {
                    throw "InputObject is missing required property '$field'. Ensure it comes from Get-PSUADOVariableGroup."
                }
            }

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
                    value    = $var.value
                    isSecret = [bool]$var.isSecret
                }
            }

            $body = @{
                id          = $InputObject.Id
                name        = $InputObject.Name
                description = $InputObject.Description
                type        = "Vsts"
                variables   = $variables
            }

            if ($PSCmdlet.ShouldProcess(
                "$($InputObject.Name) [$($InputObject.Id)]",
                "Update Azure DevOps Variable Group"
            )) {
                $json = $body | ConvertTo-Json -Depth 10
                Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Body $json -ContentType "application/json"
            }

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
