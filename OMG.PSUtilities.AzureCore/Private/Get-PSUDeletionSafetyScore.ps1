<#
.SYNOPSIS
    Calculates a Deletion Safety Score for an Azure App Registration.

.DESCRIPTION
    Evaluates a hashtable of collected signals about an App Registration and
    produces a score from 0-100 indicating how safe it is to delete. Higher
    score = safer to delete. Lower score = higher risk.

    The scoring engine applies weighted deductions for evidence of active use
    (sign-ins, consumers, RBAC roles, etc.) and bonuses for indicators of
    abandonment (no SP, all secrets expired, old age with no sign-in).

    Microsoft 1st-party apps always return score 0 (never touch).

.PARAMETER Signals
    A hashtable containing all collected signals for the app. Expected keys:
    IsMicrosoftApp, ConsumedByAppsCount, HasPrivilegedEntraRole,
    HasPrivilegedAzureRole, AssignedUsersCount, SPLastSignInDate,
    SPLastDaemonSignInDate, LastInteractiveSignInDate, DaemonUsageDetected,
    UsedByExternalSystem, ExternalSystemType, HasAzureRBACRoles,
    AzureRBACRoleCount, AssignedGroupsCount, AdminConsentGranted,
    AppRoleAssignmentCount, OAuthGrantCount, IsApiProvider, ExposedScopeCount,
    DirectoryRoleCount, HasExpiredSecret, SecretCount, HasExpiredCert,
    CertCount, IsCoveredByCAPolicy, NoServicePrincipal, AllSecretsExpired,
    AppAgeDays, IsVerifiedPublisher.

.EXAMPLE
    $score = Get-PSUDeletionSafetyScore -Signals $signalHashtable
    $score.Score        # 85
    $score.ScoreReasons # "+NoSP|+OldUnused:1200d"

    Calculates the deletion safety score for an app with collected signals.

.OUTPUTS
    [Hashtable] with keys: Score (int 0-100), ScoreReasons (string, pipe-delimited).

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 7th March 2026
    Last Modified: 7th March 2026
    Version: 1.0

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
#>
function Get-PSUDeletionSafetyScore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Signals
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Calculating score"
    }

    process {
        $score = 100
        $reasons = [System.Collections.Generic.List[string]]::new()

        # -- INSTANT OVERRIDE: Microsoft 1st-party apps -----------------------
        if ($Signals.IsMicrosoftApp) {
            return @{
                Score        = 0
                ScoreReasons = "Microsoft1stPartyApp"
            }
        }

        # -- HARD BLOCKS (score floor = 0, do not touch) ----------------------
        if ($Signals.ConsumedByAppsCount -gt 0) {
            $score -= 70
            $reasons.Add("ConsumedBy:$($Signals.ConsumedByAppsCount)apps")
        }
        if ($Signals.HasPrivilegedEntraRole) {
            $score -= 60
            $reasons.Add("PrivilegedEntraRole")
        }
        if ($Signals.HasPrivilegedAzureRole) {
            $score -= 60
            $reasons.Add("PrivilegedAzureRole")
        }
        if ($Signals.AssignedUsersCount -gt 100) {
            $score -= 70
            $reasons.Add("ManyAssignedUsers:$($Signals.AssignedUsersCount)")
        }

        # -- STRONG EVIDENCE OF ACTIVE USE ------------------------------------

        # Use ALL-TIME sign-in date from signInActivity first (more reliable than audit logs)
        $bestSignInDate = $null
        if ($null -ne $Signals.SPLastSignInDate) { $bestSignInDate = $Signals.SPLastSignInDate }
        if ($null -ne $Signals.SPLastDaemonSignInDate -and
            ($null -eq $bestSignInDate -or $Signals.SPLastDaemonSignInDate -gt $bestSignInDate)) {
            $bestSignInDate = $Signals.SPLastDaemonSignInDate
        }
        # Overlay audit log dates if they are more recent
        if ($null -ne $Signals.LastInteractiveSignInDate -and
            ($null -eq $bestSignInDate -or $Signals.LastInteractiveSignInDate -gt $bestSignInDate)) {
            $bestSignInDate = $Signals.LastInteractiveSignInDate
        }

        if ($null -ne $bestSignInDate) {
            $daysSince = [int]((Get-Date) - $bestSignInDate).TotalDays
            if ($daysSince -le 30) { $score -= 60; $reasons.Add("SignIn:${daysSince}dAgo") }
            elseif ($daysSince -le 90) { $score -= 50; $reasons.Add("SignIn:${daysSince}dAgo") }
            elseif ($daysSince -le 180) { $score -= 35; $reasons.Add("SignIn:${daysSince}dAgo") }
            elseif ($daysSince -le 365) { $score -= 20; $reasons.Add("SignIn:${daysSince}dAgo") }
            elseif ($daysSince -le 730) { $score -= 10; $reasons.Add("SignIn:${daysSince}dAgo") }
        }
        if ($Signals.DaemonUsageDetected) {
            $score -= 40
            $reasons.Add("DaemonSignInDetected")
        }
        if ($Signals.UsedByExternalSystem) {
            $score -= 50
            $reasons.Add("FederatedCreds:$($Signals.ExternalSystemType)")
        }
        if ($Signals.HasAzureRBACRoles) {
            $score -= 40
            $reasons.Add("AzureRBACRoles:$($Signals.AzureRBACRoleCount)")
        }

        # -- MODERATE EVIDENCE ------------------------------------------------
        if ($Signals.AssignedUsersCount -gt 0 -and $Signals.AssignedUsersCount -le 100) {
            $score -= 40
            $reasons.Add("AssignedUsers:$($Signals.AssignedUsersCount)")
        }
        if ($Signals.AssignedGroupsCount -gt 0) {
            $score -= 35
            $reasons.Add("AssignedGroups:$($Signals.AssignedGroupsCount)")
        }
        if ($Signals.AdminConsentGranted) {
            $score -= 20
            $reasons.Add("AdminConsentGranted")
        }
        if ($Signals.AppRoleAssignmentCount -gt 0) {
            $score -= 15
            $reasons.Add("OutboundAPIAssignments:$($Signals.AppRoleAssignmentCount)")
        }
        if ($Signals.OAuthGrantCount -gt 0) {
            $score -= 15
            $reasons.Add("OAuthGrants:$($Signals.OAuthGrantCount)")
        }
        if ($Signals.IsApiProvider) {
            $score -= 25
            $reasons.Add("ExposesAPI:$($Signals.ExposedScopeCount)scopes")
        }
        if ($Signals.DirectoryRoleCount -gt 0) {
            $score -= 20
            $reasons.Add("DirectoryRoles:$($Signals.DirectoryRoleCount)")
        }

        # -- WEAK EVIDENCE (configuration exists, may or may not be in use) ---
        if (-not $Signals.HasExpiredSecret -and $Signals.SecretCount -gt 0) {
            $score -= 10
            $reasons.Add("ActiveSecret")
        }
        if (-not $Signals.HasExpiredCert -and $Signals.CertCount -gt 0) {
            $score -= 10
            $reasons.Add("ActiveCert")
        }
        if ($Signals.IsCoveredByCAPolicy) {
            $score -= 10
            $reasons.Add("CAProtected")
        }

        # -- POSITIVE SIGNALS (increases confidence it is truly unused) -------
        if ($Signals.NoServicePrincipal) {
            $score += 10
            $reasons.Add("+NoSP")
        }
        # AllSecretsExpired = ALL secrets expired (not just "any expired")
        if ($Signals.AllSecretsExpired -and $Signals.CertCount -eq 0 -and -not $Signals.UsedByExternalSystem) {
            $score += 5
            $reasons.Add("+AllSecretsExpired")
        }
        # App age factor: older unused apps are safer to clean up
        if ($Signals.AppAgeDays -gt 730 -and $null -eq $bestSignInDate) {
            $score += 10
            $reasons.Add("+OldUnused:$($Signals.AppAgeDays)d")
        }
        if ($Signals.AppAgeDays -lt 30) {
            $score -= 15
            $reasons.Add("NewlyCreated:$($Signals.AppAgeDays)d")
        }
        # Verified publisher bonus (legitimate SaaS apps from known vendors)
        if ($Signals.IsVerifiedPublisher) {
            $score -= 5
            $reasons.Add("VerifiedPublisher")
        }

        # Clamp to 0-100
        $score = [Math]::Max(0, [Math]::Min(100, $score))

        return @{
            Score        = $score
            ScoreReasons = $reasons -join "|"
        }
    }
}
