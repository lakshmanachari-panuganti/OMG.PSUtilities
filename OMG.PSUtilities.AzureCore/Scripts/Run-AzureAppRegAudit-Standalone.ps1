<#
.SYNOPSIS
    Standalone Azure App Registration Audit Script (no module dependencies).

.DESCRIPTION
    A single self-contained script that performs a comprehensive audit of all
    Azure App Registrations in a tenant. No external PowerShell module functions
    are required — all scoring, classification, and bucketing logic is inline.

    Collects 13 signals per app, calculates a Deletion Safety Score (0-100),
    assigns each app to one of four cleanup buckets, and exports actionable CSVs.

    Architecture: Auth -> Bulk-Load -> Per-App Signals -> Score -> Bucket -> Export

    Four cleanup buckets:
    - Bucket 1 (SafeToDisable)      : Score 80-100
    - Bucket 2 (NeedsInvestigation) : Score 50-79
    - Bucket 3 (LikelyActive)       : Score 20-49
    - Bucket 4 (BusinessCritical)   : Score 0-19

    No automatic deletions. 100% read-only. All actions require human review.

.PARAMETER AuditMode
    Quick  : Skip per-app sign-in log queries (~30 min for 9,000 apps)
    Full   : Collect all 13 signals including sign-in logs (~3-4 hrs)
    DryRun : Process only -DryRunCount apps for testing (~2-5 min)
    Default: Quick

.PARAMETER TenantId
    (Optional) Entra ID tenant ID. Auto-detected from Graph context if omitted.

.PARAMETER OutputRoot
    (Optional) Root folder for audit output. A timestamped subfolder is created.
    Default: C:\AuditOutput

.PARAMETER DryRunCount
    (Optional) Number of apps to process in DryRun mode. Default: 50.

.PARAMETER SkipAzureRBAC
    (Optional) Skip Azure RBAC data collection.

.PARAMETER ThrottleDelayMs
    (Optional) Delay in ms between per-app Graph calls. Default: 200.

.EXAMPLE
    .\Run-AzureAppRegAudit-Standalone.ps1
    # Quick audit with defaults

.EXAMPLE
    .\Run-AzureAppRegAudit-Standalone.ps1 -AuditMode DryRun -DryRunCount 20 -SkipAzureRBAC
    # Test run with 20 apps, no Azure RBAC

.EXAMPLE
    .\Run-AzureAppRegAudit-Standalone.ps1 -AuditMode Full -OutputRoot "D:\Audits"
    # Full audit with all signals

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 8th March 2026
    Version: 1.0
    Prerequisites: PowerShell 7.2+, Microsoft.Graph modules, Az.Resources (optional)
#>

#Requires -Version 7.2

[CmdletBinding(SupportsShouldProcess)]
param (
    [ValidateSet("Quick", "Full", "DryRun")]
    [string]$AuditMode = "Quick",

    [string]$TenantId,

    [string]$OutputRoot = "C:\AuditOutput",

    [int]$DryRunCount = 50,

    [switch]$SkipAzureRBAC,

    [int]$ThrottleDelayMs = 200
)

$ErrorActionPreference = "Stop"
$scriptStart = Get-Date

# ────────────────────────────────────────────────────────────────
#  CONSTANTS
# ────────────────────────────────────────────────────────────────
$MicrosoftTenantId = "f8cdef31-a31e-4b4a-93e4-5f571e91255a"
$graphResourceId = "00000003-0000-0000-c000-000000000000"
$DateStamp = Get-Date -Format "yyyyMMdd"

$GraphScopes = @(
    "Application.Read.All",
    "Directory.Read.All",
    "AuditLog.Read.All",
    "Policy.Read.All"
)

$BroadPermissions = @{
    "df021288-bdef-4463-88db-98f22de89214" = "User.ReadWrite.All"
    "62a82d76-70ea-41e2-9197-370581804d09" = "Group.ReadWrite.All"
    "19dbc75e-c2e2-444c-a770-ec69d8559fc7" = "Directory.ReadWrite.All"
    "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8" = "RoleManagement.ReadWrite.Directory"
    "e2a3a72e-5f79-4c64-b1b1-878b674786c9" = "Mail.ReadWrite"
    "75359482-378d-4052-8f01-80520e7db3cd" = "Files.ReadWrite.All"
    "dc50a0fb-09a3-484d-be87-e023b12c6440" = "SecurityEvents.ReadWrite.All"
    "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9" = "Application.ReadWrite.All"
    "dbaae8cf-10b5-4b86-a4a1-f871c94c6571" = "GroupMember.ReadWrite.All"
    "9492366f-7969-46a4-8d15-ed1a20078fff" = "Sites.ReadWrite.All"
    "6931bccd-447a-43d1-b442-00a195474b6c" = "MailboxSettings.ReadWrite"
    "ef54d2bf-783f-4e0f-bca1-3210c0444d99" = "Calendars.ReadWrite"
    "741f803b-c850-494e-b5df-cde7c675a1ca" = "User.ReadWrite.All (Delegated)"
}

$PrivilegedEntraRoles = @(
    "Global Administrator", "Privileged Role Administrator",
    "Application Administrator", "Cloud Application Administrator",
    "Exchange Administrator", "SharePoint Administrator"
)

$PrivilegedAzureRoles = @("Owner", "Contributor", "User Access Administrator")

$FederatedIssuerLabels = @{
    "https://kubernetes.default.svc"              = "AKS"
    "https://app.terraform.io"                    = "Terraform Cloud"
    "https://vstoken.dev.azure.com"               = "Azure DevOps"
    "https://sts.amazonaws.com"                   = "AWS"
}

$OwnerNotificationColumns = @(
    "AppName", "AppId", "DeletionSafetyScore", "BucketLabel", "RecommendedAction",
    "LastUsedDate", "UsageConfidence", "UsageLocationSummary", "DeletionBlastRadius",
    "HasExpiredSecret", "OldestSecretAgeDays", "AuthMethod", "CreatedDate"
)

# ────────────────────────────────────────────────────────────────
#  INLINE HELPER FUNCTIONS (replaces private module functions)
# ────────────────────────────────────────────────────────────────

function Write-Log {
    param(
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [string]$Signal = "General",
        [string]$Message
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] [$Level] [$Signal] $Message"
    Add-Content -Path $script:LogFile -Value $entry
    switch ($Level) {
        "ERROR" { Write-Warning $Message }
        "WARN" { Write-Warning $Message }
        "DEBUG" { Write-Verbose $Message }
        default { Write-Host $entry }
    }
}

function Invoke-GraphRetry {
    <# Simple retry wrapper for Graph calls with HTTP 429 handling #>
    param(
        [scriptblock]$ScriptBlock,
        [string]$OperationName = "GraphCall",
        [int]$MaxRetries = 3
    )
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            return & $ScriptBlock
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            if ($statusCode -eq 429) {
                $retryAfter = 30
                try { $retryAfter = [int]$_.Exception.Response.Headers["Retry-After"] } catch {}
                Write-Log "WARN" $OperationName "Throttled. Waiting ${retryAfter}s (attempt $($attempt+1)/$MaxRetries)"
                Start-Sleep -Seconds $retryAfter
                $attempt++
            } else {
                Write-Log "ERROR" $OperationName "HTTP $statusCode - $($_.Exception.Message)"
                return $null
            }
        }
    }
    Write-Log "ERROR" $OperationName "Failed after $MaxRetries retries."
    return $null
}

function Get-DeletionSafetyScore {
    <# Calculates score 0-100 (higher = safer to delete) #>
    param([hashtable]$Signals)

    $score = 100
    $reasons = [System.Collections.Generic.List[string]]::new()

    if ($Signals.IsMicrosoftApp) {
        return @{ Score = 0; ScoreReasons = "Microsoft1stPartyApp" }
    }

    # Hard blocks
    if ($Signals.ConsumedByAppsCount -gt 0) { $score -= 70; $reasons.Add("ConsumedBy:$($Signals.ConsumedByAppsCount)apps") }
    if ($Signals.HasPrivilegedEntraRole) { $score -= 60; $reasons.Add("PrivilegedEntraRole") }
    if ($Signals.HasPrivilegedAzureRole) { $score -= 60; $reasons.Add("PrivilegedAzureRole") }
    if ($Signals.AssignedUsersCount -gt 100) { $score -= 70; $reasons.Add("ManyAssignedUsers:$($Signals.AssignedUsersCount)") }

    # Sign-in evidence
    $bestSignInDate = $null
    if ($null -ne $Signals.SPLastSignInDate) { $bestSignInDate = $Signals.SPLastSignInDate }
    if ($null -ne $Signals.SPLastDaemonSignInDate -and ($null -eq $bestSignInDate -or $Signals.SPLastDaemonSignInDate -gt $bestSignInDate)) {
        $bestSignInDate = $Signals.SPLastDaemonSignInDate
    }
    if ($null -ne $Signals.LastInteractiveSignInDate -and ($null -eq $bestSignInDate -or $Signals.LastInteractiveSignInDate -gt $bestSignInDate)) {
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

    if ($Signals.DaemonUsageDetected) { $score -= 40; $reasons.Add("DaemonSignInDetected") }
    if ($Signals.UsedByExternalSystem) { $score -= 50; $reasons.Add("FederatedCreds:$($Signals.ExternalSystemType)") }
    if ($Signals.HasAzureRBACRoles) { $score -= 40; $reasons.Add("AzureRBACRoles:$($Signals.AzureRBACRoleCount)") }

    # Moderate evidence
    if ($Signals.AssignedUsersCount -gt 0 -and $Signals.AssignedUsersCount -le 100) {
        $score -= 40; $reasons.Add("AssignedUsers:$($Signals.AssignedUsersCount)")
    }
    if ($Signals.AssignedGroupsCount -gt 0) { $score -= 35; $reasons.Add("AssignedGroups:$($Signals.AssignedGroupsCount)") }
    if ($Signals.AdminConsentGranted) { $score -= 20; $reasons.Add("AdminConsentGranted") }
    if ($Signals.AppRoleAssignmentCount -gt 0) { $score -= 15; $reasons.Add("OutboundAPIAssignments:$($Signals.AppRoleAssignmentCount)") }
    if ($Signals.OAuthGrantCount -gt 0) { $score -= 15; $reasons.Add("OAuthGrants:$($Signals.OAuthGrantCount)") }
    if ($Signals.IsApiProvider) { $score -= 25; $reasons.Add("ExposesAPI:$($Signals.ExposedScopeCount)scopes") }
    if ($Signals.DirectoryRoleCount -gt 0) { $score -= 20; $reasons.Add("DirectoryRoles:$($Signals.DirectoryRoleCount)") }

    # Weak evidence
    if (-not $Signals.HasExpiredSecret -and $Signals.SecretCount -gt 0) { $score -= 10; $reasons.Add("ActiveSecret") }
    if (-not $Signals.HasExpiredCert -and $Signals.CertCount -gt 0) { $score -= 10; $reasons.Add("ActiveCert") }
    if ($Signals.IsCoveredByCAPolicy) { $score -= 10; $reasons.Add("CAProtected") }

    # Positive signals (safer to delete)
    if ($Signals.NoServicePrincipal) { $score += 10; $reasons.Add("+NoSP") }
    if ($Signals.AllSecretsExpired -and $Signals.CertCount -eq 0 -and -not $Signals.UsedByExternalSystem) {
        $score += 5; $reasons.Add("+AllSecretsExpired")
    }
    if ($Signals.AppAgeDays -gt 730 -and $null -eq $bestSignInDate) {
        $score += 10; $reasons.Add("+OldUnused:$($Signals.AppAgeDays)d")
    }
    if ($Signals.AppAgeDays -lt 30) { $score -= 15; $reasons.Add("NewlyCreated:$($Signals.AppAgeDays)d") }
    if ($Signals.IsVerifiedPublisher) { $score -= 5; $reasons.Add("VerifiedPublisher") }

    $score = [Math]::Max(0, [Math]::Min(100, $score))
    return @{ Score = $score; ScoreReasons = $reasons -join "|" }
}

function Get-UsageStatus {
    <# Classifies usage as High/Medium/Low confidence #>
    param([hashtable]$Signals)

    $candidates = @($Signals.LastInteractiveSignInDate, $Signals.LastSPSignInDate) |
        Where-Object { $_ -is [datetime] } | Sort-Object -Descending
    $LastUsedDate = if ($candidates.Count -gt 0) { $candidates[0] } else { $null }

    $hasConfigSignal = (
        $Signals.AppRoleAssignmentCount -gt 0 -or $Signals.ConsumedByAppsCount -gt 0 -or
        $Signals.OAuthGrantCount -gt 0 -or $Signals.DirectoryRoleCount -gt 0 -or
        $Signals.AzureRBACRoleCount -gt 0 -or $Signals.FederatedCredentialCount -gt 0 -or
        $Signals.AssignedUsersCount -gt 0 -or $Signals.AssignedGroupsCount -gt 0
    )

    if ($null -ne $LastUsedDate) {
        $IsUnused = $false; $UsageConfidence = "High"
    } elseif ($Signals.UsedByExternalSystem) {
        $IsUnused = $false; $UsageConfidence = "High"; $LastUsedDate = "FederatedActive"
    } elseif ($hasConfigSignal) {
        $IsUnused = $false; $UsageConfidence = "Medium"; $LastUsedDate = "SignalFound-NoDate"
    } else {
        $IsUnused = $true; $UsageConfidence = "Low"; $LastUsedDate = "NoSignal"
    }

    $UnusedMoreThan1Year = $IsUnused -or ($LastUsedDate -is [datetime] -and $LastUsedDate -lt (Get-Date).AddDays(-365))
    $DaysSinceLastUse = if ($LastUsedDate -is [datetime]) { [int]((Get-Date) - $LastUsedDate).TotalDays } else { -1 }

    return @{
        IsUnused            = $IsUnused
        UsageConfidence     = $UsageConfidence
        LastUsedDate        = $LastUsedDate
        UnusedMoreThan1Year = $UnusedMoreThan1Year
        DaysSinceLastUse    = $DaysSinceLastUse
    }
}

function Get-CleanupBucket {
    <# Assigns app to bucket 1-4 based on score and usage #>
    param([int]$Score, [bool]$IsUnused, [string]$UsageConfidence, [bool]$IsMicrosoftApp = $false)

    if ($IsMicrosoftApp) {
        return @{ Bucket = 4; Label = "Microsoft1stParty"; Action = "DO NOT TOUCH - MICROSOFT OWNED" }
    }
    if (-not $IsUnused -and $UsageConfidence -eq "High") {
        return @{ Bucket = 4; Label = "BusinessCritical"; Action = "DO NOT TOUCH" }
    }
    switch ($true) {
        ($Score -ge 80) { return @{ Bucket = 1; Label = "SafeToDisable"; Action = "DISABLE NOW -> DELETE IN 30 DAYS" } }
        ($Score -ge 50) { return @{ Bucket = 2; Label = "NeedsInvestigation"; Action = "SEND TO OWNER FOR REVIEW" } }
        ($Score -ge 20) { return @{ Bucket = 3; Label = "LikelyActive"; Action = "DO NOT TOUCH - GATHER MORE EVIDENCE" } }
        default { return @{ Bucket = 4; Label = "BusinessCritical"; Action = "DO NOT TOUCH" } }
    }
}

function Get-ExternalSystemType {
    <# Identifies CI/CD system from federated credential issuers #>
    param([string[]]$Issuers)

    if ($null -eq $Issuers -or $Issuers.Count -eq 0) { return "None" }
    $types = [System.Collections.Generic.List[string]]::new()
    foreach ($issuer in $Issuers) {
        $matched = $false
        foreach ($key in $FederatedIssuerLabels.Keys) {
            if ($issuer -like "$key*") {
                if (-not $types.Contains($FederatedIssuerLabels[$key])) { $types.Add($FederatedIssuerLabels[$key]) }
                $matched = $true; break
            }
        }
        if (-not $matched -and -not $types.Contains("Unknown")) { $types.Add("Unknown") }
    }
    return ($types -join ";")
}

function Get-WhereUsed {
    <# Human-readable usage location summary #>
    param([hashtable]$Signals)

    $locations = [System.Collections.Generic.List[string]]::new()
    if ($Signals.LastSignInResourceName -ne "NoData") { $locations.Add("UserSignIn->$($Signals.LastSignInResourceName)") }
    if ($Signals.DaemonUsageDetected) { $locations.Add("DaemonSignIn->$($Signals.LastSPSignInResourceName)") }
    if ($Signals.AppRoleAssignedResources -ne "None") { $locations.Add("CallsAPI->$($Signals.AppRoleAssignedResources)") }
    if ($Signals.ConsumedByApps -ne "") { $locations.Add("ConsumedBy->$($Signals.ConsumedByApps)") }
    if ($Signals.AzureRBACScopes -ne "None") { $locations.Add("AzureScope->$($Signals.AzureRBACScopes)") }
    if ($Signals.UsedByExternalSystem) { $locations.Add("ExternalSystem->$($Signals.ExternalSystemType)") }
    if ($Signals.AssignedGroupNames -ne "") { $locations.Add("AssignedGroups->$($Signals.AssignedGroupNames)") }
    if ($Signals.IsApiProvider) { $locations.Add("ExposesAPI->$($Signals.ExposedPermissions)") }
    return if ($locations.Count -gt 0) { $locations -join " | " } else { "NoUsageSignalFound" }
}

# ────────────────────────────────────────────────────────────────
#  BANNER
# ────────────────────────────────────────────────────────────────
$bar = [string]::new([char]0x2550, 70)
Write-Host ""
Write-Host $bar -ForegroundColor Cyan
Write-Host "  Azure App Registration Audit - Standalone Script" -ForegroundColor Cyan
Write-Host "  Mode: $AuditMode | Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host $bar -ForegroundColor Cyan
Write-Host ""

$SkipSignInLogs = $AuditMode -ne "Full"
$DryRunLimit = if ($AuditMode -eq "DryRun") { $DryRunCount } else { 0 }

# ────────────────────────────────────────────────────────────────
#  STEP 1: Pre-requisite Module Check
# ────────────────────────────────────────────────────────────────
Write-Host "[1/7] Checking pre-requisite modules..." -ForegroundColor White

$requiredModules = @(
    @{ Name = "Microsoft.Graph.Authentication"; MinVer = "2.0.0" },
    @{ Name = "Microsoft.Graph.Applications"; MinVer = "2.0.0" },
    @{ Name = "Microsoft.Graph.Reports"; MinVer = "2.0.0" },
    @{ Name = "Microsoft.Graph.Identity.Governance"; MinVer = "2.0.0" },
    @{ Name = "Microsoft.Graph.Identity.DirectoryManagement"; MinVer = "2.0.0" }
)
if (-not $SkipAzureRBAC) {
    $requiredModules += @{ Name = "Az.Resources"; MinVer = "6.0.0" }
    $requiredModules += @{ Name = "Az.Accounts"; MinVer = "2.0.0" }
}

$missingModules = @()
foreach ($mod in $requiredModules) {
    $installed = Get-Module -ListAvailable -Name $mod.Name | Sort-Object Version -Descending | Select-Object -First 1
    if ($null -eq $installed) {
        $missingModules += $mod.Name
        Write-Host "  [MISSING] $($mod.Name)" -ForegroundColor Red
    } elseif ($installed.Version -lt [version]$mod.MinVer) {
        $missingModules += "$($mod.Name) (need >= $($mod.MinVer))"
        Write-Host "  [OUTDATED] $($mod.Name) v$($installed.Version)" -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] $($mod.Name) v$($installed.Version)" -ForegroundColor Green
    }
}

if ($missingModules.Count -gt 0) {
    Write-Host "`n  Missing modules: $($missingModules -join ', ')" -ForegroundColor Yellow
    $choice = Read-Host "  Install now? (Y/N)"
    if ($choice -in @("Y", "y")) {
        foreach ($mod in $requiredModules) {
            $installed = Get-Module -ListAvailable -Name $mod.Name | Sort-Object Version -Descending | Select-Object -First 1
            if ($null -eq $installed -or $installed.Version -lt [version]$mod.MinVer) {
                Write-Host "  Installing $($mod.Name)..." -ForegroundColor Cyan
                Install-Module -Name $mod.Name -MinimumVersion $mod.MinVer -Scope CurrentUser -Force -AllowClobber
            }
        }
    } else {
        throw "Cannot proceed without required modules."
    }
}
Write-Host ""

# ────────────────────────────────────────────────────────────────
#  STEP 2: Authentication
# ────────────────────────────────────────────────────────────────
Write-Host "[2/7] Authenticating..." -ForegroundColor White

$mgContext = Get-MgContext -ErrorAction SilentlyContinue
if ($null -eq $mgContext) {
    Write-Host "  Connecting to Microsoft Graph..." -ForegroundColor Cyan
    if ($TenantId) { Connect-MgGraph -Scopes $GraphScopes -TenantId $TenantId -NoWelcome }
    else { Connect-MgGraph -Scopes $GraphScopes -NoWelcome }
    $mgContext = Get-MgContext
} else {
    $missingScopes = $GraphScopes | Where-Object { $_ -notin $mgContext.Scopes }
    if ($missingScopes.Count -gt 0) {
        Write-Host "  Reconnecting (missing scopes: $($missingScopes -join ', '))..." -ForegroundColor Yellow
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        if ($TenantId) { Connect-MgGraph -Scopes $GraphScopes -TenantId $TenantId -NoWelcome }
        else { Connect-MgGraph -Scopes $GraphScopes -NoWelcome }
        $mgContext = Get-MgContext
    } else {
        Write-Host "  Reusing existing Graph session" -ForegroundColor Green
    }
}

# Validate token with a lightweight call
try {
    $null = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1
    Write-Host "  Graph token validated" -ForegroundColor Green
} catch {
    throw "Graph token invalid or expired. Re-authenticate with Connect-MgGraph. Error: $($_.Exception.Message)"
}

$effectiveTenantId = $TenantId ?? $mgContext.TenantId
$authIdentity = $mgContext.Account ?? $mgContext.AppName ?? "Unknown"
Write-Host "  Graph : $authIdentity | Tenant: $effectiveTenantId" -ForegroundColor Green

# Azure auth (if needed)
$AzSubscriptions = @()
if (-not $SkipAzureRBAC) {
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if ($null -eq $azContext) {
        Write-Host "  Connecting to Azure..." -ForegroundColor Cyan
        if ($TenantId) { Connect-AzAccount -TenantId $TenantId } else { Connect-AzAccount }
        $azContext = Get-AzContext
    } else {
        Write-Host "  Reusing existing Azure session" -ForegroundColor Green
    }
    Write-Host "  Azure : $($azContext.Account.Id)" -ForegroundColor Green
    $AzSubscriptions = @(Get-AzSubscription -TenantId $effectiveTenantId)
    Write-Host "  Subscriptions: $($AzSubscriptions.Count)" -ForegroundColor Green
} else {
    Write-Host "  Azure : SKIPPED" -ForegroundColor DarkGray
}
Write-Host ""

# ────────────────────────────────────────────────────────────────
#  STEP 3: Output Directories & Log File
# ────────────────────────────────────────────────────────────────
Write-Host "[3/7] Setting up output..." -ForegroundColor White

$runTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$runFolder = Join-Path $OutputRoot "AppRegAudit_${effectiveTenantId}_${runTimestamp}"
$logDir = Join-Path $runFolder "Logs"
$ownerNotifDir = Join-Path $runFolder "OwnerNotifications"
foreach ($dir in @($runFolder, $logDir, $ownerNotifDir)) {
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
}
$script:LogFile = Join-Path $logDir "AuditLog_${effectiveTenantId}_${runTimestamp}.log"

Write-Host "  Output : $runFolder" -ForegroundColor Green
Write-Host ""

# ────────────────────────────────────────────────────────────────
#  STEP 4: Bulk Pre-Load (8 data sets)
# ────────────────────────────────────────────────────────────────
Write-Host "[4/7] Bulk-loading data from Graph..." -ForegroundColor White

# 1. App Registrations
Write-Log "INFO" "Bulk" "Loading App Registrations..."
$AllApps = Get-MgApplication -All `
    -ExpandProperty "owners,federatedIdentityCredentials" `
    -Property @(
    "id", "appId", "displayName", "createdDateTime", "signInAudience",
    "publisherDomain", "tags", "passwordCredentials", "keyCredentials",
    "requiredResourceAccess", "web", "spa", "publicClient", "api", "info",
    "notes", "verifiedPublisher"
)
if ($null -eq $AllApps -or $AllApps.Count -eq 0) { throw "ZERO App Registrations returned. Check permissions." }
$AppCache = @{}; foreach ($app in $AllApps) { $AppCache[$app.AppId] = $app }
Write-Log "INFO" "Bulk" "Loaded $($AllApps.Count) App Registrations"

# 2. Service Principals
Write-Log "INFO" "Bulk" "Loading Service Principals..."
$AllSPs = Get-MgServicePrincipal -All -Property @(
    "id", "appId", "displayName", "accountEnabled", "appOwnerOrganizationId",
    "servicePrincipalType", "createdDateTime", "signInActivity", "tags",
    "homepage", "replyUrls", "alternativeNames"
)
if ($null -eq $AllSPs -or $AllSPs.Count -eq 0) { throw "ZERO Service Principals returned." }
$SpCache = @{}; $MiCache = @{}; $MicrosoftAppIds = [System.Collections.Generic.HashSet[string]]::new()
foreach ($sp in $AllSPs) {
    $SpCache[$sp.AppId] = $sp
    if ($sp.ServicePrincipalType -eq "ManagedIdentity") { $MiCache[$sp.Id] = $sp }
    if ($sp.AppOwnerOrganizationId -eq $MicrosoftTenantId) { [void]$MicrosoftAppIds.Add($sp.AppId) }
}
Write-Log "INFO" "Bulk" "Loaded $($AllSPs.Count) SPs ($($MiCache.Count) MIs, $($MicrosoftAppIds.Count) Microsoft)"

# 3. OAuth2 Permission Grants
Write-Log "INFO" "Bulk" "Loading OAuth2 Grants..."
$AllOAuthGrants = Get-MgOauth2PermissionGrant -All -Property "id,clientId,resourceId,scope,consentType,principalId"
$OAuthGrantCache = @{}
foreach ($grant in $AllOAuthGrants) {
    if (-not $OAuthGrantCache.ContainsKey($grant.ClientId)) {
        $OAuthGrantCache[$grant.ClientId] = [System.Collections.Generic.List[object]]::new()
    }
    $OAuthGrantCache[$grant.ClientId].Add($grant)
}
Write-Log "INFO" "Bulk" "Loaded $(($AllOAuthGrants | Measure-Object).Count) OAuth2 Grants"

# 4. Outbound App Role Assignments
Write-Log "INFO" "Bulk" "Loading outbound App Role Assignments..."
$OutboundRoleCache = @{}; $outboundTotal = 0
foreach ($sp in $AllSPs) {
    if ($sp.ServicePrincipalType -eq "ManagedIdentity" -or $MicrosoftAppIds.Contains($sp.AppId)) { continue }
    $assignments = Invoke-GraphRetry -OperationName "OutboundRoles-$($sp.Id)" -ScriptBlock {
        Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -All
    }
    if ($null -ne $assignments -and $assignments.Count -gt 0) {
        $OutboundRoleCache[$sp.Id] = [System.Collections.Generic.List[object]]::new()
        foreach ($a in $assignments) { $OutboundRoleCache[$sp.Id].Add($a) }
        $outboundTotal += $assignments.Count
    }
    if ($ThrottleDelayMs -gt 0) { Start-Sleep -Milliseconds $ThrottleDelayMs }
}
Write-Log "INFO" "Bulk" "Loaded $outboundTotal outbound role assignments"

# 5. Inbound App Role Assignments (consumers)
Write-Log "INFO" "Bulk" "Loading inbound App Role Assignments..."
$InboundRoleCache = @{}; $inboundTotal = 0
foreach ($sp in $AllSPs) {
    if ($sp.ServicePrincipalType -eq "ManagedIdentity" -or $MicrosoftAppIds.Contains($sp.AppId)) { continue }
    $assignments = Invoke-GraphRetry -OperationName "InboundRoles-$($sp.Id)" -ScriptBlock {
        Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $sp.Id -All
    }
    if ($null -ne $assignments -and $assignments.Count -gt 0) {
        $InboundRoleCache[$sp.Id] = [System.Collections.Generic.List[object]]::new()
        foreach ($a in $assignments) { $InboundRoleCache[$sp.Id].Add($a) }
        $inboundTotal += $assignments.Count
    }
    if ($ThrottleDelayMs -gt 0) { Start-Sleep -Milliseconds $ThrottleDelayMs }
}
Write-Log "INFO" "Bulk" "Loaded $inboundTotal inbound role assignments"

# 6. Directory Roles
Write-Log "INFO" "Bulk" "Loading Directory Roles..."
$AllRoleDefinitions = Get-MgRoleManagementDirectoryRoleDefinition -All -Property "id,displayName,isBuiltIn"
$RoleDefCache = @{}; foreach ($rd in $AllRoleDefinitions) { $RoleDefCache[$rd.Id] = $rd }

$AllDirRoleAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All -Property "id,principalId,roleDefinitionId,directoryScopeId"
$DirRoleCache = @{}
foreach ($ra in $AllDirRoleAssignments) {
    $ra | Add-Member -NotePropertyName "RoleDefinition" -NotePropertyValue $RoleDefCache[$ra.RoleDefinitionId] -Force
    if (-not $DirRoleCache.ContainsKey($ra.PrincipalId)) {
        $DirRoleCache[$ra.PrincipalId] = [System.Collections.Generic.List[object]]::new()
    }
    $DirRoleCache[$ra.PrincipalId].Add($ra)
}
Write-Log "INFO" "Bulk" "Loaded $($AllDirRoleAssignments.Count) directory role assignments"

# 7. Azure RBAC
$AzureRbacCache = @{}
if (-not $SkipAzureRBAC) {
    Write-Log "INFO" "Bulk" "Loading Azure RBAC across $($AzSubscriptions.Count) subscriptions..."
    foreach ($sub in $AzSubscriptions) {
        try {
            Set-AzContext -SubscriptionId $sub.Id -ErrorAction Stop | Out-Null
            $subAssignments = Get-AzRoleAssignment -ErrorAction Stop
            foreach ($ra in $subAssignments) {
                if ([string]::IsNullOrEmpty($ra.ObjectId)) { continue }
                if (-not $AzureRbacCache.ContainsKey($ra.ObjectId)) {
                    $AzureRbacCache[$ra.ObjectId] = [System.Collections.Generic.List[object]]::new()
                }
                $AzureRbacCache[$ra.ObjectId].Add($ra)
            }
        } catch {
            Write-Log "WARN" "RBAC" "Sub $($sub.Id): $($_.Exception.Message)"
        }
    }
    Write-Log "INFO" "Bulk" "RBAC loaded across $($AzSubscriptions.Count) subscriptions"
}

# 8. Conditional Access Policies
Write-Log "INFO" "Bulk" "Loading CA Policies..."
$AllCAPolicies = Get-MgIdentityConditionalAccessPolicy -All -Property "id,displayName,state,conditions"
$CaProtectedAppIds = [System.Collections.Generic.HashSet[string]]::new()
foreach ($policy in $AllCAPolicies) {
    if ($policy.State -in @("enabled", "Enabled", "enabledForReportingButNotEnforced")) {
        foreach ($appId in $policy.Conditions.Applications.IncludeApplications) {
            [void]$CaProtectedAppIds.Add($appId)
        }
    }
}
Write-Log "INFO" "Bulk" "Loaded $($AllCAPolicies.Count) CA policies, $($CaProtectedAppIds.Count) protected apps"
Write-Host ""

# ────────────────────────────────────────────────────────────────
#  STEP 5: Per-App Signal Collection + Scoring
# ────────────────────────────────────────────────────────────────
Write-Host "[5/7] Processing apps ($AuditMode mode)..." -ForegroundColor White

$MasterReport = [System.Collections.Generic.List[object]]::new()
$appsToProcess = if ($DryRunLimit -gt 0) { $AllApps | Select-Object -First $DryRunLimit } else { $AllApps }
$totalApps = @($appsToProcess).Count
$currentApp = 0

if (-not $SkipSignInLogs -and $totalApps -gt 100) {
    Write-Log "WARN" "SignIn" "Processing $totalApps apps WITH sign-in logs. Estimated: 2-4 hours."
}

foreach ($app in $appsToProcess) {
    $currentApp++
    Write-Progress -Activity "Auditing App Registrations" -Status "$currentApp/$totalApps - $($app.DisplayName)" -PercentComplete (($currentApp / $totalApps) * 100)

    # ── Signal A: Base Properties ──
    $ObjectId = $app.Id
    $AppId = $app.AppId
    $DisplayName = $app.DisplayName
    $CreatedDateTime = $app.CreatedDateTime
    $SignInAudience = $app.SignInAudience
    $PublisherDomain = $app.PublisherDomain
    $Tags = ($app.Tags -join ";")
    $VerifiedPublisher = $app.VerifiedPublisher.DisplayName ?? "NotVerified"
    $IsVerifiedPublisher = (-not [string]::IsNullOrWhiteSpace($app.VerifiedPublisher.DisplayName))
    $IsMicrosoftApp = $MicrosoftAppIds.Contains($AppId)
    $AppAgeDays = [int]((Get-Date) - $CreatedDateTime).TotalDays

    $AllRedirectUris = @($app.Web.RedirectUris + $app.Spa.RedirectUris + $app.PublicClient.RedirectUris) | Where-Object { $_ }
    $WebRedirectUris = ($app.Web.RedirectUris -join ";")
    $SpaRedirectUris = ($app.Spa.RedirectUris -join ";")
    $HasLocalhostUri = ($AllRedirectUris | Where-Object { $_ -match "localhost" }).Count -gt 0
    $HasHttpUri = ($AllRedirectUris | Where-Object { $_ -match "^http://" }).Count -gt 0
    $HasNgrokUri = ($AllRedirectUris | Where-Object { $_ -match "ngrok" }).Count -gt 0
    $RedirectUriCount = $AllRedirectUris.Count
    $IsPublicClient = ($null -ne $app.PublicClient -and $app.PublicClient.RedirectUris.Count -gt 0)

    $ExposedScopeCount = $app.Api.Oauth2PermissionScopes.Count
    $ExposedRoleCount = $app.Api.AppRoles.Count
    $IsApiProvider = ($ExposedScopeCount -gt 0 -or $ExposedRoleCount -gt 0)
    $ExposedPermissions = @(
        ($app.Api.Oauth2PermissionScopes | ForEach-Object { $_.Value })
        ($app.Api.AppRoles | ForEach-Object { $_.Value })
    ) -join ";"
    $DeclaredPermissionCount = ($app.RequiredResourceAccess | ForEach-Object { $_.ResourceAccess.Count } | Measure-Object -Sum).Sum

    # ── Signal B: Service Principal + Sign-in Activity ──
    $sp = $SpCache[$AppId]
    if ($null -eq $sp) {
        $ServicePrincipalId = "NoSP"; $IsEnabled = "N/A"; $NoServicePrincipal = $true
        $ServicePrincipalType = "N/A"; $SPLastSignInDate = $null; $SPLastDaemonSignInDate = $null
    } else {
        $ServicePrincipalId = $sp.Id
        $IsEnabled = $sp.AccountEnabled
        $NoServicePrincipal = $false
        $ServicePrincipalType = $sp.ServicePrincipalType
        $SPLastSignInDate = $sp.SignInActivity.LastSignInDateTime
        $SPLastDaemonSignInDate = $sp.SignInActivity.LastNonInteractiveSignInDateTime
    }

    # ── Signal C: Owners ──
    $owners = $app.Owners
    $OwnerUPNs = if ($owners.Count -gt 0) {
        ($owners | ForEach-Object { $_.AdditionalProperties.userPrincipalName ?? $_.AdditionalProperties.displayName ?? $_.Id }) -join ";"
    } else { "NoOwner" }
    $OwnerCount = $owners.Count
    $HasOwner = $owners.Count -gt 0

    # ── Signal D: Federated Identity Credentials ──
    $fedCreds = $app.FederatedIdentityCredentials
    $FederatedCredentialCount = if ($null -ne $fedCreds) { $fedCreds.Count } else { 0 }
    $FederatedCredentials = if ($FederatedCredentialCount -gt 0) { ($fedCreds | ForEach-Object { $_.Name }) -join ";" } else { "None" }
    $FederatedIssuers = if ($FederatedCredentialCount -gt 0) { ($fedCreds | ForEach-Object { $_.Issuer }) -join ";" } else { "None" }
    $FederatedSubjects = if ($FederatedCredentialCount -gt 0) { ($fedCreds | ForEach-Object { $_.Subject }) -join ";" } else { "None" }
    $UsedByExternalSystem = $FederatedCredentialCount -gt 0
    $ExternalSystemType = Get-ExternalSystemType -Issuers $fedCreds.Issuer

    # ── Signal E: Interactive Sign-in Logs (optional) ──
    $LastInteractiveSignInDate = $null
    $LastSignInResourceName = "NoData"; $LastSignInUserUPN = "NoData"
    $LastSignInIPAddress = "NoData"; $LastSignInLocation = "NoData"
    $LastSignInClientApp = "NoData"; $LegacyAuthDetected = $false
    $IsCoveredByCAPolicy = $CaProtectedAppIds.Contains($AppId)

    if (-not $SkipSignInLogs -and -not $NoServicePrincipal) {
        $siDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $signIn = Invoke-GraphRetry -OperationName "InteractiveSignIn-$AppId" -ScriptBlock {
            Get-MgAuditLogSignIn -Filter "appId eq '$AppId' and createdDateTime ge $siDate" `
                -Top 1 -OrderBy "createdDateTime desc" `
                -Property @("createdDateTime", "resourceDisplayName", "resourceId", "userPrincipalName", "ipAddress", "location", "clientAppUsed", "conditionalAccessStatus", "status")
        }
        if ($null -ne $signIn) {
            $LastInteractiveSignInDate = $signIn.CreatedDateTime
            $LastSignInResourceName = $signIn.ResourceDisplayName ?? "NoData"
            $LastSignInUserUPN = $signIn.UserPrincipalName ?? "NoData"
            $LastSignInIPAddress = $signIn.IpAddress ?? "NoData"
            $loc = $signIn.Location
            $LastSignInLocation = if ($loc) { "$($loc.City), $($loc.CountryOrRegion)" } else { "NoData" }
            $LastSignInClientApp = $signIn.ClientAppUsed ?? "NoData"
            $LegacyAuthDetected = $LastSignInClientApp -match "Basic Auth|SMTP|POP3|IMAP|MAPI|Exchange ActiveSync|Other clients"
        }
        if ($ThrottleDelayMs -gt 0) { Start-Sleep -Milliseconds $ThrottleDelayMs }
    }

    # ── Signal F: SP/Daemon Sign-in Logs (optional) ──
    $LastSPSignInDate = $null; $LastSPSignInResourceName = "NoData"; $DaemonUsageDetected = $false
    if (-not $SkipSignInLogs -and -not $NoServicePrincipal) {
        $spSiDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $spSignIn = Invoke-GraphRetry -OperationName "SPSignIn-$AppId" -ScriptBlock {
            Get-MgAuditLogSignIn -Filter "appId eq '$AppId' and signInEventTypes/any(t: t eq 'servicePrincipal') and createdDateTime ge $spSiDate" `
                -Top 1 -OrderBy "createdDateTime desc" -Property @("createdDateTime", "resourceDisplayName", "ipAddress", "status")
        }
        if ($null -ne $spSignIn) {
            $LastSPSignInDate = $spSignIn.CreatedDateTime
            $LastSPSignInResourceName = $spSignIn.ResourceDisplayName ?? "NoData"
            $DaemonUsageDetected = $true
        }
        if ($ThrottleDelayMs -gt 0) { Start-Sleep -Milliseconds $ThrottleDelayMs }
    }

    # ── Signal G: Outbound App Role Assignments ──
    $outbound = if ($ServicePrincipalId -ne "NoSP") { $OutboundRoleCache[$ServicePrincipalId] } else { $null }
    $AppRoleAssignmentCount = if ($outbound) { $outbound.Count } else { 0 }
    $AppRoleAssignedResources = if ($outbound) { ($outbound | ForEach-Object { $_.ResourceDisplayName } | Select-Object -Unique) -join ";" } else { "None" }

    # ── Signal H: Inbound Consumers ──
    $inbound = if ($ServicePrincipalId -ne "NoSP") { $InboundRoleCache[$ServicePrincipalId] } else { $null }
    $consumingApps = $inbound | Where-Object { $_.PrincipalType -eq "ServicePrincipal" }
    $assignedUsers = $inbound | Where-Object { $_.PrincipalType -eq "User" }
    $assignedGroups = $inbound | Where-Object { $_.PrincipalType -eq "Group" }

    $ConsumedByAppsCount = ($consumingApps | Measure-Object).Count
    $ConsumedByApps = ($consumingApps | ForEach-Object { $_.PrincipalDisplayName }) -join ";"
    $AssignedUsersCount = ($assignedUsers | Measure-Object).Count
    $AssignedGroupsCount = ($assignedGroups | Measure-Object).Count
    $AssignedGroupNames = ($assignedGroups | ForEach-Object { $_.PrincipalDisplayName }) -join ";"
    $IsActingAsResourceApp = $ConsumedByAppsCount -gt 0
    $DeletionBlastRadius = $ConsumedByAppsCount + $AssignedUsersCount + $AssignedGroupsCount

    # ── Signal I: OAuth2 Permission Grants ──
    $grants = if ($ServicePrincipalId -ne "NoSP") { $OAuthGrantCache[$ServicePrincipalId] } else { $null }
    $OAuthGrantCount = if ($grants) { $grants.Count } else { 0 }
    $OAuthGrantScopes = if ($grants) { ($grants | ForEach-Object { $_.Scope }) -join ";" } else { "None" }
    $AdminConsentGranted = ($grants | Where-Object { $_.ConsentType -eq "AllPrincipals" }).Count -gt 0

    # ── Signal J: Directory Role Assignments ──
    $dirRoles = if ($ServicePrincipalId -ne "NoSP") { $DirRoleCache[$ServicePrincipalId] } else { $null }
    $DirectoryRoles = if ($dirRoles) { ($dirRoles | ForEach-Object { $_.RoleDefinition.DisplayName }) -join ";" } else { "None" }
    $DirectoryRoleCount = if ($dirRoles) { $dirRoles.Count } else { 0 }
    $HasPrivilegedEntraRole = ($dirRoles | Where-Object { $_.RoleDefinition.DisplayName -in $PrivilegedEntraRoles }).Count -gt 0

    # ── Signal K: Azure RBAC ──
    $rbac = if ($ServicePrincipalId -ne "NoSP") { $AzureRbacCache[$ServicePrincipalId] } else { $null }
    $AzureRBACRoleCount = if ($rbac) { $rbac.Count } else { 0 }
    $AzureRBACRoles = if ($rbac) { ($rbac | ForEach-Object { $_.RoleDefinitionName } | Select-Object -Unique) -join ";" } else { "None" }
    $AzureRBACScopes = if ($rbac) { ($rbac | ForEach-Object { $_.Scope } | Select-Object -Unique) -join ";" } else { "None" }
    $HasAzureRBACRoles = $AzureRBACRoleCount -gt 0
    $HasPrivilegedAzureRole = ($rbac | Where-Object { $_.RoleDefinitionName -in $PrivilegedAzureRoles }).Count -gt 0

    # ── Signal L: Credential Health ──
    $now = Get-Date
    $secrets = $app.PasswordCredentials; $SecretCount = $secrets.Count
    $HasExpiredSecret = ($secrets | Where-Object { $_.EndDateTime -lt $now }).Count -gt 0
    $NearestSecretExpiry = if ($SecretCount -gt 0) { ($secrets | Sort-Object EndDateTime | Select-Object -First 1).EndDateTime } else { "NoSecret" }
    $OldestSecretAgeDays = if ($SecretCount -gt 0) {
        $oldest = ($secrets | Sort-Object StartDateTime | Select-Object -First 1).StartDateTime
        if ($null -ne $oldest) { [int]($now - $oldest).TotalDays } else { -1 }
    } else { -1 }
    $AllSecretsExpired = ($SecretCount -gt 0 -and ($secrets | Where-Object { $_.EndDateTime -ge $now }).Count -eq 0)

    $certs = $app.KeyCredentials; $CertCount = $certs.Count
    $HasExpiredCert = ($certs | Where-Object { $_.EndDateTime -lt $now }).Count -gt 0
    $NearestCertExpiry = if ($CertCount -gt 0) { ($certs | Sort-Object EndDateTime | Select-Object -First 1).EndDateTime } else { "NoCert" }
    $AllCertsExpired = ($CertCount -gt 0 -and ($certs | Where-Object { $_.EndDateTime -ge $now }).Count -eq 0)

    $UsesPasswordlessAuth = ($FederatedCredentialCount -gt 0 -or $CertCount -gt 0 -or $ServicePrincipalType -eq "ManagedIdentity")
    $AuthMethod = if ($ServicePrincipalType -eq "ManagedIdentity") { "ManagedIdentity" }
    elseif ($FederatedCredentialCount -gt 0) { "FederatedCredential" }
    elseif ($CertCount -gt 0 -and $SecretCount -eq 0) { "CertificateOnly" }
    elseif ($SecretCount -gt 0) { "ClientSecret" }
    else { "NoCredential" }

    # ── Signal M: Broad Permission Detection ──
    $HasBroadGraphPermissions = $false
    $BroadPermissionNames = [System.Collections.Generic.List[string]]::new()
    foreach ($resource in $app.RequiredResourceAccess) {
        if ($resource.ResourceAppId -eq $graphResourceId) {
            foreach ($access in $resource.ResourceAccess) {
                if ($BroadPermissions.ContainsKey($access.Id.ToString())) {
                    $HasBroadGraphPermissions = $true
                    $BroadPermissionNames.Add($BroadPermissions[$access.Id.ToString()])
                }
            }
        }
    }

    # ── SCORE / CLASSIFY / BUCKET ──
    $signalHash = @{
        IsMicrosoftApp = $IsMicrosoftApp; ConsumedByAppsCount = $ConsumedByAppsCount
        HasPrivilegedEntraRole = $HasPrivilegedEntraRole; HasPrivilegedAzureRole = $HasPrivilegedAzureRole
        AssignedUsersCount = $AssignedUsersCount; SPLastSignInDate = $SPLastSignInDate
        SPLastDaemonSignInDate = $SPLastDaemonSignInDate; LastInteractiveSignInDate = $LastInteractiveSignInDate
        DaemonUsageDetected = $DaemonUsageDetected; UsedByExternalSystem = $UsedByExternalSystem
        ExternalSystemType = $ExternalSystemType; HasAzureRBACRoles = $HasAzureRBACRoles
        AzureRBACRoleCount = $AzureRBACRoleCount; AssignedGroupsCount = $AssignedGroupsCount
        AdminConsentGranted = $AdminConsentGranted; AppRoleAssignmentCount = $AppRoleAssignmentCount
        OAuthGrantCount = $OAuthGrantCount; IsApiProvider = $IsApiProvider
        ExposedScopeCount = $ExposedScopeCount; DirectoryRoleCount = $DirectoryRoleCount
        HasExpiredSecret = $HasExpiredSecret; SecretCount = $SecretCount
        HasExpiredCert = $HasExpiredCert; CertCount = $CertCount
        IsCoveredByCAPolicy = $IsCoveredByCAPolicy; NoServicePrincipal = $NoServicePrincipal
        AllSecretsExpired = $AllSecretsExpired; AppAgeDays = $AppAgeDays
        IsVerifiedPublisher = $IsVerifiedPublisher; FederatedCredentialCount = $FederatedCredentialCount
        LastSPSignInDate = $LastSPSignInDate; AppRoleAssignedResources = $AppRoleAssignedResources
        ConsumedByApps = $ConsumedByApps; AzureRBACScopes = $AzureRBACScopes
        AssignedGroupNames = $AssignedGroupNames; ExposedPermissions = $ExposedPermissions
        LastSignInResourceName = $LastSignInResourceName; LastSPSignInResourceName = $LastSPSignInResourceName
    }

    $scoreResult = Get-DeletionSafetyScore -Signals $signalHash
    $usageResult = Get-UsageStatus -Signals $signalHash
    $bucketResult = Get-CleanupBucket -Score $scoreResult.Score -IsUnused $usageResult.IsUnused -UsageConfidence $usageResult.UsageConfidence -IsMicrosoftApp $IsMicrosoftApp
    $whereUsed = Get-WhereUsed -Signals $signalHash

    $DaysSinceInteractiveSignIn = if ($LastInteractiveSignInDate -is [datetime]) { [int]((Get-Date) - $LastInteractiveSignInDate).TotalDays } else { -1 }
    $DaysSinceSPSignIn = if ($LastSPSignInDate -is [datetime]) { [int]((Get-Date) - $LastSPSignInDate).TotalDays } else { -1 }

    # ── Build Master Record ──
    $MasterReport.Add([PSCustomObject]@{
            CleanupBucket              = $bucketResult.Bucket
            BucketLabel                = $bucketResult.Label
            RecommendedAction          = $bucketResult.Action
            DeletionSafetyScore        = $scoreResult.Score
            ScoreReasons               = $scoreResult.ScoreReasons
            AppName                    = $DisplayName
            AppId                      = $AppId
            ObjectId                   = $ObjectId
            CreatedDate                = $CreatedDateTime
            SignInAudience             = $SignInAudience
            ServicePrincipalId         = $ServicePrincipalId
            NoServicePrincipal         = $NoServicePrincipal
            IsEnabled                  = $IsEnabled
            ServicePrincipalType       = $ServicePrincipalType
            Tags                       = $Tags
            VerifiedPublisher          = $VerifiedPublisher
            IsMicrosoftApp             = $IsMicrosoftApp
            AppAgeDays                 = $AppAgeDays
            OwnerUPNs                  = $OwnerUPNs
            OwnerCount                 = $OwnerCount
            HasOwner                   = $HasOwner
            IsUnused                   = $usageResult.IsUnused
            UnusedMoreThan1Year        = $usageResult.UnusedMoreThan1Year
            UsageConfidence            = $usageResult.UsageConfidence
            LastUsedDate               = $usageResult.LastUsedDate
            DaysSinceLastUse           = $usageResult.DaysSinceLastUse
            UsageLocationSummary       = $whereUsed
            LastInteractiveSignInDate  = if ($null -ne $LastInteractiveSignInDate) { $LastInteractiveSignInDate } else { "NoData" }
            DaysSinceInteractiveSignIn = $DaysSinceInteractiveSignIn
            LastSignInResourceName     = $LastSignInResourceName
            LastSignInUserUPN          = $LastSignInUserUPN
            LastSignInIPAddress        = $LastSignInIPAddress
            LastSignInLocation         = $LastSignInLocation
            LastSignInClientApp        = $LastSignInClientApp
            LegacyAuthDetected         = $LegacyAuthDetected
            IsCoveredByCAPolicy        = $IsCoveredByCAPolicy
            SPLastSignInDate           = if ($null -ne $SPLastSignInDate) { $SPLastSignInDate } else { "NoData" }
            SPLastDaemonSignInDate     = if ($null -ne $SPLastDaemonSignInDate) { $SPLastDaemonSignInDate } else { "NoData" }
            LastSPSignInDate           = if ($null -ne $LastSPSignInDate) { $LastSPSignInDate } else { "NoData" }
            DaysSinceSPSignIn          = $DaysSinceSPSignIn
            LastSPSignInResourceName   = $LastSPSignInResourceName
            DaemonUsageDetected        = $DaemonUsageDetected
            DeletionBlastRadius        = $DeletionBlastRadius
            ConsumedByAppsCount        = $ConsumedByAppsCount
            ConsumedByApps             = $ConsumedByApps
            AssignedUsersCount         = $AssignedUsersCount
            AssignedGroupsCount        = $AssignedGroupsCount
            AssignedGroupNames         = $AssignedGroupNames
            IsActingAsResourceApp      = $IsActingAsResourceApp
            AppRoleAssignmentCount     = $AppRoleAssignmentCount
            AppRoleAssignedResources   = $AppRoleAssignedResources
            OAuthGrantCount            = $OAuthGrantCount
            OAuthGrantScopes           = $OAuthGrantScopes
            AdminConsentGranted        = $AdminConsentGranted
            DirectoryRoles             = $DirectoryRoles
            DirectoryRoleCount         = $DirectoryRoleCount
            HasPrivilegedEntraRole     = $HasPrivilegedEntraRole
            AzureRBACRoleCount         = $AzureRBACRoleCount
            AzureRBACRoles             = $AzureRBACRoles
            AzureRBACScopes            = $AzureRBACScopes
            HasAzureRBACRoles          = $HasAzureRBACRoles
            HasPrivilegedAzureRole     = $HasPrivilegedAzureRole
            FederatedCredentialCount   = $FederatedCredentialCount
            FederatedCredentials       = $FederatedCredentials
            FederatedIssuers           = $FederatedIssuers
            FederatedSubjects          = $FederatedSubjects
            UsedByExternalSystem       = $UsedByExternalSystem
            ExternalSystemType         = $ExternalSystemType
            SecretCount                = $SecretCount
            NearestSecretExpiry        = $NearestSecretExpiry
            HasExpiredSecret           = $HasExpiredSecret
            AllSecretsExpired          = $AllSecretsExpired
            OldestSecretAgeDays        = $OldestSecretAgeDays
            CertCount                  = $CertCount
            NearestCertExpiry          = $NearestCertExpiry
            HasExpiredCert             = $HasExpiredCert
            AllCertsExpired            = $AllCertsExpired
            AuthMethod                 = $AuthMethod
            UsesPasswordlessAuth       = $UsesPasswordlessAuth
            IsPublicClient             = $IsPublicClient
            IsApiProvider              = $IsApiProvider
            ExposedScopeCount          = $ExposedScopeCount
            ExposedRoleCount           = $ExposedRoleCount
            ExposedPermissions         = $ExposedPermissions
            DeclaredPermissionCount    = $DeclaredPermissionCount
            HasBroadGraphPermissions   = $HasBroadGraphPermissions
            BroadPermissionNames       = ($BroadPermissionNames -join ";")
            RedirectUriCount           = $RedirectUriCount
            WebRedirectUris            = $WebRedirectUris
            SpaRedirectUris            = $SpaRedirectUris
            HasLocalhostUri            = $HasLocalhostUri
            HasHttpUri                 = $HasHttpUri
            HasNgrokUri                = $HasNgrokUri
        })

    Write-Log "DEBUG" "App" "[$currentApp/$totalApps] $AppId | Score=$($scoreResult.Score) | $($bucketResult.Label)"
}

Write-Progress -Activity "Auditing App Registrations" -Completed
Write-Log "INFO" "Phase2" "Completed per-app processing for $totalApps apps"
Write-Host ""

# ────────────────────────────────────────────────────────────────
#  STEP 6: Managed Identity Sweep
# ────────────────────────────────────────────────────────────────
Write-Host "[6/7] Managed Identity sweep ($($MiCache.Count) MIs)..." -ForegroundColor White

$MiReport = [System.Collections.Generic.List[object]]::new()
foreach ($mi in $MiCache.Values) {
    $miRbac = $AzureRbacCache[$mi.Id]
    $miDirRole = $DirRoleCache[$mi.Id]
    $miRBACRoles = if ($miRbac) { ($miRbac | ForEach-Object { $_.RoleDefinitionName }) -join ";" } else { "None" }
    $miDirRoles = if ($miDirRole) { ($miDirRole | ForEach-Object { $_.RoleDefinition.DisplayName }) -join ";" } else { "None" }

    $altNames = $mi.AlternativeNames
    $isSystemAssigned = ($altNames | Where-Object { $_ -like '/subscriptions/*' }).Count -gt 0
    $miType = if ($isSystemAssigned) { "SystemAssigned" } else { "UserAssigned" }
    $LinkedResource = if ($isSystemAssigned) {
        ($altNames | Where-Object { $_ -like '/subscriptions/*' }) | Select-Object -First 1
    } else { $mi.DisplayName }

    $MiReport.Add([PSCustomObject]@{
            DisplayName            = $mi.DisplayName
            ServicePrincipalId     = $mi.Id
            AppId                  = $mi.AppId
            ManagedIdentityType    = $miType
            LinkedResource         = $LinkedResource
            IsEnabled              = $mi.AccountEnabled
            CreatedDateTime        = $mi.CreatedDateTime
            AzureRBACRoles         = $miRBACRoles
            AzureRBACRoleCount     = if ($miRbac) { $miRbac.Count } else { 0 }
            HasPrivilegedAzureRole = ($miRbac | Where-Object { $_.RoleDefinitionName -in $PrivilegedAzureRoles }).Count -gt 0
            DirectoryRoles         = $miDirRoles
            HasPrivilegedEntraRole = ($miDirRole | Where-Object { $_.RoleDefinition.DisplayName -in $PrivilegedEntraRoles }).Count -gt 0
            PossiblyOrphaned       = ($miRbac.Count -eq 0 -and $miDirRole.Count -eq 0)
        })
}
Write-Log "INFO" "MI" "MI sweep complete: $($MiReport.Count) MIs"
Write-Host ""

# ────────────────────────────────────────────────────────────────
#  STEP 7: Export CSVs + Console Summary
# ────────────────────────────────────────────────────────────────
Write-Host "[7/7] Exporting results..." -ForegroundColor White

# Master CSV
$masterPath = Join-Path $runFolder "MasterAudit_Full_${effectiveTenantId}_${DateStamp}.csv"
$MasterReport | Export-Csv -Path $masterPath -NoTypeInformation -Encoding UTF8
Write-Log "INFO" "Export" "Master: $masterPath"

# Bucket CSVs
$bucketLabels = @{ 1 = "Bucket1_SafeToDisable"; 2 = "Bucket2_NeedsInvestigation"; 3 = "Bucket3_LikelyActive"; 4 = "Bucket4_BusinessCritical" }
for ($b = 1; $b -le 4; $b++) {
    $bucketApps = $MasterReport | Where-Object { $_.CleanupBucket -eq $b }
    $bucketPath = Join-Path $runFolder "$($bucketLabels[$b])_${effectiveTenantId}_${DateStamp}.csv"
    if ($b -eq 1) {
        $bucketApps | Select-Object *, @{N = 'ProposedDisableDate'; E = { Get-Date -Format 'yyyy-MM-dd' } },
        @{N = 'ProposedDeleteDate'; E = { (Get-Date).AddDays(30).ToString('yyyy-MM-dd') } },
        @{N = 'DisabledConfirmed'; E = { '' } }, @{N = 'OwnerNotified'; E = { '' } } |
            Export-Csv -Path $bucketPath -NoTypeInformation -Encoding UTF8
    } else {
        $bucketApps | Export-Csv -Path $bucketPath -NoTypeInformation -Encoding UTF8
    }
    Write-Log "INFO" "Export" "$($bucketLabels[$b]): $(@($bucketApps).Count) apps"
}

# MI CSV
$miPath = Join-Path $runFolder "ManagedIdentity_Audit_${effectiveTenantId}_${DateStamp}.csv"
$MiReport | Export-Csv -Path $miPath -NoTypeInformation -Encoding UTF8

# Owner Notification CSVs
$byOwner = $MasterReport | Where-Object { $_.OwnerUPNs -ne "NoOwner" } |
    ForEach-Object {
        $rec = $_; $rec.OwnerUPNs -split ";" | ForEach-Object { @{ Owner = $_; App = $rec } }
    } | Group-Object -Property Owner

foreach ($ownerGroup in $byOwner) {
    $safeFileName = $ownerGroup.Name -replace '[\\/:*?"<>|@]', '_'
    $ownerApps = $ownerGroup.Group | Select-Object -ExpandProperty App
    $ownerPath = Join-Path $ownerNotifDir "Owner_${safeFileName}_${DateStamp}.csv"
    $ownerApps | Select-Object $OwnerNotificationColumns | Export-Csv -Path $ownerPath -NoTypeInformation -Encoding UTF8
}

$noOwnerApps = $MasterReport | Where-Object { $_.OwnerUPNs -eq "NoOwner" -and $_.CleanupBucket -le 2 }
$escalationPath = Join-Path $ownerNotifDir "NoOwner_Escalation_${DateStamp}.csv"
$noOwnerApps | Select-Object $OwnerNotificationColumns | Export-Csv -Path $escalationPath -NoTypeInformation -Encoding UTF8

# ── Console Summary ──
$duration = (Get-Date) - $scriptStart
$durationStr = "$([int]$duration.TotalMinutes) min $($duration.Seconds) sec"

$b1 = @($MasterReport | Where-Object { $_.CleanupBucket -eq 1 }).Count
$b2 = @($MasterReport | Where-Object { $_.CleanupBucket -eq 2 }).Count
$b3 = @($MasterReport | Where-Object { $_.CleanupBucket -eq 3 }).Count
$b4 = @($MasterReport | Where-Object { $_.CleanupBucket -eq 4 }).Count

$withOwners = @($MasterReport | Where-Object { $_.HasOwner }).Count
$withoutOwners = @($MasterReport | Where-Object { -not $_.HasOwner }).Count
$highConf = @($MasterReport | Where-Object { $_.UsageConfidence -eq "High" }).Count
$medConf = @($MasterReport | Where-Object { $_.UsageConfidence -eq "Medium" }).Count
$lowConf = @($MasterReport | Where-Object { $_.UsageConfidence -eq "Low" }).Count

$line = [string]::new([char]0x2550, 66)
$thin = [string]::new([char]0x2500, 66)

Write-Host ""
Write-Host $line -ForegroundColor Cyan
Write-Host "  Azure App Registration Audit - Summary" -ForegroundColor Cyan
Write-Host $line -ForegroundColor Cyan
Write-Host "  Tenant          : $effectiveTenantId"
Write-Host "  Mode            : $AuditMode"
Write-Host "  Duration        : $durationStr"
Write-Host "  Subscriptions   : $($AzSubscriptions.Count)"
Write-Host $thin -ForegroundColor DarkGray
Write-Host "  INVENTORY" -ForegroundColor White
Write-Host "  App Registrations    : $($MasterReport.Count)"
Write-Host "  Managed Identities   : $($MiReport.Count)"
Write-Host $thin -ForegroundColor DarkGray
Write-Host "  CLEANUP BUCKETS" -ForegroundColor White
Write-Host "  Bucket 1 - Safe to Disable    : $b1" -ForegroundColor Red
Write-Host "  Bucket 2 - Needs Investigation: $b2" -ForegroundColor Yellow
Write-Host "  Bucket 3 - Likely Active      : $b3" -ForegroundColor DarkYellow
Write-Host "  Bucket 4 - Business Critical  : $b4" -ForegroundColor Green
Write-Host $thin -ForegroundColor DarkGray
Write-Host "  OWNERSHIP" -ForegroundColor White
Write-Host "  With Owners          : $withOwners"
Write-Host "  Without Owners       : $withoutOwners"
Write-Host "  Ownerless Escalation : $(@($noOwnerApps).Count)"
Write-Host $thin -ForegroundColor DarkGray
Write-Host "  USAGE CONFIDENCE" -ForegroundColor White
Write-Host "  High (confirmed)     : $highConf"
Write-Host "  Medium (signals)     : $medConf"
Write-Host "  Low (no signal)      : $lowConf"
Write-Host $thin -ForegroundColor DarkGray
Write-Host "  RISK FLAGS" -ForegroundColor White
Write-Host "  Privileged Entra Role: $(@($MasterReport | Where-Object { $_.HasPrivilegedEntraRole }).Count)"
Write-Host "  Privileged Azure Role: $(@($MasterReport | Where-Object { $_.HasPrivilegedAzureRole }).Count)"
Write-Host "  Broad Graph Perms    : $(@($MasterReport | Where-Object { $_.HasBroadGraphPermissions }).Count)"
Write-Host "  Expired Secrets      : $(@($MasterReport | Where-Object { $_.HasExpiredSecret }).Count)"
Write-Host "  Secrets > 1yr Old    : $(@($MasterReport | Where-Object { $_.OldestSecretAgeDays -gt 365 }).Count)"
Write-Host "  Legacy Auth Detected : $(@($MasterReport | Where-Object { $_.LegacyAuthDetected }).Count)"
Write-Host $thin -ForegroundColor DarkGray
Write-Host "  OUTPUT" -ForegroundColor White
Write-Host "  Folder  : $runFolder"
Write-Host "  Log     : $($script:LogFile)"

$outputFiles = Get-ChildItem -Path $runFolder -File -Recurse | Where-Object { $_.Extension -in @('.csv', '.log') }
Write-Host "  Files   : $($outputFiles.Count)" -ForegroundColor White
foreach ($f in $outputFiles | Sort-Object Extension, Name) {
    $sizeKB = [math]::Round($f.Length / 1KB, 1)
    $relPath = $f.FullName.Replace($runFolder, "").TrimStart('\')
    Write-Host "    $($f.Extension.PadRight(6)) ${sizeKB}KB  $relPath" -ForegroundColor DarkGray
}

Write-Host $line -ForegroundColor Cyan
Write-Host ""

# Open output folder
if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
    Start-Process explorer.exe -ArgumentList $runFolder
} elseif ($IsMacOS) {
    Start-Process "open" -ArgumentList $runFolder
} elseif ($IsLinux) {
    Start-Process "xdg-open" -ArgumentList $runFolder
}

Write-Log "INFO" "Done" "Audit complete. Duration: $durationStr. Apps: $($MasterReport.Count). B1=$b1 B2=$b2 B3=$b3 B4=$b4"
