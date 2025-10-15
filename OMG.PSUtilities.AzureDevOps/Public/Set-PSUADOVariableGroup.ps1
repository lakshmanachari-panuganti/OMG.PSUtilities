function Set-PSUADOVariableGroup {
    <#
    .SYNOPSIS
        Updates an existing Azure DevOps Variable Group.

    .DESCRIPTION
        Updates the properties of an existing variable group in an Azure DevOps project.
        Allows modification of the variable group name, description, and variables.
        Use this function to rename a variable group or update its description.

    .PARAMETER VariableGroupId
        (Mandatory) The ID of the variable group to update.

    .PARAMETER VariableGroupName
        (Optional) The new name for the variable group.

    .PARAMETER Description
        (Optional) The new description for the variable group.

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing the variable group.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication with Variable Groups (read, create, & manage) permissions.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        Set-PSUADOVariableGroup -Organization "omg" -Project "psutilities" -VariableGroupId 123 -VariableGroupName "UpdatedVarGroup"

        Renames the variable group with ID 123 to "UpdatedVarGroup".

    .EXAMPLE
        Set-PSUADOVariableGroup -Organization "omg" -Project "psutilities" -VariableGroupId 456 -Description "Updated production variables"

        Updates the description of variable group with ID 456.

    .EXAMPLE
        Set-PSUADOVariableGroup -Organization "omg" -Project "psutilities" -VariableGroupId 789 -VariableGroupName "ProdVars" -Description "Production environment variables"

        Updates both the name and description of the variable group.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 15th October 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://learn.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]$VariableGroupId,

        [Parameter()]
        [string]$VariableGroupName,

        [Parameter()]
        [string]$Description,

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
            # First, get the existing variable group to preserve existing data
            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            } else {
                [uri]::EscapeDataString($Project)
            }

            $getUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/distributedtask/variablegroups/$($VariableGroupId)?api-version=7.1-preview.2"
            Write-Verbose "Retrieving existing variable group from: $getUri"

            $existingGroup = Invoke-RestMethod -Uri $getUri -Headers $headers -Method Get -ErrorAction Stop

            # Build the update body with existing data
            $updateBody = @{
                id          = $existingGroup.id
                type        = $existingGroup.type
                name        = if ($VariableGroupName) { $VariableGroupName } else { $existingGroup.name }
                description = if ($PSBoundParameters.ContainsKey('Description')) { $Description } else { $existingGroup.description }
                variables   = $existingGroup.variables
            }

            # Include variableGroupProjectReferences (required for update)
            if ($existingGroup.variableGroupProjectReferences) {
                # Update the name and description in the project references
                $updatedRefs = @()
                foreach ($ref in $existingGroup.variableGroupProjectReferences) {
                    $updatedRefs += @{
                        projectReference = $ref.projectReference
                        name             = if ($VariableGroupName) { $VariableGroupName } else { $ref.name }
                        description      = if ($PSBoundParameters.ContainsKey('Description')) { $Description } else { $ref.description }
                    }
                }
                $updateBody.variableGroupProjectReferences = $updatedRefs
            }

            # Include providerData if it exists (for Azure Key Vault linked variable groups)
            if ($existingGroup.providerData) {
                $updateBody.providerData = $existingGroup.providerData
            }

            $bodyJson = $updateBody | ConvertTo-Json -Depth 10

            Write-Verbose "Update payload:"
            Write-Verbose $bodyJson

            $updateUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/distributedtask/variablegroups/$($VariableGroupId)?api-version=7.1-preview.2"
            Write-Verbose "Updating variable group at: $updateUri"

            $response = Invoke-RestMethod -Uri $updateUri -Headers $headers -Method Put -Body $bodyJson -ContentType "application/json" -ErrorAction Stop

            Write-Verbose "Successfully updated variable group ID: $($response.id)"
            Write-Verbose "Response name: $($response.name)"
            Write-Verbose "Response description: $($response.description)"

            [PSCustomObject]@{
                Id          = $response.id
                Name        = $response.name
                Description = $response.description
                Type        = $response.type
                Variables   = $response.variables
                CreatedBy   = $response.createdBy.displayName
                CreatedOn   = $response.createdOn
                ModifiedBy  = $response.modifiedBy.displayName
                ModifiedOn  = $response.modifiedOn
                PSTypeName  = 'PSU.ADO.VariableGroup'
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
