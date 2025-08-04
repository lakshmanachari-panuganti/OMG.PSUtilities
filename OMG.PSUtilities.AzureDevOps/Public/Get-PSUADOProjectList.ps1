function Get-PSUADOProjectList {
    <#
    .SYNOPSIS
        Retrieves the list of Azure DevOps projects within the specified organization.

    .DESCRIPTION
        Uses Azure DevOps REST API to fetch all visible projects in an organization.
        Leverages environment variables if parameters are not supplied.

    .PARAMETER Organization
        The Azure DevOps organization name. If not provided, uses $env:ORGANIZATION.

    .EXAMPLE
        Get-PSUADOProjectList -Organization 'omgitsolutions'

    .EXAMPLE
        Get-PSUADOProjectList

    .OUTPUTS
        [PSCustomObject[]]

    .NOTES
        Author: Lakshmanachari Panuganti
        2 August 2025: Initial Development

    .LINK
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://github.com/lakshmanachari-panuganti
        https://www.linkedin.com/in/lakshmanachari-panuganti/
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [string]$PAT = $env:PAT
    )

    begin {
        $script:ShouldExit = $false
        if ([string]::IsNullOrWhiteSpace($Organization)) {
            Write-Warning 'A valid Azure DevOps organization is not provided.'
            Write-Host "`nTo fix this, either:"
            Write-Host "  1. Pass the -Organization parameter explicitly, OR" -ForegroundColor Yellow
            Write-Host "  2. Create an environment variable using:" -ForegroundColor Yellow
            Write-Host "     Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<YOUR ADO ORGANIZATION NAME>'`n" -ForegroundColor Cyan
            $script:ShouldExit = $true
            return
        }
        $headers = Get-PSUADOAuthorizationHeader -PAT $PAT
    }

    process {
        if ($script:ShouldExit) {
            return
        }

        $uri = "https://dev.azure.com/$Organization/_apis/projects?api-version=7.1-preview.4"

        try {
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
            if ($response.value) {
                ConvertTo-CapitalizedObject -InputObject $response.value
            }

        }
        catch {
            $PSCmdlet.ThrowTerminatingError("Failed to retrieve project list from ADO: $_")
        }
    }
}

