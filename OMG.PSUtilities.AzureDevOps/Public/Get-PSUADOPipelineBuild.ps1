function Get-PSUADOPipelineBuild {
    <#
    .SYNOPSIS
        Get details about a specific Azure DevOps pipeline build.

    .DESCRIPTION
        This function connects to Azure DevOps using your Personal Access Token (PAT) and fetches information about a particular pipeline build. It returns details like the build ID, pipeline name, when it was queued, its status, result, and a link to view the build in Azure DevOps.

    .PARAMETER BuildId
        (Mandatory) The build ID of the pipeline run to retrieve details for.

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing the build.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        Get-PSUADOPipelineBuild -Organization "omg" -Project "psutilities" -BuildId 12345

        Retrieves details for build ID 12345 in the psutilities project.

    .EXAMPLE
        Get-PSUADOPipelineBuild -Organization "omg" -Project "psutilities" -BuildId 67890

        Retrieves details for build ID 67890 in the psutilities project.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date  : 2025-06-16 : Initial development
    
    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://learn.microsoft.com/en-us/rest/api/azure/devops/build/builds/get

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$BuildId,

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
    begin{
        $headers = Get-PSUAdoAuthHeader -PAT $PAT
    }
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

            Write-Verbose "Escaping project name for the URL..."
            
            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            }
            else {
                [uri]::EscapeDataString($Project)
            }

            $buildUrl = "https://dev.azure.com/$Organization/$escapedProject/_apis/build/builds/$($BuildId)?api-version=7.1-preview.7"
            Write-Verbose "Calling Azure DevOps API at: $buildUrl"

            $build = Invoke-RestMethod -Uri $buildUrl -Headers $headers -Method Get -ErrorAction Stop

            if (-not $build) {
                throw "No build found with ID: $BuildId"
            }

            [PSCustomObject]@{
                BuildId       = $build.id
                BuildNumber   = $build.buildNumber
                PipelineName  = $build.definition.name
                Status        = $build.status
                Result        = $build.result
                QueueTime     = if ($build.queueTime) { [datetime]$build.queueTime } else { $null }
                StartTime     = if ($build.startTime) { [datetime]$build.startTime } else { $null }
                FinishTime    = if ($build.finishTime) { [datetime]$build.finishTime } else { $null }
                SourceBranch  = $build.sourceBranch
                SourceVersion = $build.sourceVersion
                TriggeredBy   = $build.requestedFor.displayName
                Reason        = $build.reason
                LogsUrl       = $build.logs.url
                WebLink       = $build._links.web.href
                Repository    = $build.repository.name
                RepositoryUrl = $build.repository.url
                PSTypeName    = 'PSU.ADO.BuildDetails'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
