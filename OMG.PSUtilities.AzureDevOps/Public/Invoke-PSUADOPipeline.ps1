function Invoke-PSUADOPipeline {
    <#
    .SYNOPSIS
        Triggers an Azure DevOps pipeline by pipeline ID and branch.

    .DESCRIPTION
        Starts a new run of the specified Azure DevOps pipeline using the REST API.
        Optionally triggers the pipeline for a specific branch.
        Returns pipeline run details including run ID, status, and web URL.
        Requires a valid Organization and PAT with build permissions.

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing the pipeline.
        Example: "psutilities".

    .PARAMETER PipelineId
        (Mandatory) The ID of the pipeline to trigger.
    .PARAMETER Branch
        (Optional) The branch name to run the pipeline for. Example: "feature/dev".

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name.
        Default is $env:ORGANIZATION.
        Set via: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default is $env:PAT.
        Set via: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        Invoke-PSUADOPipeline -Project "psutilities" -PipelineId 42

        Triggers pipeline ID 42 in the "psutilities" project using environment variables for Organization and PAT.

    .EXAMPLE
        Invoke-PSUADOPipeline -Project "psutilities" -PipelineId 42 -Branch "feature/dev"

        Triggers pipeline ID 42 in the "psutilities" project for branch "feature/dev".

    .EXAMPLE
        Invoke-PSUADOPipeline -Project "psutilities" -PipelineId 42 -Organization "omg" -PAT "xxxx" -Branch "main"

        Triggers pipeline ID 42 in the "psutilities" project for organization "omg" and branch "main" with explicit PAT.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Created: 2025-10-25

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://learn.microsoft.com/en-us/rest/api/azure/devops/pipelines/runs/run-pipeline?view=azure-devops-rest-7.1
    #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]$Project,

            [Parameter(Mandatory)]
            [int]$PipelineId,

            [Parameter()]
            [string]$Branch,

            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [string]$Organization = $env:ORGANIZATION,

            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [string]$PAT = $env:PAT
        )

        begin {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Parameters:"
            foreach ($param in $PSBoundParameters.GetEnumerator()) {
                if ($param.Key -eq 'PAT') {
                    $maskedPAT = if ($param.Value -and $param.Value.Length -ge 3) { $param.Value.Substring(0, 3) + "********" } else { "***" }
                    Write-Verbose "  $($param.Key): $maskedPAT"
                } else {
                    Write-Verbose "  $($param.Key): $($param.Value)"
                }
            }

            if ([string]::IsNullOrWhiteSpace($Organization)) {
                throw "Organization parameter is required. Set via: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<your-organization>'"
            }
            if ([string]::IsNullOrWhiteSpace($PAT)) {
                throw "PAT parameter is required. Set via: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<your-pat>'"
            }

            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
            $headers = @{
                Authorization = "Basic $base64AuthInfo"
                'Content-Type' = 'application/json'
            }
        }

        process {
            $escapedProject = [uri]::EscapeDataString($Project)
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/pipelines/$PipelineId/runs?api-version=7.1-preview.1"
            Write-Verbose "Triggering pipeline: $PipelineId in project: $Project"
            Write-Verbose "API URI: $uri"

            $body = if ($Branch) {
                @{ resources = @{ repositories = @{ self = @{ refName = "refs/heads/$Branch" } } } } | ConvertTo-Json -Depth 5
            } else {
                '{}' # Default body triggers default branch
            }

            try {
                $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $body -ErrorAction Stop
                [PSCustomObject]@{
                    PipelineId   = $PipelineId
                    Project      = $Project
                    Organization = $Organization
                    Branch       = $Branch
                    RunId        = $response.id
                    Status       = $response.state
                    Url          = $response._links.web.href
                    PSTypeName   = 'PSU.ADO.PipelineRun'
                }
            } catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
}