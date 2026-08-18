function Get-PSUAdoAuthHeader {
    <#
    .SYNOPSIS
        Constructs the Authorization header for Azure DevOps REST API requests.

    .DESCRIPTION
        This private helper function returns a hashtable containing the 'Authorization' and 'Content-Type' headers
        required to communicate with the Azure DevOps REST API. It prioritizes values from the environment variable
        $env:PAT but allows override via parameters.

    .PARAMETER PAT
        The Personal Access Token used to authenticate with Azure DevOps REST API.

    .OUTPUTS
        [Hashtable]

    .EXAMPLE
        $headers = Get-PSUAdoAuthHeader

    .EXAMPLE
        $headers = Get-PSUAdoAuthHeader -PAT "YourPATvalue"

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2 July 2025: Initial Development.

    .LINK
        https://github.com/lakshmanachari-panuganti
        https://www.linkedin.com/in/lakshmanachari-panuganti
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        Install-Module -Name OMG.PSUtilities.AzureDevOps
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'The guidance shown when no token is configured is addressed to an operator at the console and must stay visible. It names commands only and carries no token value.'
    )]
    param (
        [Parameter()]
        [string] $PAT = $env:PAT
    )

    # Single point of PAT resolution for the whole module. Every public command routes its
    # token through here, so this is the only place that needs to know where a token can come
    # from, and the plaintext exists only long enough to build the header below.
    #
    # Resolution triggers on an empty value rather than on the parameter being unbound,
    # because commands chain internally and splat their own $PAT onward; an inner call
    # therefore receives an explicitly bound but empty value when nothing was configured.
    #
    # The environment variable still wins where it is set, because it remains the parameter
    # default across the public commands. That is the documented compatibility behaviour for
    # the deprecation window; Credential Manager covers the case where it is not set, so
    # secure storage works without anyone having to export a token first.
    if ([string]::IsNullOrWhiteSpace($PAT)) {
        try {
            $PAT = Get-PSUSecret -Name 'PAT' -AsPlainText
        }
        catch {
            Write-Verbose 'No stored secret found for PAT.'
        }
    }

    if ([string]::IsNullOrWhiteSpace($PAT)) {
        Write-Warning 'A valid Azure DevOps PAT is not provided.'
        Write-Host "`nTo fix this, either:"
        Write-Host "  1. Pass the -PAT parameter explicitly, OR" -ForegroundColor Yellow
        Write-Host "  2. Store it securely, which is preferred:" -ForegroundColor Yellow
        Write-Host "     Set-PSUCredentialToManager -Target 'PAT'" -ForegroundColor Cyan
        Write-Host "  3. Or configure the legacy environment variable:" -ForegroundColor Yellow
        Write-Host "     Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<YOUR ADO PAT>'`n" -ForegroundColor Cyan
        
        # Return empty hashtable to ensure consistent return type and clear error
        throw "Azure DevOps PAT is required but not provided. Please set the PAT parameter or environment variable."
    }
    
    $encodedPAT = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
    @{
        Authorization  = "Basic $encodedPAT"
        'Content-Type' = 'application/json'
    }

}
