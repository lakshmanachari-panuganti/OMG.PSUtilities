<#
.SYNOPSIS
    Identifies the external CI/CD system type from federated identity credential issuers.

.DESCRIPTION
    Analyzes the issuer URLs of federated identity credentials to determine
    which external system (GitHub Actions, Azure Kubernetes Service, Terraform Cloud,
    Azure DevOps, AWS, Google Cloud) the app is integrated with.

    Returns "None" if no issuers are provided, or "Unknown" if the issuer
    does not match any known pattern.

.PARAMETER Issuers
    An array of issuer URLs from the federated identity credentials.

.EXAMPLE
    Get-PSUExternalSystemType -Issuers @("https://token.actions.githubusercontent.com")
    # Returns "GitHub Actions"

.EXAMPLE
    Get-PSUExternalSystemType -Issuers @("https://oidc.prod-aks.azure.com/tenant-id")
    # Returns "AKS"

.OUTPUTS
    [String] The identified system type or "Unknown".

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 7th March 2026
    Last Modified: 7th March 2026
    Version: 1.0

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
#>
function Get-PSUExternalSystemType {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string[]]$Issuers
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Evaluating $($Issuers.Count) issuer(s)"

        $FederatedIssuerLabels = @{
            "https://kubernetes.default.svc" = "AKS"
            "https://app.terraform.io"       = "Terraform Cloud"
            "https://vstoken.dev.azure.com"  = "Azure DevOps"
            "https://sts.amazonaws.com"      = "AWS"
        }
    }

    process {
        if ($null -eq $Issuers -or $Issuers.Count -eq 0) {
            return "None"
        }

        $types = [System.Collections.Generic.List[string]]::new()
        foreach ($issuer in $Issuers) {
            $matched = $false
            foreach ($key in $FederatedIssuerLabels.Keys) {
                if ($issuer -like "$key*") {
                    if (-not $types.Contains($FederatedIssuerLabels[$key])) {
                        $types.Add($FederatedIssuerLabels[$key])
                    }
                    $matched = $true
                    break
                }
            }
            if (-not $matched -and -not $types.Contains("Unknown")) {
                $types.Add("Unknown")
            }
        }

        return ($types -join ";")
    }
}
