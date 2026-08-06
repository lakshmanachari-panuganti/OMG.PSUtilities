function Confirm-PSUAdoConnectionParameter {
    <#
    .SYNOPSIS
        Validates the Azure DevOps organization and PAT before a REST call is attempted.

    .DESCRIPTION
        This private helper function throws a terminating error when the organization or the
        Personal Access Token is missing. Both values usually come from the $env:ORGANIZATION and
        $env:PAT defaults, and ValidateNotNullOrEmpty does not check parameter default values, so
        the check has to happen at runtime.

        Every public Azure DevOps command calls this helper in its begin block, which keeps the
        guidance in the error message identical across the module.

    .PARAMETER Organization
        The Azure DevOps organization name to validate.

    .PARAMETER PAT
        The Personal Access Token to validate.

    .OUTPUTS
        None

    .EXAMPLE
        Confirm-PSUAdoConnectionParameter -Organization $Organization -PAT $PAT

        Throws when either value is missing, otherwise returns without output.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 6th August 2026

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization,

        [Parameter()]
        [string]$PAT
    )

    if (-not $Organization) {
        throw "The default value for the 'ORGANIZATION' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>' or provide via -Organization parameter."
    }

    if (-not $PAT) {
        throw "The default value for the 'PAT' environment variable is not set.`nSet it using: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<pat>' or provide via -PAT parameter."
    }
}
