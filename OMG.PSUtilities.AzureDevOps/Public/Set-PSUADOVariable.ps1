function Set-PSUADOVariable {
    <#
    .SYNOPSIS
        Updates an existing variable in an Azure DevOps Variable Group.

    .DESCRIPTION
        Updates the value and/or secret status of an existing variable in a variable group.
        If the variable doesn't exist, it will be created. If it exists, its value will be updated.
        Use this function to modify variable values or change a variable's secret status.

    .PARAMETER VariableGroupName
        (Mandatory) The name of the variable group containing the variable.

    .PARAMETER VariableGroupId
        (Optional) The ID of the variable group. If not provided, the function will look up the ID by name.

    .PARAMETER VariableName
        (Mandatory) The name of the variable to update.

    .PARAMETER VariableValue
        (Mandatory) The new value for the variable.

    .PARAMETER IsSecret
        (Optional) Switch parameter. If specified, the variable will be marked as secret and its value will be masked.
        If not specified, the existing secret status will be preserved.

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing the variable group.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication with Variable Groups (read, create, & manage) permissions.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        Set-PSUADOVariable -Organization "omg" -Project "psutilities" -VariableGroupName "MyVarGroup" -VariableName "Environment" -VariableValue "Staging"

        Updates the "Environment" variable to "Staging" in the variable group.

    .EXAMPLE
        Set-PSUADOVariable -Organization "omg" -Project "psutilities" -VariableGroupName "MyVarGroup" -VariableName "ApiKey" -VariableValue "newkey456" -IsSecret

        Updates the "ApiKey" variable and marks it as secret.

    .EXAMPLE
        Set-PSUADOVariable -Organization "omg" -Project "psutilities" -VariableGroupId 123 -VariableName "Region" -VariableValue "West-US"

        Updates the "Region" variable using the variable group ID directly.

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

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$VariableGroupName,

        [Parameter(ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [int]$VariableGroupId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$VariableName,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$VariableValue,

        [Parameter()]
        [switch]$IsSecret,

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

            # If VariableGroupId not provided, look it up by name
            if (-not $VariableGroupId) {
                Write-Verbose "Looking up variable group ID for: $VariableGroupName"
                $listUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
                $allGroups = Invoke-RestMethod -Uri $listUri -Headers $headers -Method Get -ErrorAction Stop

                $matchingGroup = $allGroups.value | Where-Object { $_.name -eq $VariableGroupName }

                if (-not $matchingGroup) {
                    throw "Variable group '$VariableGroupName' not found in project '$Project'."
                }

                $VariableGroupId = $matchingGroup.id
                Write-Verbose "Found variable group ID: $VariableGroupId"
            }

            # Get the existing variable group
            $getUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/distributedtask/variablegroups/$($VariableGroupId)?api-version=7.1-preview.2"
            Write-Verbose "Retrieving variable group from: $getUri"

            $existingGroup = Invoke-RestMethod -Uri $getUri -Headers $headers -Method Get -ErrorAction Stop

            # Check if variable exists
            $variableExists = $existingGroup.variables.PSObject.Properties.Name -contains $VariableName

            # Clone the existing variables into a new hashtable
            $updatedVariables = @{}
            foreach ($prop in $existingGroup.variables.PSObject.Properties) {
                $updatedVariables[$prop.Name] = @{
                    value = $prop.Value.value
                }
                if ($prop.Value.PSObject.Properties.Name -contains 'isSecret') {
                    $updatedVariables[$prop.Name].isSecret = $prop.Value.isSecret
                }
            }

            # Add or update the target variable
            if ($variableExists) {
                Write-Verbose "Updating existing variable: $VariableName"
                # Preserve existing isSecret status unless explicitly provided
                $secretStatus = if ($PSBoundParameters.ContainsKey('IsSecret')) {
                    $IsSecret.IsPresent
                } else {
                    $existingGroup.variables.$VariableName.isSecret -eq $true
                }

                $updatedVariables[$VariableName] = @{
                    value    = $VariableValue
                    isSecret = $secretStatus
                }
            } else {
                Write-Verbose "Adding new variable: $VariableName"
                $updatedVariables[$VariableName] = @{
                    value    = $VariableValue
                    isSecret = $IsSecret.IsPresent
                }
            }

            # Build the update body
            $updateBody = @{
                id          = $existingGroup.id
                type        = $existingGroup.type
                name        = $existingGroup.name
                description = $existingGroup.description
                variables   = $updatedVariables
            }

            # Include variableGroupProjectReferences (required for update)
            if ($existingGroup.variableGroupProjectReferences) {
                $updateBody.variableGroupProjectReferences = $existingGroup.variableGroupProjectReferences
            }

            # Include providerData if it exists (for Azure Key Vault linked variable groups)
            if ($existingGroup.providerData) {
                $updateBody.providerData = $existingGroup.providerData
            }

            $bodyJson = $updateBody | ConvertTo-Json -Depth 10

            $updateUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/distributedtask/variablegroups/$($VariableGroupId)?api-version=7.1-preview.2"
            Write-Verbose "Updating variable group at: $updateUri"

            $response = Invoke-RestMethod -Uri $updateUri -Headers $headers -Method Put -Body $bodyJson -ContentType "application/json" -ErrorAction Stop

            $action = if ($variableExists) { "Updated" } else { "Added" }
            Write-Verbose "$action variable '$VariableName' in variable group '$($response.name)'"

            # Return information about the updated/added variable
            [PSCustomObject]@{
                VariableGroupId   = $response.id
                VariableGroupName = $response.name
                VariableName      = $VariableName
                VariableValue     = if ($response.variables.$VariableName.isSecret) { "***SECRET***" } else { $response.variables.$VariableName.value }
                IsSecret          = $response.variables.$VariableName.isSecret
                Action            = $action
                ModifiedBy        = $response.modifiedBy.displayName
                ModifiedOn        = $response.modifiedOn
                PSTypeName        = 'PSU.ADO.Variable'
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
