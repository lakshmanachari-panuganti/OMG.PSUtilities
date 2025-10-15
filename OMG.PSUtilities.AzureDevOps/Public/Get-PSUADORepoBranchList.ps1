<#
.SYNOPSIS
    Retrieves a list of branches for a specified Azure DevOps repository.

.DESCRIPTION
    Connects to the Azure DevOps REST API and fetches all branches (refs/heads) for a given repository within a project.
    Returns an array of custom objects with branch properties, where each property name is capitalized for readability.
    Supports lookup by RepositoryId (GUID) or Repository (name).

.PARAMETER Project
    (Mandatory) The Azure DevOps project name containing the repository.

.PARAMETER RepositoryId
    (Mandatory - ParameterSet: ByRepositoryId) The unique identifier (GUID) of the repository to retrieve branches from.

.PARAMETER Repository
    (Mandatory - ParameterSet: ByRepositoryName) The name of the repository to retrieve branches from.

.PARAMETER Organization
    (Optional) The Azure DevOps organization name under which the project resides.
    Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

.PARAMETER PAT
    (Optional) Personal Access Token for Azure DevOps authentication.
    Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

.EXAMPLE
    Get-PSUADORepoBranchList -Organization "omg" -Project "psutilities" -RepositoryId "12345678-1234-1234-1234-123456789abc"

    Retrieves all branches for the specified repository using RepositoryId.

.EXAMPLE
    Get-PSUADORepoBranchList -Organization "omg" -Project "psutilities" -Repository "AzureDevOps"

    Retrieves all branches for the "AzureDevOps" repository using Repository name.

.EXAMPLE
    $branches = Get-PSUADORepoBranchList -Organization "omg" -Project "psutilities" -Repository "Core"
    $branches | Where-Object { $_.Name -like "*feature*" }

    Retrieves all branches from the "Core" repository and filters for feature branches.

.OUTPUTS
    [PSCustomObject]

.NOTES
    Author: Lakshmanachari Panuganti
    Created: August 2025

.LINK
    https://github.com/lakshmanachari-panuganti
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    https://learn.microsoft.com/en-us/rest/api/azure/devops/git/refs/list
    https://learn.microsoft.com/en-us/azure/devops/repos/git/branches
#>
function Get-PSUADORepoBranchList {
    [CmdletBinding(DefaultParameterSetName = 'ByRepositoryId')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ByRepositoryId')]
        [Parameter(Mandatory, ParameterSetName = 'ByRepositoryName')]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory, ParameterSetName = 'ByRepositoryId')]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryId,

        [Parameter(Mandatory, ParameterSetName = 'ByRepositoryName')]
        [ValidateNotNullOrEmpty()]
        [string]$Repository,

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

            # Create authentication headers ONCE
            $headers = Get-PSUAdoAuthHeader -PAT $PAT
            
            # Escape project name ONCE
            $escapedProject = [uri]::EscapeDataString($Project)

            # Resolve Repository Name to ID if needed
            if ($PSCmdlet.ParameterSetName -eq 'ByRepositoryName') {
                Write-Verbose "Resolving repository name '$Repository' to ID..."
                $escapedRepo = [uri]::EscapeDataString($Repository)
                $repoUri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$escapedRepo?api-version=7.1"
                
                $repoResponse = Invoke-RestMethod -Uri $repoUri -Headers $headers -Method Get -ErrorAction Stop
                
                if (-not $repoResponse.id) {
                    throw "Repository '$Repository' not found in project '$Project'."
                }
                
                $RepositoryId = $repoResponse.id
                Write-Verbose "Resolved repository '$Repository' to ID: $RepositoryId"
            }

            # Fetch branches
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories/$RepositoryId/refs?filter=heads/&api-version=7.1"
            Write-Verbose "Fetching branches from: $uri"

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
            
            # Build results efficiently using List
            $formattedResults = [System.Collections.Generic.List[PSCustomObject]]::new()
            
            if ($response.value) {
                foreach ($item in $response.value) {
                    # Build hashtable first, then create object once
                    $properties = @{}
                    
                    foreach ($property in $item.PSObject.Properties) {
                        # Simple capitalization - preserve rest of the name
                        $capitalizedName = $property.Name.Substring(0,1).ToUpper() + $property.Name.Substring(1)
                        $properties[$capitalizedName] = $property.Value
                    }
                    
                    # Add computed property for clean branch name
                    if ($properties.ContainsKey('Name')) {
                        $properties['BranchName'] = $properties['Name'] -replace '^refs/heads/', ''
                    }
                    
                    # Create object once and add to list
                    $formattedResults.Add([PSCustomObject]$properties)
                }
            }

            return $formattedResults
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
