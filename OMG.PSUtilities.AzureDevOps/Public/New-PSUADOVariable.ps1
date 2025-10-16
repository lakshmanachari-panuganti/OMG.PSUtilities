function New-PSUADOVariable {
    <#
    .SYNOPSIS
        Adds a variable to an existing Azure DevOps Variable Group.

    .DESCRIPTION
        Adds or updates a variable in an existing variable group. Supports both regular and secret variables.
        If the variable already exists, it will be updated with the new value.

    .PARAMETER VariableGroupName
        (Mandatory) The name of the variable group to add the variable to.
        Use either VariableGroupName or VariableGroupId.

    .PARAMETER VariableGroupId
        (Mandatory) The ID of the variable group to add the variable to.
        Use either VariableGroupName or VariableGroupId.

    .PARAMETER VariableName
        (Mandatory) The name of the variable to add or update.

    .PARAMETER VariableValue
        (Mandatory) The value of the variable.

    .PARAMETER IsSecret
        (Optional) Switch parameter. If specified, the variable will be marked as secret and its value will be masked.

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing the variable group.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication with Variable Groups (read, create, & manage) permissions.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        New-PSUADOVariable -Organization "omg" -Project "psutilities" -VariableGroupName "MyVarGroup" -VariableName "Environment" -VariableValue "Production"

        Adds a regular variable named "Environment" with value "Production" to the variable group.

    .EXAMPLE
        New-PSUADOVariable -Organization "omg" -Project "psutilities" -VariableGroupName "MyVarGroup" -VariableName "ApiKey" -VariableValue "secret123" -IsSecret

        Adds a secret variable named "ApiKey" to the variable group. The value will be masked.

    .EXAMPLE
        New-PSUADOVariable -Organization "omg" -Project "psutilities" -VariableGroupName "MyVarGroup" -VariableName "Region" -VariableValue "East-US"

        Adds a variable to the psutilities project's variable group.

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

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
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
            # Get variable group by ID or Name
            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                Write-Verbose "Retrieving variable group by ID: $VariableGroupId"
                $getUrl = "https://dev.azure.com/$Organization/$([uri]::EscapeDataString($Project))/_apis/distributedtask/variablegroups/$($VariableGroupId)?api-version=7.1-preview.2"
                $variableGroup = Invoke-RestMethod -Uri $getUrl -Method Get -Headers $headers -ErrorAction Stop
            } else {
                Write-Verbose "Retrieving variable group by name: $VariableGroupName"
                # Get all variable groups for the project
                $listUrl = "https://dev.azure.com/$Organization/$([uri]::EscapeDataString($Project))/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
                $allGroups = Invoke-RestMethod -Uri $listUrl -Method Get -Headers $headers -ErrorAction Stop

                $variableGroup = $allGroups.value | Where-Object { $_.name -eq $VariableGroupName }

                if (-not $variableGroup) {
                    throw "Variable group '$VariableGroupName' not found in project '$Project'"
                }
            }

            Write-Verbose "Found variable group with ID: $($variableGroup.id)"
            Write-Verbose "Adding/updating variable: $VariableName"

            # Initialize variables hashtable if it doesn't exist
            if (-not $variableGroup.variables) {
                $variableGroup.variables = @{}
            }

            # Remove _placeholder if this is the first real variable
            if ($variableGroup.variables.PSObject.Properties.Name -contains '_placeholder' -and
                $variableGroup.variables.PSObject.Properties.Count -eq 1) {
                Write-Verbose "Removing placeholder variable"
                $variableGroup.variables.PSObject.Properties.Remove('_placeholder')
            }

            # Add or update the variable
            if ($variableGroup.variables.PSObject.Properties.Name -contains $VariableName) {
                Write-Verbose "Updating existing variable: $VariableName"
                $variableGroup.variables.$VariableName.value = $VariableValue
                if ($IsSecret) {
                    $variableGroup.variables.$VariableName | Add-Member -MemberType NoteProperty -Name "isSecret" -Value $true -Force
                }
            } else {
                Write-Verbose "Adding new variable: $VariableName"
                $newVariable = @{
                    value = $VariableValue
                }
                if ($IsSecret) {
                    $newVariable.isSecret = $true
                }
                $variableGroup.variables | Add-Member -MemberType NoteProperty -Name $VariableName -Value $newVariable -Force
            }

            # Get project ID for proper reference
            $projectUrl = "https://dev.azure.com/$Organization/_apis/projects/$([uri]::EscapeDataString($Project))?api-version=7.1"
            $projectInfo = Invoke-RestMethod -Uri $projectUrl -Method Get -Headers $headers -ErrorAction Stop
            $projectId = $projectInfo.id

            # Build clean update payload
            $updatePayload = @{
                id                             = $variableGroup.id
                name                           = $variableGroup.name
                description                    = $variableGroup.description
                type                           = "Vsts"
                variables                      = $variableGroup.variables
                variableGroupProjectReferences = @(
                    @{
                        projectReference = @{
                            id = $projectId
                        }
                        name             = $variableGroup.name
                        description      = $variableGroup.description
                    }
                )
            }

            # Update the variable group
            $updateBody = $updatePayload | ConvertTo-Json -Depth 10
            $updateUrl = "https://dev.azure.com/$Organization/$([uri]::EscapeDataString($Project))/_apis/distributedtask/variablegroups/$($variableGroup.id)?api-version=7.1-preview.2"

            $updatedGroup = Invoke-RestMethod -Uri $updateUrl -Method Put -Headers $headers -Body $updateBody -ErrorAction Stop

            $displayValue = if ($IsSecret) { "***" } else { $VariableValue }
            $secretLabel = if ($IsSecret) { " (Secret)" } else { "" }

            Write-Verbose "Variable '$VariableName' added/updated successfully: $displayValue$secretLabel"

            return [PSCustomObject]@{
                VariableGroupId   = $updatedGroup.id
                VariableGroupName = $updatedGroup.name
                VariableName      = $VariableName
                VariableValue     = $displayValue
                IsSecret          = $IsSecret.IsPresent
                PSTypeName        = 'PSU.ADO.Variable'
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
