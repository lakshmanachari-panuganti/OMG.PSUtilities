<#
.SYNOPSIS
    Classifies the usage status of an Azure App Registration.

.DESCRIPTION
    Analyzes a hashtable of collected signals to determine whether an app is
    actively used, likely used, or unused. Returns a usage confidence level
    (High, Medium, Low) and the most recent usage date.

    Priority order for usage determination:
    1. Real sign-in dates (High confidence)
    2. Federated credentials / external system usage (High confidence)
    3. Configuration signals (roles, grants, assignments) (Medium confidence)
    4. No signal found (Low confidence - likely unused)

.PARAMETER Signals
    A hashtable containing all collected signals for the app. Expected keys:
    LastInteractiveSignInDate, LastSPSignInDate, AppRoleAssignmentCount,
    ConsumedByAppsCount, OAuthGrantCount, DirectoryRoleCount, AzureRBACRoleCount,
    FederatedCredentialCount, AssignedUsersCount, AssignedGroupsCount,
    UsedByExternalSystem.

.EXAMPLE
    $usage = Get-PSUAppUsageStatus -Signals $signalHashtable
    $usage.IsUnused          # $false
    $usage.UsageConfidence   # "High"
    $usage.LastUsedDate      # 2026-01-15T10:30:00Z

    Classifies the usage status of an app with collected signals.

.OUTPUTS
    [Hashtable] with keys: IsUnused (bool), UsageConfidence (string),
    LastUsedDate (datetime/string), UnusedMoreThan1Year (bool), DaysSinceLastUse (int).

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 7th March 2026
    Last Modified: 7th March 2026
    Version: 1.0

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
#>
function Get-PSUAppUsageStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Signals
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Classifying usage status"
    }

    process {
        # Step 1: Most recent confirmed sign-in date
        $candidates = @($Signals.LastInteractiveSignInDate, $Signals.LastSPSignInDate) |
            Where-Object { $_ -is [datetime] } |
            Sort-Object -Descending
        $LastUsedDate = if ($candidates.Count -gt 0) { $candidates[0] } else { $null }

        # Step 2: Any non-date usage signal
        $hasConfigSignal = (
            $Signals.AppRoleAssignmentCount -gt 0 -or
            $Signals.ConsumedByAppsCount -gt 0 -or
            $Signals.OAuthGrantCount -gt 0 -or
            $Signals.DirectoryRoleCount -gt 0 -or
            $Signals.AzureRBACRoleCount -gt 0 -or
            $Signals.FederatedCredentialCount -gt 0 -or
            $Signals.AssignedUsersCount -gt 0 -or
            $Signals.AssignedGroupsCount -gt 0
        )

        # Step 3: Classify with confidence
        if ($null -ne $LastUsedDate) {
            $IsUnused = $false
            $UsageConfidence = "High"
        } elseif ($Signals.UsedByExternalSystem) {
            $IsUnused = $false
            $UsageConfidence = "High"
            $LastUsedDate = "FederatedActive"
        } elseif ($hasConfigSignal) {
            $IsUnused = $false
            $UsageConfidence = "Medium"
            $LastUsedDate = "SignalFound-NoDate"
        } else {
            $IsUnused = $true
            $UsageConfidence = "Low"
            $LastUsedDate = "NoSignal"
        }

        # Step 4: Age classification
        $UnusedMoreThan1Year = $false
        if ($IsUnused) {
            $UnusedMoreThan1Year = $true
        } elseif ($LastUsedDate -is [datetime] -and $LastUsedDate -lt (Get-Date).AddDays(-365)) {
            $UnusedMoreThan1Year = $true
        }

        # Step 5: Days since last use
        $DaysSinceLastUse = if ($LastUsedDate -is [datetime]) {
            [int]((Get-Date) - $LastUsedDate).TotalDays
        } else { -1 }

        return @{
            IsUnused            = $IsUnused
            UsageConfidence     = $UsageConfidence
            LastUsedDate        = $LastUsedDate
            UnusedMoreThan1Year = $UnusedMoreThan1Year
            DaysSinceLastUse    = $DaysSinceLastUse
        }
    }
}
