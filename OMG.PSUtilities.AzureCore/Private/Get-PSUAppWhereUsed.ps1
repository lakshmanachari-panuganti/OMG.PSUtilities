<#
.SYNOPSIS
    Summarizes where an Azure App Registration is used across the environment.

.DESCRIPTION
    Analyzes a hashtable of collected signals and produces a human-readable
    summary of all locations/systems where the app is actively referenced.
    Returns "NoUsageSignalFound" if no evidence of usage exists.

    Usage locations include: user sign-ins, daemon sign-ins, API consumers,
    Azure RBAC scopes, external CI/CD systems, assigned groups, and exposed APIs.

.PARAMETER Signals
    A hashtable containing all collected signals for the app. Expected keys:
    LastSignInResourceName, DaemonUsageDetected, LastSPSignInResourceName,
    AppRoleAssignedResources, ConsumedByApps, AzureRBACScopes,
    UsedByExternalSystem, ExternalSystemType, AssignedGroupNames, IsApiProvider,
    ExposedPermissions.

.EXAMPLE
    $summary = Get-PSUAppWhereUsed -Signals $signalHashtable
    # "UserSignIn->Microsoft Graph | AzureScope->/subscriptions/abc123"

    Gets a usage location summary for an app.

.OUTPUTS
    [String] Pipe-delimited summary of usage locations, or "NoUsageSignalFound".

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 7th March 2026
    Last Modified: 7th March 2026
    Version: 1.0

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
#>
function Get-PSUAppWhereUsed {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Signals
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Building usage summary"
    }

    process {
        $locations = [System.Collections.Generic.List[string]]::new()

        if ($Signals.LastSignInResourceName -ne "NoData") {
            $locations.Add("UserSignIn->$($Signals.LastSignInResourceName)")
        }
        if ($Signals.DaemonUsageDetected) {
            $locations.Add("DaemonSignIn->$($Signals.LastSPSignInResourceName)")
        }
        if ($Signals.AppRoleAssignedResources -ne "None") {
            $locations.Add("CallsAPI->$($Signals.AppRoleAssignedResources)")
        }
        if ($Signals.ConsumedByApps -ne "") {
            $locations.Add("ConsumedBy->$($Signals.ConsumedByApps)")
        }
        if ($Signals.AzureRBACScopes -ne "None") {
            $locations.Add("AzureScope->$($Signals.AzureRBACScopes)")
        }
        if ($Signals.UsedByExternalSystem) {
            $locations.Add("ExternalSystem->$($Signals.ExternalSystemType)")
        }
        if ($Signals.AssignedGroupNames -ne "") {
            $locations.Add("AssignedGroups->$($Signals.AssignedGroupNames)")
        }
        if ($Signals.IsApiProvider) {
            $locations.Add("ExposesAPI->$($Signals.ExposedPermissions)")
        }

        return if ($locations.Count -gt 0) { $locations -join " | " } else { "NoUsageSignalFound" }
    }
}
