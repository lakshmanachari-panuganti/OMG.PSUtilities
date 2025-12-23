function Get-PSUADORepositories {
    <#
    .SYNOPSIS
        Retrieves all repositories from Azure DevOps for a given organization and project.

    .DESCRIPTION
        This function queries the Azure DevOps REST API to get all repositories in the specified organization and project.

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing the repositories.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name under which the project resides.
        Default value is $env:ORGANIZATION. Set using: Set-PSUUserEnvironmentVariable -Name "ORGANIZATION" -Value "your_org_name"

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default value is $env:PAT. Set using: Set-PSUUserEnvironmentVariable -Name "PAT" -Value "your_pat_token"

    .EXAMPLE
        Get-PSUADORepositories -Organization "omg" -Project "psutilities"

        Retrieves all repositories in the "psutilities" project.

    .EXAMPLE
        Get-PSUADORepositories -Project "psutilities"

        Retrieves all repositories using the organization from $env:ORGANIZATION.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2 July 2025: Initial Development.

    .LINK
        https://www.github.com/lakshmanachari-panuganti
        https://www.linkedin.com/in/lakshmanachari-panuganti
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        Install-Module -Name OMG.PSUtilities.AzureDevOps -Repository PSGallery
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
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
            # Escape project name for URI
            $escapedProject = if ($Project -match '%[0-9A-Fa-f]{2}') {
                $Project
            } else {
                [uri]::EscapeDataString($Project)
            }
            
            $uri = "https://dev.azure.com/$Organization/$escapedProject/_apis/git/repositories?api-version=7.1-preview.1"

            $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -Verbose:$false
            $response.value | ForEach-Object {
                [PSCustomObject]@{
                    Id              = $_.id
                    Name            = $_.name
                    DefaultBranch   = $_.defaultBranch
                    IsDisabled      = $_.isDisabled
                    IsInMaintenance = $_.isInMaintenance
                    Size            = $_.size
                    SshUrl          = $_.sshUrl
                    RemoteUrl       = $_.remoteUrl
                    WebUrl          = $_.webUrl
                    Project         = $_.project.name
                    ProjectId       = $_.project.id
                    PSTypeName      = 'PSU.ADO.Repository'
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
