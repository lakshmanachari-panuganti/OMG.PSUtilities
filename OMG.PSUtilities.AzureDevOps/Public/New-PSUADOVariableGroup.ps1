function New-PSUADOVariableGroup {
    <#
    .SYNOPSIS
        Creates a new Azure DevOps Variable Group.

    .DESCRIPTION
        Creates a new variable group in an Azure DevOps project with an initial placeholder variable.
        The variable group can be used to store and manage variables for CI/CD pipelines.

    .PARAMETER VariableGroupName
        (Mandatory) The name of the variable group to create.

    .PARAMETER Description
        (Optional) Description for the variable group explaining its purpose.

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name where the variable group will be created.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication with Variable Groups (read, create, & manage) permissions.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        New-PSUADOVariableGroup -Organization "omg" -Project "psutilities" -VariableGroupName "MyVarGroup" -Description "Production variables"

        Creates a new variable group named "MyVarGroup" with description in the psutilities project.

    .EXAMPLE
        New-PSUADOVariableGroup -Organization "omg" -Project "psutilities" -VariableGroupName "DevVars"

        Creates a variable group in the psutilities project.

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
        [string]$VariableGroupName,
        
        [Parameter()]
        [string]$Description = "",
        
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

            $headers = Get-PSUAdoAuthHeader -PAT $PAT

            Write-Verbose "Retrieving project information for: $Project"
            
            # Get project ID
            $projectUrl = "https://dev.azure.com/$Organization/_apis/projects/$([uri]::EscapeDataString($Project))?api-version=7.1"
            $projectInfo = Invoke-RestMethod -Uri $projectUrl -Method Get -Headers $headers -ErrorAction Stop
            $projectId = $projectInfo.id

            Write-Verbose "Project ID: $projectId"
            Write-Verbose "Creating variable group: $VariableGroupName"
            
            # Build variable group payload
            $variableGroupBody = @{
                name = $VariableGroupName
                description = $Description
                type = "Vsts"
                variables = @{
                    "_placeholder" = @{
                        value = "This is a placeholder variable. You can delete it after adding your variables."
                        isSecret = $false
                    }
                }
                variableGroupProjectReferences = @(
                    @{
                        projectReference = @{
                            id = $projectId
                            name = $Project
                        }
                        name = $VariableGroupName
                        description = $Description
                    }
                )
            } | ConvertTo-Json -Depth 10
            
            $createUrl = "https://dev.azure.com/$Organization/$([uri]::EscapeDataString($Project))/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
            
            $variableGroup = Invoke-RestMethod -Uri $createUrl -Method Post -Headers $headers -Body $variableGroupBody -ErrorAction Stop
            
            Write-Verbose "Variable group '$VariableGroupName' created successfully with ID: $($variableGroup.id)"
            
            return [PSCustomObject]@{
                Id = $variableGroup.id
                Name = $variableGroup.name
                Description = $variableGroup.description
                Type = $variableGroup.type
                VariableCount = $variableGroup.variables.PSObject.Properties.Count
                ProjectReference = $variableGroup.variableGroupProjectReferences[0].projectReference.name
                PSTypeName = 'PSU.ADO.VariableGroup'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
