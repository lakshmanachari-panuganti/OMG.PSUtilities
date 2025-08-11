function Get-PSUADORepositories {
    <#
    .SYNOPSIS
        Retrieves all repositories from Azure DevOps for a given organization and project.

    .DESCRIPTION
        This function queries the Azure DevOps REST API to get all repositories in the specified organization and project.

    .PARAMETER Project
        The name of the Azure DevOps project.

    .PARAMETER Organization
        The Azure DevOps organization. If not provided, defaults to the ORGANIZATION environment variable.

    .PARAMETER PAT
        The Personal Access Token for authentication. If not provided, defaults to the PAT environment variable.

    .OUTPUTS
        [PSCustomObject]

    .EXAMPLE
        Get-PSUADORepositories -Project "PSUtilities"

        Retrieves all repositories in the "PSUtilities" project under the organization specified in $env:ORGANIZATION.

    .EXAMPLE
        Get-PSUADORepositories -Project "PSUtilities" -Organization "omgitsolutions" -PAT "<YourPAT>"

        Retrieves all repositories explicitly using provided organization and PAT.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2 July 2025: Initial Development.

    .LINK
        https://www.github.com/lakshmanachari-panuganti
        https://www.linkedin.com/in/lakshmanachari-panuganti
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        Install-Module -Name OMG.PSUtilities.AzureDevOps
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Project,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )
    process {
        $headers = Get-PSUAdoAuthHeader -PAT $PAT
        $uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories?api-version=7.1-preview.1"

        try {
            $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
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
                    ProjectName     = $_.project.name
                    ProjectId       = $_.project.id
                    PSTypeName      = 'PSU.ADO.Repository'
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
