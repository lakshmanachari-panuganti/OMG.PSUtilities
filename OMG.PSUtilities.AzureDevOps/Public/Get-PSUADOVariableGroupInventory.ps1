function Get-PSUADOVariableGroupInventory {
    <#
    .SYNOPSIS
        Retrieves an inventory of Azure DevOps variable groups across projects.

    .DESCRIPTION
        This function connects to Azure DevOps using a Personal Access Token (PAT) and retrieves 
        comprehensive metadata for variable groups across matching projects. It provides detailed 
        inventory information including creation/modification metadata, variable counts, and 
        optional export capabilities.

        Features:
        - Project filtering with wildcard support
        - Parallel processing using Microsoft ThreadJobs for improved performance
        - Comprehensive error handling and logging
        - Optional CSV export functionality
        - Pipeline support for batch processing
        - Detailed progress reporting
        - Type validation and parameter validation

        Array of variable group inventory objects with the following properties:
        - OrganizationName: The Azure DevOps organization name
        - ProjectName: The project containing the variable group
        - ProjectId: The unique project identifier
        - VariableGroupId: The unique variable group identifier
        - VariableGroupName: The display name of the variable group
        - VariableGroupType: The type of variable group (Vsts or AzureKeyVault)
        - Description: Variable group description (if any)
        - CreatedBy: Display name of the user who created the variable group
        - CreatedDate: Date and time when the variable group was created
        - ModifiedBy: Display name of the user who last modified the variable group
        - ModifiedDate: Date and time when the variable group was last modified
        - VariableCount: Total number of variables in the group
        - SecretVariableCount: Number of secret/encrypted variables
        - IsShared: Whether the variable group is shared across pipelines
        - PSTypeName: Custom type name for formatting

    .PARAMETER Organization
        The name of the Azure DevOps organization. This is the part that appears in your Azure DevOps URL
        (e.g., 'omg' in https://dev.azure.com/omg).

    .PARAMETER PAT
        Azure DevOps Personal Access Token with appropriate permissions. If not provided, the function 
        will attempt to use the $env:ADO_PAT or $env:PAT environment variable. The PAT must have at least 
        'Variable Groups (read)' and 'Project and Team (read)' permissions.

    .PARAMETER $project
        Optional wildcard filter for project names. Supports standard PowerShell wildcard patterns.
        Examples: '*Services*', 'Prod-*', '*API*'
        Default: '*' (all projects)

    .PARAMETER OutputFilePath
        Optional path to export the inventory as a CSV file. If specified, the results will be 
        exported to this location in addition to being returned as objects.

    .PARAMETER IncludeVariableDetails
        Switch parameter to include additional variable-level details in the output. When enabled,
        provides information about variable types and counts by category.

    .PARAMETER ThrottleLimit
        Maximum number of concurrent threads when processing multiple projects using ThreadJobs. 
        Default: 10 (recommended to balance performance with API throttling)
        Range: 1-20

    .EXAMPLE
        Get-PSUADOVariableGroupInventory -Organization 'OMG'

        Retrieves variable group inventory for all projects in the 'OMG' organization.

    .EXAMPLE
        Get-PSUADOVariableGroupInventory -Organization 'OMG' -Project @('ProjectA', 'ProjectB')

        Retrieves variable group inventory for specific projects only.

    .EXAMPLE
        Get-PSUADOVariableGroupInventory -Organization 'OMG' -Project @('*-Prod', '*-Dev') -OutputFilePath 'C:\Reports\VarGroups.csv'

        Retrieves variable groups from projects matching wildcard patterns and exports to CSV.

    .EXAMPLE
        Get-PSUADOVariableGroupInventory -Organization 'OMG' -Filter 'VariableGroupName -like "*prod*"'

        Retrieves variable groups with names containing 'prod'.

    .EXAMPLE
        Get-PSUADOVariableGroupInventory -Organization 'OMG' -ThrottleLimit 15

        Retrieves variable group inventory with higher concurrency (15 parallel threads) for faster processing of large organizations.

    .EXAMPLE
        Get-PSUADOVariableGroupInventory -Organization 'OMG' -IncludeVariableDetails -Verbose

        Retrieves detailed variable group inventory with verbose logging and additional variable metadata.

    .INPUTS
        None

    .OUTPUTS
        [PSCustomObject[]] 

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2025-06-16
        Updated: 2025-07-24 - Added ThreadJobs for parallel processing
        
        Requirements:
        - PowerShell 5.1 or later
        - ThreadJob module (Install-Module ThreadJob) for parallel processing
        - Network access to dev.azure.com
        - Valid Azure DevOps PAT with appropriate permissions
        
        Performance Considerations:
        - Uses Microsoft ThreadJobs for parallel processing of projects
        - Configurable throttle limit to balance speed with API rate limits
        - Includes progress reporting for long-running operations

    .LINK
        https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('OrganizationName', 'Org')]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('PersonalAccessToken', 'Token')]
        [string]$PAT,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('Projects')]
        [string[]]$Project = '*',

        [Parameter()]
        [ValidateScript({
                $directory = Split-Path $_ -Parent
                if ($directory -and -not (Test-Path $directory)) {
                    throw "Directory does not exist: $directory"
                }
                $extension = [System.IO.Path]::GetExtension($_)
                if ($extension -notin @('.csv', '.json', '.xml')) {
                    throw "Output file must have .csv, .json, or .xml extension"
                }
                return $true
            })]
        [string]$OutputFilePath,

        [Parameter()]
        [switch]$IncludeVariableDetails,

        [Parameter()]
        [ValidateRange(1, 20)]
        [int]$ThrottleLimit = 10
    )

    begin {
        Write-Verbose "Starting Azure DevOps Variable Group inventory process"
        
        # Initialize PAT from environment if not provided
        if (-not $PAT) {
            $PAT = $env:ADO_PAT ?? $env:PAT
            if (-not $PAT) {
                throw "Personal Access Token is required. Provide via -PAT parameter or set `$env:ADO_PAT environment variable."
            }
            Write-Verbose "Using Personal Access Token from environment variable"
        }

        # Setup authentication headers
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
        $authHeaders = @{
            Authorization  = "Basic $base64AuthInfo"
            'Content-Type' = 'application/json'
            'Accept'       = 'application/json'
        }

        # Initialize results collection
        $variableGroupInventory = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        Write-Verbose "Authentication configured for organization: $Organization"
        Write-Verbose "Project filter: $Project"
        Write-Verbose "Include variable details: $IncludeVariableDetails"
        Write-Verbose "Throttle limit: $ThrottleLimit"

        # Check if ThreadJob module is available
        $useThreadJobs = $false
        try {
            if (Get-Module -ListAvailable -Name ThreadJob) {
                Import-Module ThreadJob -Force -ErrorAction Stop
                $useThreadJobs = $true
                Write-Verbose "ThreadJob module loaded successfully - parallel processing enabled"
            }
            else {
                Write-Warning "ThreadJob module not found. Install it with: Install-Module ThreadJob"
                Write-Information "Falling back to sequential processing..." -InformationAction Continue
            }
        }
        catch {
            Write-Warning "Failed to load ThreadJob module: $($_.Exception.Message)"
            Write-Information "Falling back to sequential processing..." -InformationAction Continue
        }
    }

    process {
        try {
            # Get filtered projects
            Write-Verbose "Retrieving projects from Azure DevOps..."
            $projectsApiUrl = "https://dev.azure.com/$Organization/_apis/projects" +
            "?api-version=7.1-preview.4&`$top=1000&includeCapabilities=false"
            
            Write-Progress -Activity "Azure DevOps Variable Group Inventory" -Status "Retrieving projects..." -PercentComplete 10
            
            $projectsResponse = Invoke-RestMethod -Uri $projectsApiUrl -Method Get -Headers $authHeaders -ErrorAction Stop

            # Filter projects based on Project parameter
            if ($Project -and $Project.Count -gt 0) {
                $filteredProjects = @()
                foreach ($projectPattern in $Project) {
                    $matchingProjects = $projectsResponse.value | Where-Object { $_.name -like $projectPattern }
                    $filteredProjects += $matchingProjects
                }
                # Remove duplicates if any
                $filteredProjects = $filteredProjects | Sort-Object id -Unique
            }
            else {
                # Process all projects if no Project filter specified
                $filteredProjects = $projectsResponse.value
            }

            if (-not $filteredProjects) {
                Write-Warning "No projects matched the filter: '$Project'"
                Write-Warning "Available projects: $(($projectsResponse.value.name | Sort-Object) -join ', ')"
                return @()
            }

            Write-Verbose "Found $($filteredProjects.Count) matching projects"
            $processingMethod = if ($useThreadJobs -and $filteredProjects.Count -gt 1) { "parallel ($ThrottleLimit threads)" } else { "sequential" }
            Write-Information "Processing $($filteredProjects.Count) projects matching filter '$Project' using $processingMethod processing" -InformationAction Continue

            if ($useThreadJobs -and $filteredProjects.Count -gt 1) {
                # Parallel processing
                Write-Verbose "Starting parallel processing with ThreadJobs"
                
                # Create scriptblock for processing each project
                $scriptBlock = {
                    param($projectObj, $Organization, $AuthHeaders, $IncludeVariableDetails)
                    
                    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
                    
                    try {
                        # Get variable groups for current project
                        $variableGroupsApiUrl = "https://dev.azure.com/$Organization/$($projectObj.name)/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
                        
                        $variableGroupsResponse = Invoke-RestMethod -Uri $variableGroupsApiUrl -Method Get -Headers $AuthHeaders -ErrorAction Stop
                        
                        if ($variableGroupsResponse.value -and $variableGroupsResponse.value.Count -gt 0) {                            
                            foreach ($variableGroup in $variableGroupsResponse.value) {
                                # Calculate variable counts - ensure single integer values
                                $totalVariables = 0
                                $secretVariables = 0
                                
                                if ($variableGroup.variables -and $variableGroup.variables.PSObject.Properties) {
                                    # Get all variable properties and count them properly
                                    $variableProperties = @($variableGroup.variables.PSObject.Properties)
                                    $totalVariables = [int]$variableProperties.Count
                                    $secretProps = @($variableProperties | Where-Object { 
                                            $_.Value -and $_.Value.PSObject.Properties['isSecret'] -and $_.Value.isSecret -eq $true 
                                        })
                                    $secretVariables = [int]$secretProps.Count                                    

                                }
                                $KeyVaultName = if ($variableGroup.providerData -and $variableGroup.providerData.vault) { 
                                    $variableGroup.providerData.vault 
                                }
                                elseif ($variableGroup.providerData -and $variableGroup.providerData.serviceEndpointId) {
                                    # Sometimes Key Vault name is in serviceEndpointId or requires additional API call
                                    "ServiceEndpoint:$($variableGroup.providerData.serviceEndpointId)"
                                }
                                else { 
                                    $null 
                                }
                                # Create inventory object
                                $inventoryItem = [PSCustomObject]@{
                                    OrganizationName    = $Organization
                                    ProjectName         = $projectObj.name
                                    ProjectId           = $projectObj.id
                                    VariableGroupId     = $variableGroup.id
                                    VariableGroupName   = $variableGroup.name
                                    VariableGroupType   = $variableGroup.type ?? 'Vsts'
                                    Description         = $variableGroup.description
                                    CreatedBy           = $variableGroup.createdBy.displayName
                                    CreatedDate         = if ($variableGroup.createdOn) { [datetime]$variableGroup.createdOn } else { $null }
                                    ModifiedBy          = $variableGroup.modifiedBy.displayName
                                    ModifiedDate        = if ($variableGroup.modifiedOn) { [datetime]$variableGroup.modifiedOn } else { $null }
                                    VariableCount       = $totalVariables
                                    SecretVariableCount = if ($IncludeVariableDetails) { $secretVariables } else { $null }
                                    IsShared            = $variableGroup.isShared ?? $false
                                    KeyVaultName        = $KeyVaultName
                                    PSTypeName          = 'PSU.ADO.VariableGroupInventory'
                                }
                                if ($IncludeVariableDetails) {
                                    # Collect variable name and value (omit secrets)
                                    $variableDetails = @()

                                    foreach ($property in $variableProperties) {
                                        $varName = $property.Name
                                        $varValue = if ($property.Value.isSecret -eq $true) {
                                            '********'
                                        }
                                        else {
                                            $property.Value.value
                                        }

                                        $variableDetails += [PSCustomObject]@{
                                            Project           = $projectObj.name
                                            VariableGroupName = $variableGroup.name
                                            VariableName      = $varName
                                            VariableValue     = $varValue
                                            IsSecret          = $property.Value.isSecret -eq $true
                                        }
                                    }
                                    $inventoryItem | Add-Member -MemberType NoteProperty -Name Variables -Value $variableDetails -Force
                                }
                                $results.Add($inventoryItem)
                            }
                        }
                        
                        return @{
                            Success            = $true
                            ProjectName        = $projectObj.name
                            Results            = $results.ToArray()
                            VariableGroupCount = $results.Count
                            ErrorMessage       = $null
                        }
                    }
                    catch {
                        return @{
                            Success            = $false
                            ProjectName        = $projectObj.name
                            Results            = @()
                            VariableGroupCount = 0
                            ErrorMessage       = $_.Exception.Message
                        }
                    }
                }

                # Start ThreadJobs for all projects
                Write-Verbose "Starting $($filteredProjects.Count) ThreadJobs with throttle limit $ThrottleLimit"
                $jobs = @()
                
                foreach ($projectObj in $filteredProjects) {
                    $job = Start-ThreadJob -ScriptBlock $scriptBlock -ArgumentList $projectObj, $Organization, $authHeaders, $IncludeVariableDetails -ThrottleLimit $ThrottleLimit
                    $jobs += $job
                }

                # Monitor job progress and collect results
                $completedJobs = 0
                $totalJobs = $jobs.Count
                
                Write-Verbose "Monitoring $totalJobs ThreadJobs for completion..."
                
                while ($completedJobs -lt $totalJobs) {
                    Start-Sleep -Milliseconds 1000
                    $finishedJobs = $jobs | Where-Object { $_.State -in @('Completed', 'Failed', 'Stopped') }
                    $currentCompleted = $finishedJobs.Count
                    
                    if ($currentCompleted -ne $completedJobs) {
                        $completedJobs = $currentCompleted
                        $percentComplete = [math]::Round(($completedJobs / $totalJobs) * 70) + 20
                        
                        Write-Progress -Activity "Azure DevOps Variable Group Inventory" `
                            -Status "Processing projects in parallel: $completedJobs of $totalJobs completed" `
                            -PercentComplete $percentComplete
                        
                        Write-Verbose "Progress: $completedJobs/$totalJobs jobs completed"
                    }
                }

                # Collect all results
                Write-Verbose "Collecting results from completed ThreadJobs"
                $successfulProjects = 0
                $failedProjects = 0
                
                foreach ($job in $jobs) {
                    try {
                        $jobResult = Receive-Job -Job $job -Wait -ErrorAction Stop
                        
                        if ($jobResult.Success) {
                            Write-Verbose "Successfully processed project '$($jobResult.ProjectName)' - found $($jobResult.VariableGroupCount) variable groups"
                            if ($jobResult.Results -and $jobResult.Results.Count -gt 0) {
                                $variableGroupInventory.AddRange($jobResult.Results)
                            }
                            $successfulProjects++
                        }
                        else {
                            Write-Warning "Failed to process project '$($jobResult.ProjectName)': $($jobResult.ErrorMessage)"
                            $failedProjects++
                        }
                    }
                    catch {
                        Write-Warning "Error receiving job results for project: $($_.Exception.Message)"
                        $failedProjects++
                    }
                    finally {
                        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                    }
                }
                
                Write-Verbose "ThreadJob processing completed. Successful: $successfulProjects, Failed: $failedProjects"
            }
            else {
                # Sequential processing
                Write-Verbose "Using sequential processing (ThreadJobs not available or single project)"
                
                $projectIndex = 0
                $totalProjects = $filteredProjects.Count

                foreach ($projectObj in $filteredProjects) {
                    $projectIndex++
                    $percentComplete = [math]::Round(($projectIndex / $totalProjects) * 70) + 20
                    
                    Write-Progress -Activity "Azure DevOps Variable Group Inventory" `
                        -Status "Processing project: $($projectObj.name) ($projectIndex of $totalProjects)" `
                        -PercentComplete $percentComplete

                    Write-Verbose "Processing project: $($projectObj.name) (ID: $($projectObj.id))"

                    try {
                        # Get variable groups for current project
                        $variableGroupsApiUrl = "https://dev.azure.com/$Organization/$($projectObj.name)/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
                        
                        $variableGroupsResponse = Invoke-RestMethod -Uri $variableGroupsApiUrl -Method Get -Headers $authHeaders -ErrorAction Stop
                        
                        if ($variableGroupsResponse.value -and $variableGroupsResponse.value.Count -gt 0) {
                            Write-Verbose "Found $($variableGroupsResponse.value.Count) variable groups in project '$($projectObj.name)'"
                            
                            foreach ($variableGroup in $variableGroupsResponse.value) {
                                # Calculate variable counts - ensure single integer values
                                $totalVariables = 0
                                $secretVariables = 0
                                
                                if ($variableGroup.variables -and $variableGroup.variables.PSObject.Properties) {
                                    # Get all variable properties and count them properly
                                    $variableProperties = @($variableGroup.variables.PSObject.Properties)
                                    $totalVariables = [int]$variableProperties.Count

                                    $secretProps = @($variableProperties | Where-Object { 
                                            $_.Value -and $_.Value.PSObject.Properties['isSecret'] -and $_.Value.isSecret -eq $true 
                                        })
                                    $secretVariables = [int]$secretProps.Count
                                    
                                }

                                # Create inventory object
                                $inventoryItem = [PSCustomObject]@{
                                    OrganizationName    = $Organization
                                    ProjectName         = $projectObj.name
                                    ProjectId           = $projectObj.id
                                    VariableGroupId     = $variableGroup.id
                                    VariableGroupName   = $variableGroup.name
                                    VariableGroupType   = $variableGroup.type ?? 'Vsts'
                                    Description         = $variableGroup.description
                                    CreatedBy           = $variableGroup.createdBy.displayName
                                    CreatedDate         = if ($variableGroup.createdOn) { [datetime]$variableGroup.createdOn } else { $null }
                                    ModifiedBy          = $variableGroup.modifiedBy.displayName
                                    ModifiedDate        = if ($variableGroup.modifiedOn) { [datetime]$variableGroup.modifiedOn } else { $null }
                                    VariableCount       = $totalVariables
                                    SecretVariableCount = $secretVariables
                                    IsShared            = $variableGroup.isShared ?? $false
                                    KeyVaultName        = if ($variableGroup.providerData) { $variableGroup.providerData.vault } else { $null }
                                    PSTypeName          = 'PSU.ADO.VariableGroupInventory'
                                }

                                if ($IncludeVariableDetails) {
                                    # Collect variable name and value (omit secrets)
                                    $variableDetails = @()

                                    foreach ($property in $variableProperties) {
                                        $varName = $property.Name
                                        $varValue = if ($property.Value.isSecret -eq $true) {
                                            '********'
                                        }
                                        else {
                                            $property.Value.value
                                        }

                                        $variableDetails += [PSCustomObject]@{
                                            Project           = $projectObj.name
                                            VariableGroupName = $variableGroup.name
                                            VariableName      = $varName
                                            VariableValue     = $varValue
                                            IsSecret          = $property.Value.isSecret -eq $true
                                        }
                                    }
                                    $inventoryItem | Add-Member -MemberType NoteProperty -Name Variables -Value $variableDetails -Force
                                }

                                $variableGroupInventory.Add($inventoryItem)
                            }
                        }
                        else {
                            Write-Verbose "No variable groups found in project '$($projectObj.name)'"
                        }
                    }
                    catch {
                        $errorMessage = "Failed to retrieve variable groups for project '$($projectObj.name)': $($_.Exception.Message)"
                        Write-Warning $errorMessage
                        Write-Verbose "Full error details: $($_.Exception | Format-List * | Out-String)"
                        continue
                    }
                }
            }

            Write-Progress -Activity "Azure DevOps Variable Group Inventory" -Status "Generating summary..." -PercentComplete 95

            # Display summary
            if ($variableGroupInventory.Count -eq 0) {
                Write-Information "No variable groups found in the specified projects." -InformationAction Continue
                return @()
            }
            else {
                # Apply Filter if specified (similar to Get-ADUser -Filter)
                $finalResults = $variableGroupInventory
                
                # TODO: Integrate $Filter parameter to enable custom filter expressions
                
                # Calculate summary with proper error handling
                $totalVariables = 0
                foreach ($item in $finalResults) {
                    $count = $item.VariableCount
                    if ($count -is [array]) { 
                        $totalVariables += [int]$count[0] 
                    } 
                    else { 
                        $totalVariables += [int]$count 
                    }
                }

                $summary = @{
                    TotalVariableGroups        = $finalResults.Count
                    ProjectsProcessed          = $filteredProjects.Count
                    ProjectsWithVariableGroups = ($finalResults | Select-Object -Unique ProjectName).Count
                    TotalVariables             = $totalVariables
                }

                Write-Information "Inventory Summary:" -InformationAction Continue
                Write-Information "  - Total Variable Groups: $($summary.TotalVariableGroups)" -InformationAction Continue
                Write-Information "  - Projects Processed: $($summary.ProjectsProcessed)" -InformationAction Continue
                Write-Information "  - Projects with Variable Groups: $($summary.ProjectsWithVariableGroups)" -InformationAction Continue
                Write-Information "  - Total Variables: $($summary.TotalVariables)" -InformationAction Continue

                # Export to file if specified
                if ($OutputFilePath) {
                    Write-Progress -Activity "Azure DevOps Variable Group Inventory" -Status "Exporting results..." -PercentComplete 98
                    
                    $extension = [System.IO.Path]::GetExtension($OutputFilePath).ToLower()
                    
                    try {
                        switch ($extension) {
                            '.csv' {
                                $finalResults | Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding UTF8
                            }
                            '.json' {
                                $finalResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFilePath -Encoding UTF8
                            }
                            '.xml' {
                                $finalResults | Export-Clixml -Path $OutputFilePath -Encoding UTF8
                            }
                        }
                        Write-Information "Results exported to: $OutputFilePath" -InformationAction Continue
                    }
                    catch {
                        Write-Warning "Failed to export results to '$OutputFilePath': $($_.Exception.Message)"
                    }
                }

                Write-Progress -Activity "Azure DevOps Variable Group Inventory" -Status "Complete" -PercentComplete 100 -Completed
                
                # Return the inventory
                return $finalResults.ToArray()
            }
        }
        catch {
            Write-Progress -Activity "Azure DevOps Variable Group Inventory" -Status "Error occurred" -PercentComplete 100 -Completed
            $errorMessage = "Failed to retrieve variable group inventory: $($_.Exception.Message)"
            Write-Error $errorMessage
            throw
        }
    }

    end {
        Write-Verbose "Azure DevOps Variable Group inventory process completed"
    }
}