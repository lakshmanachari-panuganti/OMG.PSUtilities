# Prompt: Azure App Registration Cleanup & Governance System (v5)
# PRIMARY GOAL: Safe, evidence-based cleanup of unused App Registrations at scale (9,000+ apps)
# Architecture: Collect → Score → Bucket → Output → Act
# Updated: 7th March 2026 — fixes from expert Azure review (19 issues resolved)

---

## Role & Context

You are a Senior Azure Architect and PowerShell automation engineer.

The organization has approximately **9,000 App Registrations** in a single Microsoft Entra ID tenant.
The IT team does not know which apps are used, who owns them, or whether they are safe to delete.

**The primary objective of this script is NOT to produce a report. It is to produce an
actionable, safe, prioritized cleanup pipeline** that tells the IT team exactly:

1. Which apps can be **safely disabled today** (🔴 Bucket 1)
2. Which apps need **owner review before action** (🟡 Bucket 2)
3. Which apps are **likely still active** and need more evidence (🟠 Bucket 3)
4. Which apps must **never be touched** without a formal change request (🟢 Bucket 4)

Every design decision — data collected, scoring weights, output format — must serve this goal.

The script must use:
- **Microsoft Graph PowerShell SDK v2+** (`Microsoft.Graph.*` modules)
- **Az.Resources module** (Azure RBAC coverage)

Do **NOT** use:
- `AzureAD` module (deprecated)
- `MSOnline` module (deprecated)
- `Invoke-RestMethod` unless unavoidable and documented inline with justification

---

## Strict Technical Constraints

### Language & Runtime
- PowerShell 7.2+ (cross-platform)
- Microsoft Graph PowerShell SDK v2.x
- Az.Resources 6.0.0+
- Designed to run against a single Entra ID tenant
- Must complete a 9,000-app tenant run without manual intervention

### Module Declarations

```powershell
#Requires -Version 7.2
#Requires -Modules @{ ModuleName='Microsoft.Graph.Authentication';               ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Applications';                ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Reports';                     ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.Governance';         ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.DirectoryManagement';ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Az.Resources';                                ModuleVersion='6.0.0' }
```

> **Why PowerShell 7.2+?** This script uses the `??` null-coalescing operator,
> ternary expressions, and `[System.Collections.Generic.*]` types extensively.
> These features do NOT exist in Windows PowerShell 5.1.

---

## Parameters Block

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TenantId,                    # Optional: read from Get-MgContext if absent
    [string]$OutputDirectory   = $PSScriptRoot,
    [string]$LogDirectory      = $PSScriptRoot,
    [switch]$SkipAzureRBAC,               # Skip Az.Resources if module unavailable
    [switch]$SkipSignInLogs,              # Skip per-app sign-in log queries (faster, less signal)
    [int]$ThrottleDelayMs      = 200,     # Base delay between per-app Graph calls (ms)
    [int]$DryRunLimit          = 0,       # If > 0, process only this many apps (test mode)
    [switch]$VerboseMode
)
```

> **`-DryRunLimit 50`** processes only the first 50 apps and generates sample output files.
> Use this to validate the script works before committing to a full 3-4 hour run.

---

## Authentication & Pre-flight

### Dual Connection

```powershell
Connect-MgGraph -Scopes @(
    "Application.Read.All",
    "Directory.Read.All",
    "AuditLog.Read.All",
    "AppRoleAssignment.Read.All",
    "Policy.Read.All"               # Required for Conditional Access policy read in Bulk Load 8
) -NoWelcome

Connect-AzAccount -TenantId $TenantId   # Required for RBAC unless -SkipAzureRBAC
```

### Pre-flight Checklist (halt on ANY failure)

Execute in this exact order before any data collection:

1. `Get-MgContext` → if `$null` → abort: `"ERROR: No Graph context. Run Connect-MgGraph."`
2. Validate all 5 scopes present in `(Get-MgContext).Scopes` → list missing scopes by name → abort
   - `Application.Read.All`, `Directory.Read.All`, `AuditLog.Read.All`, `AppRoleAssignment.Read.All`, `Policy.Read.All`
3. If `-SkipAzureRBAC` is NOT set: `Get-AzContext` → if `$null` → abort: `"ERROR: No Azure context. Run Connect-AzAccount."`
4. Resolve and store `$TenantId` from `(Get-MgContext).TenantId` if not supplied as parameter
5. Cache all Azure subscriptions: `$script:AzSubscriptions = Get-AzSubscription -TenantId $TenantId`
   → Log subscription count
6. Log: authenticated identity (UPN or AppId), TenantId, subscription count, script start timestamp

---

## Phase 1: Bulk Pre-Load (Performance Architecture for 9,000 Apps)

> **CRITICAL PERFORMANCE RULE:**
> For a 9,000-app tenant, per-app Graph calls multiply into 50,000–100,000+ API requests.
> The following data MUST be bulk-loaded ONCE into memory before the per-app loop begins.
> NEVER call these inside the per-app loop.

### Bulk Load 1 — All App Registrations (with Owners + Federated Creds)

```powershell
# ✅ PERFORMANCE FIX: Use $expand to include owners and federated identity credentials
#    in the same bulk call. This eliminates 18,000 per-app Graph calls (Signal C + Signal D).
#    If $expand causes timeouts on very large tenants, fall back to per-app calls.
$AllApps = Get-MgApplication -All `
    -ExpandProperty "owners,federatedIdentityCredentials" `
    -Property @(
        "id", "appId", "displayName", "createdDateTime",
        "signInAudience", "publisherDomain", "tags",
        "passwordCredentials", "keyCredentials", "requiredResourceAccess",
        "web", "spa", "publicClient",
        "api",                          # API exposure: oauth2PermissionScopes + appRoles
        "info", "notes",
        "verifiedPublisher"             # Verified publisher info (Salesforce, ServiceNow, etc.)
    )

# Validate bulk load returned data
if ($null -eq $AllApps -or $AllApps.Count -eq 0) {
    Write-Log "ERROR" "Bulk" "ZERO App Registrations returned. Check Application.Read.All scope."
    throw "Bulk load returned no applications. Verify permissions and try again."
}

# Store as hashtable keyed by appId for O(1) lookups
$AppCache = @{}
foreach ($app in $AllApps) { $AppCache[$app.AppId] = $app }
Write-Log "INFO" "Bulk" "Loaded $($AllApps.Count) App Registrations (with owners + federated creds)"
```

### Bulk Load 2 — All Service Principals (with Sign-in Activity)

```powershell
# ✅ PERFORMANCE FIX: Include signInActivity to get ALL-TIME last sign-in dates.
#    This is far more reliable than per-app audit log queries (30-day/7-day retention).
#    signInActivity provides: LastSignInDateTime + LastNonInteractiveSignInDateTime
#    across the entire lifetime of the SP — not limited by log retention.
# ✅ FIX: Include alternativeNames for reliable MI type detection (system vs user-assigned).
$AllSPs = Get-MgServicePrincipal -All -Property @(
    "id", "appId", "displayName", "accountEnabled",
    "appOwnerOrganizationId", "servicePrincipalType", "createdDateTime",
    "signInActivity",               # ALL-TIME sign-in dates (not limited by log retention)
    "tags", "homepage", "replyUrls",
    "alternativeNames"              # Contains ARM resource ID for Managed Identities
)

# Validate bulk load returned data
if ($null -eq $AllSPs -or $AllSPs.Count -eq 0) {
    Write-Log "ERROR" "Bulk" "ZERO Service Principals returned. Check Directory.Read.All scope."
    throw "Bulk load returned no service principals. Verify permissions and try again."
}

# Microsoft 1st-party tenant ID — apps owned by this org are Microsoft's own apps
$MicrosoftTenantId = "f8cdef31-a31e-4b4a-93e4-5f571e91255a"

# THREE separate caches — apps, managed identities, and Microsoft apps
$SpCache = @{}           # keyed by AppId → SP object
$MiCache = @{}           # keyed by SP ObjectId → MI SP object
$MicrosoftAppIds = [System.Collections.Generic.HashSet[string]]::new()  # Microsoft 1st-party apps

foreach ($sp in $AllSPs) {
    $SpCache[$sp.AppId] = $sp
    if ($sp.ServicePrincipalType -eq "ManagedIdentity") {
        $MiCache[$sp.Id] = $sp
    }
    # Detect Microsoft 1st-party apps (Office 365, Teams, Azure Portal, etc.)
    # These should NEVER appear in cleanup buckets — they are auto-classified as Bucket 4
    if ($sp.AppOwnerOrganizationId -eq $MicrosoftTenantId) {
        [void]$MicrosoftAppIds.Add($sp.AppId)
    }
}
Write-Log "INFO" "Bulk" "Loaded $($AllSPs.Count) Service Principals ($($MiCache.Count) Managed Identities, $($MicrosoftAppIds.Count) Microsoft 1st-party)"
```

### Bulk Load 3 — All OAuth2 Permission Grants

```powershell
# Load ALL grants once — group by clientId in memory
# DO NOT call Get-MgOauth2PermissionGrant per app — this causes throttling at scale
$AllOAuthGrants = Get-MgOauth2PermissionGrant -All -Property @(
    "id", "clientId", "resourceId", "scope", "consentType", "principalId"
)
$OAuthGrantCache = @{}   # keyed by clientId (SP ObjectId)
foreach ($grant in $AllOAuthGrants) {
    if (-not $OAuthGrantCache.ContainsKey($grant.ClientId)) {
        $OAuthGrantCache[$grant.ClientId] = [System.Collections.Generic.List[object]]::new()
    }
    $OAuthGrantCache[$grant.ClientId].Add($grant)
}
Write-Log "INFO" "Bulk" "Loaded $(if ($AllOAuthGrants) { $AllOAuthGrants.Count } else { 0 }) OAuth2 Permission Grants"
```

### Bulk Load 4 — All App Role Assignments (Outbound)

```powershell
# ✅ CRITICAL FIX: Get-MgServicePrincipalAppRoleAssignment REQUIRES -ServicePrincipalId.
#    It CANNOT be called with just -All. The v4 prompt was incorrect about this.
#    We must iterate through each SP and collect assignments.
#    For 9,000 SPs this is 9,000 calls — but each call is fast (small payload).
#    Use Invoke-GraphWithRetry for throttle protection.

$OutboundRoleCache = @{}   # keyed by principalId (SP ObjectId)
$outboundTotal = 0

foreach ($sp in $AllSPs) {
    # Skip Managed Identities and Microsoft 1st-party apps here for speed
    if ($sp.ServicePrincipalType -eq "ManagedIdentity") { continue }
    if ($MicrosoftAppIds.Contains($sp.AppId)) { continue }

    $assignments = Invoke-GraphWithRetry -OperationName "OutboundRoles-$($sp.Id)" -ScriptBlock {
        Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -All
    }
    if ($null -ne $assignments -and $assignments.Count -gt 0) {
        $OutboundRoleCache[$sp.Id] = [System.Collections.Generic.List[object]]::new()
        foreach ($assignment in $assignments) {
            $OutboundRoleCache[$sp.Id].Add($assignment)
        }
        $outboundTotal += $assignments.Count
    }

    # Throttle delay to avoid HTTP 429
    if ($ThrottleDelayMs -gt 0) { Start-Sleep -Milliseconds $ThrottleDelayMs }
}
Write-Log "INFO" "Bulk" "Loaded $outboundTotal outbound App Role Assignments across $($OutboundRoleCache.Count) SPs"
```

### Bulk Load 5 — All Inbound App Role Assignments (Consumers)

```powershell
# ✅ CRITICAL FIX: Get-MgServicePrincipalAppRoleAssignedTo also REQUIRES -ServicePrincipalId.
#    Same fix as Bulk Load 4 — iterate SPs.
#    Inbound = who is assigned TO each app (users, groups, other SPs consuming this app)

$InboundRoleCache = @{}   # keyed by resourceId (the SP being consumed)
$inboundTotal = 0

foreach ($sp in $AllSPs) {
    # Skip Managed Identities and Microsoft 1st-party apps here for speed
    if ($sp.ServicePrincipalType -eq "ManagedIdentity") { continue }
    if ($MicrosoftAppIds.Contains($sp.AppId)) { continue }

    $assignments = Invoke-GraphWithRetry -OperationName "InboundRoles-$($sp.Id)" -ScriptBlock {
        Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $sp.Id -All
    }
    if ($null -ne $assignments -and $assignments.Count -gt 0) {
        $InboundRoleCache[$sp.Id] = [System.Collections.Generic.List[object]]::new()
        foreach ($assignment in $assignments) {
            $InboundRoleCache[$sp.Id].Add($assignment)
        }
        $inboundTotal += $assignments.Count
    }

    # Throttle delay to avoid HTTP 429
    if ($ThrottleDelayMs -gt 0) { Start-Sleep -Milliseconds $ThrottleDelayMs }
}
Write-Log "INFO" "Bulk" "Loaded $inboundTotal inbound App Role Assignments across $($InboundRoleCache.Count) SPs"
```

### Bulk Load 6 — All Directory Role Assignments

```powershell
# ✅ PERFORMANCE FIX: Load role definitions separately (small, static dataset ~80 roles)
#    instead of using -ExpandProperty "roleDefinition" on every assignment.
#    This avoids throttling on large tenants with thousands of role assignments.

# Step 1: Load all role definitions (small call, ~80 built-in roles)
$AllRoleDefinitions = Get-MgRoleManagementDirectoryRoleDefinition -All -Property @(
    "id", "displayName", "isBuiltIn"
)
$RoleDefCache = @{}   # keyed by roleDefinitionId → role definition object
foreach ($rd in $AllRoleDefinitions) { $RoleDefCache[$rd.Id] = $rd }
Write-Log "INFO" "Bulk" "Loaded $($AllRoleDefinitions.Count) Directory Role Definitions"

# Step 2: Load all role assignments WITHOUT -ExpandProperty
$AllDirRoleAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All `
    -Property "id,principalId,roleDefinitionId,directoryScopeId"

# Step 3: Join in memory using the RoleDefCache (O(1) lookups)
$DirRoleCache = @{}   # keyed by principalId
foreach ($ra in $AllDirRoleAssignments) {
    # Attach role definition from cache
    $ra | Add-Member -NotePropertyName "RoleDefinition" -NotePropertyValue $RoleDefCache[$ra.RoleDefinitionId] -Force

    if (-not $DirRoleCache.ContainsKey($ra.PrincipalId)) {
        $DirRoleCache[$ra.PrincipalId] = [System.Collections.Generic.List[object]]::new()
    }
    $DirRoleCache[$ra.PrincipalId].Add($ra)
}
Write-Log "INFO" "Bulk" "Loaded $($AllDirRoleAssignments.Count) Directory Role Assignments"
```

### Bulk Load 7 — Azure RBAC Assignments (All Subscriptions)

```powershell
$AzureRbacCache = @{}   # keyed by SP ObjectId

if (-not $SkipAzureRBAC) {
    foreach ($sub in $script:AzSubscriptions) {
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
            Write-Log "WARN" "AzureRBAC" "Could not load RBAC from sub $($sub.Id): $($_.Exception.Message)"
        }
    }
    Write-Log "INFO" "Bulk" "Loaded Azure RBAC assignments across $($script:AzSubscriptions.Count) subscriptions"
}
```

### Bulk Load 8 — Conditional Access Policies (Simplified)

```powershell
# Load all CA policies once — extract included app IDs into a flat set for O(1) lookup
$AllCAPolicies = Get-MgIdentityConditionalAccessPolicy -All -Property @(
    "id", "displayName", "state", "conditions"
)
$CaProtectedAppIds = [System.Collections.Generic.HashSet[string]]::new()
foreach ($policy in $AllCAPolicies) {
    # ✅ FIX: Graph SDK returns State as "Enabled" (PascalCase), not "enabled" (lowercase).
    #    Also include "enabledForReportingButNotEnforced" — these policies are active in reporting mode.
    if ($policy.State -in @("enabled", "Enabled", "enabledForReportingButNotEnforced")) {
        foreach ($appId in $policy.Conditions.Applications.IncludeApplications) {
            [void]$CaProtectedAppIds.Add($appId)
        }
    }
}
Write-Log "INFO" "Bulk" "Loaded $($AllCAPolicies.Count) CA policies. Protected apps: $($CaProtectedAppIds.Count)"
```

> **Sign-in Logs are NOT bulk-loadable** — they must be queried per app.
> However, the `signInActivity` property on Service Principals (Bulk Load 2) provides
> ALL-TIME last sign-in dates without per-app queries. Use sign-in log queries only
> when you need additional detail (IP address, location, client app used).
> When `-SkipSignInLogs` is NOT set, warn the operator that 9,000 sign-in log queries
> will take approximately 2–4 hours depending on throttling.

---

## Phase 2: Per-App Signal Collection

For each app in `$AllApps`, collect the following signals via cache lookups (free) or targeted Graph calls (documented).

---

### Signal A — App Registration Base Properties (Cache Lookup — Free)

From `$AppCache[$AppId]`:

```powershell
$ObjectId          = $app.Id
$AppId             = $app.AppId
$DisplayName       = $app.DisplayName
$CreatedDateTime   = $app.CreatedDateTime
$SignInAudience    = $app.SignInAudience
$PublisherDomain   = $app.PublisherDomain
$Tags              = ($app.Tags -join ";")

# ✅ NEW: Verified Publisher detection (Salesforce, ServiceNow, etc.)
# Apps from verified publishers are legitimate SaaS apps — less likely to be abandoned
$VerifiedPublisher = $app.VerifiedPublisher.DisplayName ?? "NotVerified"
$IsVerifiedPublisher = ($null -ne $app.VerifiedPublisher -and
                       -not [string]::IsNullOrWhiteSpace($app.VerifiedPublisher.DisplayName))

# ✅ NEW: Microsoft 1st-party app detection (from Bulk Load 2 cache)
# Microsoft-owned apps (Office 365, Teams, Azure Portal, etc.) should NEVER be in cleanup buckets
$IsMicrosoftApp = $MicrosoftAppIds.Contains($AppId)

# App age (used in scoring — older unused apps are safer to clean up)
$AppAgeDays = [int]((Get-Date) - $CreatedDateTime).TotalDays

# Redirect URIs (zero extra Graph calls)
$WebRedirectUris       = ($app.Web.RedirectUris -join ";")
$SpaRedirectUris       = ($app.Spa.RedirectUris -join ";")
$PublicClientUris      = ($app.PublicClient.RedirectUris -join ";")
$AllRedirectUris       = @($app.Web.RedirectUris + $app.Spa.RedirectUris + $app.PublicClient.RedirectUris) | Where-Object { $_ }
$HasLocalhostUri       = ($AllRedirectUris | Where-Object { $_ -match "localhost" }).Count -gt 0
$HasHttpUri            = ($AllRedirectUris | Where-Object { $_ -match "^http://" }).Count -gt 0
$HasNgrokUri           = ($AllRedirectUris | Where-Object { $_ -match "ngrok" }).Count -gt 0
$RedirectUriCount      = $AllRedirectUris.Count

# Public client detection (zero extra calls)
$IsPublicClient        = ($null -ne $app.PublicClient -and $app.PublicClient.RedirectUris.Count -gt 0)

# API provider detection (zero extra calls)
$ExposedScopeCount     = $app.Api.Oauth2PermissionScopes.Count
$ExposedRoleCount      = $app.Api.AppRoles.Count
$IsApiProvider         = ($ExposedScopeCount -gt 0 -or $ExposedRoleCount -gt 0)
$ExposedPermissions    = @(
    ($app.Api.Oauth2PermissionScopes | ForEach-Object { $_.Value })
    ($app.Api.AppRoles               | ForEach-Object { $_.Value })
) -join ";"

# Declared permission count
$DeclaredPermissionCount = ($app.RequiredResourceAccess | ForEach-Object { $_.ResourceAccess.Count } | Measure-Object -Sum).Sum
```

---

### Signal B — Service Principal + ALL-TIME Sign-in Activity (Cache Lookup — Free)

```powershell
$sp = $SpCache[$AppId]

if ($null -eq $sp) {
    $ServicePrincipalId    = "NoSP"
    $IsEnabled             = "N/A"
    $NoServicePrincipal    = $true
    $ServicePrincipalType  = "N/A"
    $SPLastSignInDate      = $null
    $SPLastDaemonSignInDate = $null
} else {
    $ServicePrincipalId    = $sp.Id
    $IsEnabled             = $sp.AccountEnabled
    $NoServicePrincipal    = $false
    $ServicePrincipalType  = $sp.ServicePrincipalType

    # ✅ NEW: ALL-TIME sign-in dates from signInActivity (loaded in Bulk Load 2)
    #    These are NOT limited by log retention (30d/7d).
    #    They tell you the LAST TIME this SP was used — ever.
    $SPLastSignInDate       = $sp.SignInActivity.LastSignInDateTime
    $SPLastDaemonSignInDate = $sp.SignInActivity.LastNonInteractiveSignInDateTime
}
```

---

### Signal C — Owners (Cache Lookup — Free, via $expand)

```powershell
# ✅ PERFORMANCE FIX: Owners were bulk-loaded via $expand in Bulk Load 1.
#    No per-app Graph call needed. This saves 9,000 API calls.
$owners = $app.Owners
$OwnerUPNs    = if ($owners.Count -gt 0) {
    ($owners | ForEach-Object { $_.AdditionalProperties.userPrincipalName ?? $_.AdditionalProperties.displayName ?? $_.Id }) -join ";"
} else { "NoOwner" }
$OwnerCount   = $owners.Count
$HasOwner     = $owners.Count -gt 0
```

---

### Signal D — Federated Identity Credentials (Cache Lookup — Free, via $expand)

```powershell
# ✅ PERFORMANCE FIX: Federated creds were bulk-loaded via $expand in Bulk Load 1.
#    No per-app Graph call needed. This saves 9,000 API calls.
$fedCreds = $app.FederatedIdentityCredentials

$FederatedCredentialCount = if ($null -ne $fedCreds) { $fedCreds.Count } else { 0 }
$FederatedCredentials     = if ($FederatedCredentialCount -gt 0) { ($fedCreds | ForEach-Object { $_.Name }) -join ";" } else { "None" }
$FederatedIssuers         = if ($FederatedCredentialCount -gt 0) { ($fedCreds | ForEach-Object { $_.Issuer }) -join ";" } else { "None" }
$FederatedSubjects        = if ($FederatedCredentialCount -gt 0) { ($fedCreds | ForEach-Object { $_.Subject }) -join ";" } else { "None" }
$UsedByExternalSystem     = $FederatedCredentialCount -gt 0
$ExternalSystemType       = Get-ExternalSystemType -Issuers $fedCreds.Issuer
# RULE: If UsedByExternalSystem = $true → IsUnused MUST = $false regardless of sign-in logs
```

---

### Signal E — Interactive Sign-in Logs (Per-App Graph Call — Optional, -SkipSignInLogs)

```powershell
# ⚠️ RETENTION: 30 days max for interactive sign-in logs (all license tiers).
#    For longer retention, the tenant must stream logs to a Log Analytics workspace.
# ⚠️ PERFORMANCE: 9,000 calls. Warn operator before running.
# ✅ NOTE: The signInActivity property on the SP (Signal B) already provides ALL-TIME
#    last sign-in dates. These per-app audit log queries add DETAIL (IP, location, client app)
#    but are NOT required for basic usage classification. Consider skipping with -SkipSignInLogs
#    unless you need the detailed sign-in context.

$LastInteractiveSignInDate    = $null
$LastSignInResourceName       = "NoData"
$LastSignInUserUPN            = "NoData"
$LastSignInIPAddress          = "NoData"
$LastSignInLocation           = "NoData"
$LastSignInClientApp          = "NoData"
$LegacyAuthDetected           = $false
$IsCoveredByCAPolicy          = $CaProtectedAppIds.Contains($AppId)  # ← FREE (bulk cache)

if (-not $SkipSignInLogs -and -not $NoServicePrincipal) {
    $siDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $signIn = Invoke-GraphWithRetry -OperationName "InteractiveSignIn-$AppId" -ScriptBlock {
        Get-MgAuditLogSignIn `
            -Filter "appId eq '$AppId' and createdDateTime ge $siDate" `
            -Top 1 -OrderBy "createdDateTime desc" `
            -Property @(
                "createdDateTime","resourceDisplayName","resourceId",
                "userPrincipalName","ipAddress","location",
                "clientAppUsed","conditionalAccessStatus","status"
            )
    }
    if ($null -ne $signIn) {
        $LastInteractiveSignInDate = $signIn.CreatedDateTime
        $LastSignInResourceName    = $signIn.ResourceDisplayName ?? "NoData"
        $LastSignInUserUPN         = $signIn.UserPrincipalName   ?? "NoData"
        $LastSignInIPAddress       = $signIn.IpAddress            ?? "NoData"
        $loc                       = $signIn.Location
        $LastSignInLocation        = if ($loc) { "$($loc.City), $($loc.CountryOrRegion)" } else { "NoData" }
        $LastSignInClientApp       = $signIn.ClientAppUsed        ?? "NoData"
        $LegacyAuthDetected        = $LastSignInClientApp -match "Basic Auth|SMTP|POP3|IMAP|MAPI|Exchange ActiveSync|Other clients"
    }
}
```

---

### Signal F — SP/Daemon Sign-in Logs (Per-App Graph Call — Optional, -SkipSignInLogs)

```powershell
# ⚠️ RETENTION: 7–30 days depending on license tier.
#    - Entra ID Free: 7 days
#    - Entra ID P1/P2: 30 days
#    For longer retention, stream logs to a Log Analytics workspace.
# ✅ NOTE: The signInActivity.LastNonInteractiveSignInDateTime on the SP (Signal B)
#    already provides ALL-TIME daemon sign-in dates. These per-app queries add detail only.
# Machine-to-machine (client credentials flow) — separate from interactive logs

$LastSPSignInDate         = $null
$LastSPSignInResourceName = "NoData"
$DaemonUsageDetected      = $false

if (-not $SkipSignInLogs -and -not $NoServicePrincipal) {
    $spSiDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $spSignIn = Invoke-GraphWithRetry -OperationName "SPSignIn-$AppId" -ScriptBlock {
        Get-MgAuditLogSignIn `
            -Filter "appId eq '$AppId' and signInEventTypes/any(t: t eq 'servicePrincipal') and createdDateTime ge $spSiDate" `
            -Top 1 -OrderBy "createdDateTime desc" `
            -Property @("createdDateTime","resourceDisplayName","ipAddress","status")
    }
    if ($null -ne $spSignIn) {
        $LastSPSignInDate         = $spSignIn.CreatedDateTime
        $LastSPSignInResourceName = $spSignIn.ResourceDisplayName ?? "NoData"
        $DaemonUsageDetected      = $true
    }
}
```

---

### Signal G — Outbound App Role Assignments (Cache Lookup — Free)

```powershell
$outbound = if ($ServicePrincipalId -ne "NoSP") { $OutboundRoleCache[$ServicePrincipalId] } else { $null }
$AppRoleAssignmentCount    = if ($outbound) { $outbound.Count } else { 0 }
$AppRoleAssignedResources  = if ($outbound) { ($outbound | ForEach-Object { $_.ResourceDisplayName } | Select-Object -Unique) -join ";" } else { "None" }
```

---

### Signal H — Inbound Consumers (Cache Lookup — Free)

```powershell
$inbound = if ($ServicePrincipalId -ne "NoSP") { $InboundRoleCache[$ServicePrincipalId] } else { $null }

$consumingApps   = $inbound | Where-Object { $_.PrincipalType -eq "ServicePrincipal" }
$assignedUsers   = $inbound | Where-Object { $_.PrincipalType -eq "User" }
$assignedGroups  = $inbound | Where-Object { $_.PrincipalType -eq "Group" }

$ConsumedByAppsCount   = ($consumingApps  | Measure-Object).Count
$ConsumedByApps        = ($consumingApps  | ForEach-Object { $_.PrincipalDisplayName }) -join ";"
$AssignedUsersCount    = ($assignedUsers  | Measure-Object).Count
$AssignedGroupsCount   = ($assignedGroups | Measure-Object).Count
$AssignedGroupNames    = ($assignedGroups | ForEach-Object { $_.PrincipalDisplayName }) -join ";"
$IsActingAsResourceApp = $ConsumedByAppsCount -gt 0

# BLAST RADIUS: If this app is consumed by others, deletion will break those consumers
$DeletionBlastRadius = $ConsumedByAppsCount + $AssignedUsersCount + $AssignedGroupsCount
```

---

### Signal I — OAuth2 Permission Grants (Cache Lookup — Free)

```powershell
$grants = if ($ServicePrincipalId -ne "NoSP") { $OAuthGrantCache[$ServicePrincipalId] } else { $null }
$OAuthGrantCount      = if ($grants) { $grants.Count } else { 0 }
$OAuthGrantScopes     = if ($grants) { ($grants | ForEach-Object { $_.Scope }) -join ";" } else { "None" }
$AdminConsentGranted  = ($grants | Where-Object { $_.ConsentType -eq "AllPrincipals" }).Count -gt 0
```

---

### Signal J — Directory Role Assignments (Cache Lookup — Free)

```powershell
$dirRoles = if ($ServicePrincipalId -ne "NoSP") { $DirRoleCache[$ServicePrincipalId] } else { $null }
$DirectoryRoles          = if ($dirRoles) { ($dirRoles | ForEach-Object { $_.RoleDefinition.DisplayName }) -join ";" } else { "None" }
$DirectoryRoleCount      = if ($dirRoles) { $dirRoles.Count } else { 0 }
$HasPrivilegedEntraRole  = ($dirRoles | Where-Object {
    $_.RoleDefinition.DisplayName -in @(
        "Global Administrator","Privileged Role Administrator",
        "Application Administrator","Cloud Application Administrator",
        "Exchange Administrator","SharePoint Administrator"
    )
}).Count -gt 0
```

---

### Signal K — Azure RBAC (Cache Lookup — Free)

```powershell
$rbac = if ($ServicePrincipalId -ne "NoSP") { $AzureRbacCache[$ServicePrincipalId] } else { $null }
$AzureRBACRoleCount       = if ($rbac) { $rbac.Count } else { 0 }
$AzureRBACRoles           = if ($rbac) { ($rbac | ForEach-Object { $_.RoleDefinitionName } | Select-Object -Unique) -join ";" } else { "None" }
$AzureRBACScopes          = if ($rbac) { ($rbac | ForEach-Object { $_.Scope }            | Select-Object -Unique) -join ";" } else { "None" }
$HasAzureRBACRoles        = $AzureRBACRoleCount -gt 0
$HasPrivilegedAzureRole   = ($rbac | Where-Object { $_.RoleDefinitionName -in @("Owner","Contributor","User Access Administrator") }).Count -gt 0
```

---

### Signal L — Credential Health + Secret Age (Zero Extra Calls)

```powershell
$now = Get-Date

# Secrets
$secrets              = $app.PasswordCredentials
$SecretCount          = $secrets.Count
$HasExpiredSecret     = ($secrets | Where-Object { $_.EndDateTime -lt $now }).Count -gt 0
$NearestSecretExpiry  = if ($SecretCount -gt 0) { ($secrets | Sort-Object EndDateTime | Select-Object -First 1).EndDateTime } else { "NoSecret" }
$OldestSecretAgeDays  = if ($SecretCount -gt 0) {
    $oldest = ($secrets | Sort-Object StartDateTime | Select-Object -First 1).StartDateTime
    if ($null -ne $oldest) { [int]($now - $oldest).TotalDays } else { -1 }
} else { -1 }

# ✅ FIX: AllSecretsExpired = ALL secrets are expired (not just "at least one is expired")
#    HasExpiredSecret only means ONE or more secrets are expired.
#    An app with 3 secrets (2 expired, 1 still valid) should NOT get the "all expired" bonus.
$AllSecretsExpired = ($SecretCount -gt 0 -and
    ($secrets | Where-Object { $_.EndDateTime -ge $now }).Count -eq 0)

# Certificates
$certs                = $app.KeyCredentials
$CertCount            = $certs.Count
$HasExpiredCert       = ($certs | Where-Object { $_.EndDateTime -lt $now }).Count -gt 0
$NearestCertExpiry    = if ($CertCount -gt 0) { ($certs | Sort-Object EndDateTime | Select-Object -First 1).EndDateTime } else { "NoCert" }
$AllCertsExpired      = ($CertCount -gt 0 -and
    ($certs | Where-Object { $_.EndDateTime -ge $now }).Count -eq 0)

# Secretless authentication detection
$UsesPasswordlessAuth = ($FederatedCredentialCount -gt 0 -or $CertCount -gt 0 -or
                         $ServicePrincipalType -eq "ManagedIdentity")
$AuthMethod = if ($ServicePrincipalType -eq "ManagedIdentity") { "ManagedIdentity" }
              elseif ($FederatedCredentialCount -gt 0)         { "FederatedCredential" }
              elseif ($CertCount -gt 0 -and $SecretCount -eq 0){ "CertificateOnly" }
              elseif ($SecretCount -gt 0)                      { "ClientSecret" }
              else                                             { "NoCredential" }
```

---

### Signal M — Broad Permission Detection (Zero Extra Calls)

```powershell
# Lookup hashtable — DO NOT resolve GUIDs via Graph at runtime.
# ✅ EXPANDED: Added Application.ReadWrite.All, GroupMember.ReadWrite.All,
#    Sites.ReadWrite.All, MailboxSettings.ReadWrite, Calendars.ReadWrite
#    which are high-impact permissions commonly over-provisioned.
$BroadPermissions = @{
    # Application permissions (Role)
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
    # Delegated permissions (Scope)
    "741f803b-c850-494e-b5df-cde7c675a1ca" = "User.ReadWrite.All (Delegated)"
}

$HasBroadGraphPermissions = $false
$BroadPermissionNames     = [System.Collections.Generic.List[string]]::new()

$graphResourceId = "00000003-0000-0000-c000-000000000000"
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
```

---

## Phase 3: Deletion Safety Scoring Engine

Implement as function `Get-DeletionSafetyScore`.

**Scoring philosophy:** Score starts at 100 (safe to delete). Evidence of active use deducts points.
Higher score = safer to delete. Lower score = higher risk to touch.

```powershell
function Get-DeletionSafetyScore {
    param([hashtable]$Signals)

    $score  = 100
    $reasons = [System.Collections.Generic.List[string]]::new()

    # ── INSTANT OVERRIDE: Microsoft 1st-party apps ───────────────────────────
    # Microsoft-owned apps (Office 365, Teams, Azure Portal, etc.) are NEVER cleanup targets.
    if ($Signals.IsMicrosoftApp) {
        return @{
            Score        = 0
            ScoreReasons = "Microsoft1stPartyApp"
        }
    }

    # ── HARD BLOCKS (score floor = 0, do not touch) ──────────────────────────
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

    # ── STRONG EVIDENCE OF ACTIVE USE ────────────────────────────────────────

    # ✅ NEW: Use ALL-TIME sign-in date from signInActivity (Signal B) first.
    #    This is more reliable than audit log queries which have 30-day retention.
    $bestSignInDate = $null
    if ($null -ne $Signals.SPLastSignInDate) { $bestSignInDate = $Signals.SPLastSignInDate }
    if ($null -ne $Signals.SPLastDaemonSignInDate -and
        ($null -eq $bestSignInDate -or $Signals.SPLastDaemonSignInDate -gt $bestSignInDate)) {
        $bestSignInDate = $Signals.SPLastDaemonSignInDate
    }
    # Overlay audit log dates if they're more recent
    if ($null -ne $Signals.LastInteractiveSignInDate -and
        ($null -eq $bestSignInDate -or $Signals.LastInteractiveSignInDate -gt $bestSignInDate)) {
        $bestSignInDate = $Signals.LastInteractiveSignInDate
    }

    if ($null -ne $bestSignInDate) {
        $daysSince = [int]((Get-Date) - $bestSignInDate).TotalDays
        if ($daysSince -le 30)  { $score -= 60; $reasons.Add("SignIn:${daysSince}dAgo") }
        elseif ($daysSince -le 90)  { $score -= 50; $reasons.Add("SignIn:${daysSince}dAgo") }
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

    # ── MODERATE EVIDENCE ────────────────────────────────────────────────────
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

    # ── WEAK EVIDENCE (configuration exists, may or may not be in use) ───────
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

    # ── POSITIVE SIGNALS (increases confidence it is truly unused) ───────────
    if ($Signals.NoServicePrincipal) {
        $score += 10    # No SP = cannot issue tokens, safer to delete
        $reasons.Add("+NoSP")
    }
    # ✅ FIX: Use AllSecretsExpired (ALL secrets expired) instead of HasExpiredSecret (ANY expired)
    if ($Signals.AllSecretsExpired -and $Signals.CertCount -eq 0 -and -not $Signals.UsedByExternalSystem) {
        $score += 5     # ALL credentials expired and no certs = less likely to be actively used
        $reasons.Add("+AllSecretsExpired")
    }
    # ✅ NEW: App age factor — older unused apps are safer to clean up
    if ($Signals.AppAgeDays -gt 730 -and $null -eq $bestSignInDate) {
        $score += 10    # 2+ years old with no sign-in signal = likely abandoned
        $reasons.Add("+OldUnused:$($Signals.AppAgeDays)d")
    }
    if ($Signals.AppAgeDays -lt 30) {
        $score -= 15    # Brand new app — may not be configured yet, don't touch
        $reasons.Add("NewlyCreated:$($Signals.AppAgeDays)d")
    }
    # ✅ NEW: Verified publisher bonus (legitimate SaaS apps from known vendors)
    if ($Signals.IsVerifiedPublisher) {
        $score -= 5     # Verified publisher = more likely a real, managed app
        $reasons.Add("VerifiedPublisher")
    }

    # Clamp to 0–100 (score can go negative from cumulative deductions — this is by design)
    $score = [Math]::Max(0, [Math]::Min(100, $score))

    return @{
        Score         = $score
        ScoreReasons  = $reasons -join "|"
    }
}
```

---

## Phase 4: Usage Classification (Updated — All Signals)

Implement as `Get-AppUsageStatus`:

```powershell
function Get-AppUsageStatus {
    param([hashtable]$Signals)

    # Step 1: Most recent confirmed sign-in date
    $candidates = @($Signals.LastInteractiveSignInDate, $Signals.LastSPSignInDate) |
                  Where-Object { $_ -is [datetime] } |
                  Sort-Object -Descending
    $LastUsedDate = if ($candidates.Count -gt 0) { $candidates[0] } else { $null }

    # Step 2: Any non-date usage signal
    $hasConfigSignal = (
        $Signals.AppRoleAssignmentCount   -gt 0 -or
        $Signals.ConsumedByAppsCount      -gt 0 -or
        $Signals.OAuthGrantCount          -gt 0 -or
        $Signals.DirectoryRoleCount       -gt 0 -or
        $Signals.AzureRBACRoleCount       -gt 0 -or
        $Signals.FederatedCredentialCount -gt 0 -or   # Definitive: external system dependency
        $Signals.AssignedUsersCount       -gt 0 -or   # Definitive: users use this app
        $Signals.AssignedGroupsCount      -gt 0        # Definitive: groups assigned
    )

    # Step 3: Classify with confidence
    if ($null -ne $LastUsedDate) {
        $IsUnused        = $false
        $UsageConfidence = "High"     # Real sign-in date confirmed
    } elseif ($Signals.UsedByExternalSystem) {
        $IsUnused        = $false
        $UsageConfidence = "High"     # Federated creds = active CI/CD dependency
        $LastUsedDate    = "FederatedActive"
    } elseif ($hasConfigSignal) {
        $IsUnused        = $false
        $UsageConfidence = "Medium"   # Assigned/configured but no login in retention window
        $LastUsedDate    = "SignalFound-NoDate"
    } else {
        $IsUnused        = $true
        $UsageConfidence = "Low"
        $LastUsedDate    = "NoSignal"
    }

    # Step 4: Age classification
    $UnusedMoreThan1Year = $false
    if ($IsUnused) {
        $UnusedMoreThan1Year = $true  # No signal at all
    } elseif ($LastUsedDate -is [datetime] -and $LastUsedDate -lt (Get-Date).AddDays(-365)) {
        $UnusedMoreThan1Year = $true
    }

    # Step 5: Days since last use
    $DaysSinceLastUse = if ($LastUsedDate -is [datetime]) {
        [int]((Get-Date) - $LastUsedDate).TotalDays
    } else { -1 }

    return @{
        IsUnused             = $IsUnused
        UsageConfidence      = $UsageConfidence
        LastUsedDate         = $LastUsedDate
        UnusedMoreThan1Year  = $UnusedMoreThan1Year
        DaysSinceLastUse     = $DaysSinceLastUse
    }
}
```

---

## Phase 5: Bucket Assignment

```powershell
function Get-CleanupBucket {
    param(
        [int]$Score,
        [bool]$IsUnused,
        [string]$UsageConfidence,
        [bool]$IsMicrosoftApp = $false
    )

    # ✅ OVERRIDE 1: Microsoft 1st-party apps are NEVER cleanup targets
    if ($IsMicrosoftApp) {
        return @{ Bucket = 4; Label = "Microsoft1stParty";    Emoji = "🟢"; Action = "DO NOT TOUCH — MICROSOFT OWNED" }
    }

    # OVERRIDE 2: High-confidence active apps
    if (-not $IsUnused -and $UsageConfidence -eq "High") {
        return @{ Bucket = 4; Label = "BusinessCritical";     Emoji = "🟢"; Action = "DO NOT TOUCH" }
    }

    switch ($true) {
        ($Score -ge 80) { return @{ Bucket = 1; Label = "SafeToDisable";       Emoji = "🔴"; Action = "DISABLE NOW → DELETE IN 30 DAYS" } }
        ($Score -ge 50) { return @{ Bucket = 2; Label = "NeedsInvestigation";  Emoji = "🟡"; Action = "SEND TO OWNER FOR REVIEW" } }
        ($Score -ge 20) { return @{ Bucket = 3; Label = "LikelyActive";        Emoji = "🟠"; Action = "DO NOT TOUCH — GATHER MORE EVIDENCE" } }
        default         { return @{ Bucket = 4; Label = "BusinessCritical";    Emoji = "🟢"; Action = "DO NOT TOUCH" } }
    }
}
```

---

## Phase 6: Managed Identity Sweep (Separate Pass)

> **Architecture Note:** Managed Identities are Service Principals, NOT App Registrations.
> They do NOT appear in `Get-MgApplication`. They require a dedicated second sweep
> of the already-bulk-loaded `$MiCache`.

```powershell
# After the main app loop completes, perform a dedicated MI governance pass
$MiReport = [System.Collections.Generic.List[object]]::new()

foreach ($mi in $MiCache.Values) {
    $miRbac   = $AzureRbacCache[$mi.Id]
    $miDirRole = $DirRoleCache[$mi.Id]

    $miRBACRoles  = if ($miRbac)    { ($miRbac    | ForEach-Object { $_.RoleDefinitionName }) -join ";" } else { "None" }
    $miDirRoles   = if ($miDirRole) { ($miDirRole | ForEach-Object { $_.RoleDefinition.DisplayName }) -join ";" } else { "None" }

    # ✅ FIX: Determine MI type from AlternativeNames (not Tags).
    # System-assigned MIs have an entry like "/subscriptions/<guid>/resourceGroups/..." in AlternativeNames.
    # User-assigned MIs do not have a /subscriptions/ entry.
    $altNames = $mi.AlternativeNames
    $isSystemAssigned = ($altNames | Where-Object { $_ -like '/subscriptions/*' }).Count -gt 0
    $miType = if ($isSystemAssigned) { "SystemAssigned" } else { "UserAssigned" }

    # Determine linked resource from AlternativeNames or DisplayName
    # System-assigned MIs: the /subscriptions/... entry IS the linked ARM resource ID
    # User-assigned MIs: DisplayName is the best available hint
    $LinkedResource = if ($isSystemAssigned) {
        ($altNames | Where-Object { $_ -like '/subscriptions/*' }) | Select-Object -First 1
    } else {
        $mi.DisplayName   # Best available — actual ARM resource link requires Azure Resource Graph
    }

    # ✅ FIX: Use $miRecord (not $miReport) to avoid overwriting the $MiReport list
    $miRecord = [PSCustomObject]@{
        DisplayName            = $mi.DisplayName
        ServicePrincipalId     = $mi.Id
        AppId                  = $mi.AppId
        ManagedIdentityType    = $miType
        LinkedResource         = $LinkedResource
        IsEnabled              = $mi.AccountEnabled
        CreatedDateTime        = $mi.CreatedDateTime
        AzureRBACRoles         = $miRBACRoles
        AzureRBACRoleCount     = if ($miRbac) { $miRbac.Count } else { 0 }
        HasPrivilegedAzureRole = ($miRbac | Where-Object { $_.RoleDefinitionName -in @("Owner","Contributor","User Access Administrator") }).Count -gt 0
        DirectoryRoles         = $miDirRoles
        HasPrivilegedEntraRole = ($miDirRole | Where-Object { $_.RoleDefinition.DisplayName -in @("Global Administrator","Application Administrator","Privileged Role Administrator") }).Count -gt 0
        # Governance flag: Is this MI still linked to an existing Azure resource?
        # Full orphan detection requires Azure Resource Graph query — add as future enhancement note
        PossiblyOrphaned       = ($miRbac.Count -eq 0 -and $miDirRole.Count -eq 0)
    }
    $MiReport.Add($miRecord)
}
```

---

## Phase 7: WHERE-Usage Summary

Implement as `Get-AppWhereUsed`:

```powershell
function Get-AppWhereUsed {
    param([hashtable]$Signals)

    $locations = [System.Collections.Generic.List[string]]::new()

    if ($Signals.LastSignInResourceName -ne "NoData") {
        $locations.Add("UserSignIn→$($Signals.LastSignInResourceName)")
    }
    if ($Signals.DaemonUsageDetected) {
        $locations.Add("DaemonSignIn→$($Signals.LastSPSignInResourceName)")
    }
    if ($Signals.AppRoleAssignedResources -ne "None") {
        $locations.Add("CallsAPI→$($Signals.AppRoleAssignedResources)")
    }
    if ($Signals.ConsumedByApps -ne "") {
        $locations.Add("ConsumedBy→$($Signals.ConsumedByApps)")
    }
    if ($Signals.AzureRBACScopes -ne "None") {
        $locations.Add("AzureScope→$($Signals.AzureRBACScopes)")
    }
    if ($Signals.UsedByExternalSystem) {
        $locations.Add("ExternalSystem→$($Signals.ExternalSystemType)")
    }
    if ($Signals.AssignedGroupNames -ne "") {
        $locations.Add("AssignedGroups→$($Signals.AssignedGroupNames)")
    }
    if ($Signals.IsApiProvider) {
        $locations.Add("ExposesAPI→$($Signals.ExposedPermissions)")
    }

    return if ($locations.Count -gt 0) { $locations -join " | " } else { "NoUsageSignalFound" }
}
```

---

## Phase 8: Output Files

### Output Directory Structure

```
📁 <OutputDirectory>/
│
├── 🔴 Bucket1_SafeToDisable_<TenantId>_<YYYYMMDD>.csv
├── 🟡 Bucket2_NeedsInvestigation_<TenantId>_<YYYYMMDD>.csv
├── 🟠 Bucket3_LikelyActive_<TenantId>_<YYYYMMDD>.csv
├── 🟢 Bucket4_BusinessCritical_<TenantId>_<YYYYMMDD>.csv
│
├── 📁 OwnerNotifications/
│   ├── Owner_<UPN-sanitized>_<YYYYMMDD>.csv     ← One per owner with their apps
│   └── NoOwner_Escalation_<YYYYMMDD>.csv         ← Apps with no owner (escalate to IT Admin)
│
├── 🔵 ManagedIdentity_Audit_<TenantId>_<YYYYMMDD>.csv
├── 📋 MasterAudit_Full_<TenantId>_<YYYYMMDD>.csv
└── 📝 AuditLog_<TenantId>_<YYYYMMDD_HHmmss>.log
```

---

### Master Audit CSV — Complete Column Schema

#### Identity & Classification
| Column | Type | Sentinel |
|---|---|---|
| CleanupBucket | int | 1–4 |
| BucketLabel | string | `SafeToDisable` / `NeedsInvestigation` / `LikelyActive` / `BusinessCritical` |
| RecommendedAction | string | Action string from bucket |
| DeletionSafetyScore | int | 0–100 |
| ScoreReasons | string | Pipe-delimited deduction reasons |
| AppName | string | |
| AppId | GUID | |
| ObjectId | GUID | |
| CreatedDate | datetime | ISO 8601 |
| SignInAudience | string | |
| ServicePrincipalId | string | `"NoSP"` |
| NoServicePrincipal | bool | |
| IsEnabled | bool/string | `"N/A"` if NoSP |
| ServicePrincipalType | string | |
| Tags | string | Semicolon-delimited |

#### Ownership
| Column | Type | Sentinel |
|---|---|---|
| OwnerUPNs | string | `"NoOwner"` |
| OwnerCount | int | |
| HasOwner | bool | |

#### Usage Classification
| Column | Type | Sentinel |
|---|---|---|
| IsUnused | bool | |
| UnusedMoreThan1Year | bool | |
| UsageConfidence | string | `High` / `Medium` / `Low` |
| LastUsedDate | datetime/string | `"NoSignal"` / `"SignalFound-NoDate"` / `"FederatedActive"` |
| DaysSinceLastUse | int | `-1` if no date |
| UsageLocationSummary | string | Output of `Get-AppWhereUsed` |

#### Interactive Sign-in
| Column | Type | Sentinel |
|---|---|---|
| LastInteractiveSignInDate | datetime/string | `"NoData"` |
| DaysSinceInteractiveSignIn | int | `-1` |
| LastSignInResourceName | string | `"NoData"` |
| LastSignInUserUPN | string | `"NoData"` |
| LastSignInIPAddress | string | `"NoData"` |
| LastSignInLocation | string | `"NoData"` |
| LastSignInClientApp | string | `"NoData"` |
| LegacyAuthDetected | bool | |
| IsCoveredByCAPolicy | bool | |

#### SP/Daemon Sign-in
| Column | Type | Sentinel |
|---|---|---|
| LastSPSignInDate | datetime/string | `"NoData"` |
| DaysSinceSPSignIn | int | `-1` |
| LastSPSignInResourceName | string | `"NoData"` |
| DaemonUsageDetected | bool | |

#### Inbound Consumers (Blast Radius)
| Column | Type | Sentinel |
|---|---|---|
| DeletionBlastRadius | int | Total count of consumers |
| ConsumedByAppsCount | int | |
| ConsumedByApps | string | Semicolon-delimited |
| AssignedUsersCount | int | |
| AssignedGroupsCount | int | |
| AssignedGroupNames | string | Semicolon-delimited |
| IsActingAsResourceApp | bool | |

#### Outbound API Usage
| Column | Type | Sentinel |
|---|---|---|
| AppRoleAssignmentCount | int | |
| AppRoleAssignedResources | string | Semicolon-delimited |

#### Delegated Permissions
| Column | Type | Sentinel |
|---|---|---|
| OAuthGrantCount | int | |
| OAuthGrantScopes | string | Semicolon-delimited |
| AdminConsentGranted | bool | |

#### Directory Roles
| Column | Type | Sentinel |
|---|---|---|
| DirectoryRoles | string | `"None"` |
| DirectoryRoleCount | int | |
| HasPrivilegedEntraRole | bool | |

#### Azure RBAC
| Column | Type | Sentinel |
|---|---|---|
| AzureRBACRoleCount | int | |
| AzureRBACRoles | string | `"None"` |
| AzureRBACScopes | string | `"None"` |
| HasAzureRBACRoles | bool | |
| HasPrivilegedAzureRole | bool | |

#### Federated Credentials / External Systems
| Column | Type | Sentinel |
|---|---|---|
| FederatedCredentialCount | int | |
| FederatedCredentials | string | Semicolon-delimited names |
| FederatedIssuers | string | Semicolon-delimited |
| FederatedSubjects | string | Semicolon-delimited (repo/namespace) |
| UsedByExternalSystem | bool | |
| ExternalSystemType | string | `GitHub Actions` / `AKS` / `Terraform Cloud` / `Azure DevOps` / `Unknown` |

#### Credential Health
| Column | Type | Sentinel |
|---|---|---|
| SecretCount | int | |
| NearestSecretExpiry | datetime/string | `"NoSecret"` |
| HasExpiredSecret | bool | |
| OldestSecretAgeDays | int | `-1` if no secret |
| CertCount | int | |
| NearestCertExpiry | datetime/string | `"NoCert"` |
| HasExpiredCert | bool | |
| AuthMethod | string | `ManagedIdentity` / `FederatedCredential` / `CertificateOnly` / `ClientSecret` / `NoCredential` |
| UsesPasswordlessAuth | bool | |

#### Application Architecture
| Column | Type | Sentinel |
|---|---|---|
| IsPublicClient | bool | |
| IsApiProvider | bool | |
| ExposedScopeCount | int | |
| ExposedRoleCount | int | |
| ExposedPermissions | string | Semicolon-delimited |
| DeclaredPermissionCount | int | |
| HasBroadGraphPermissions | bool | |
| BroadPermissionNames | string | Semicolon-delimited |
| RedirectUriCount | int | |
| WebRedirectUris | string | Semicolon-delimited |
| SpaRedirectUris | string | Semicolon-delimited |
| HasLocalhostUri | bool | |
| HasHttpUri | bool | |
| HasNgrokUri | bool | |

---

### Bucket CSVs

Each bucket CSV contains the same columns as the master but filtered to that bucket only.
Add one additional column to Bucket 1:

| Column | Type | Notes |
|---|---|---|
| ProposedDisableDate | date | Today's date |
| ProposedDeleteDate | date | Today + 30 days |
| DisabledConfirmed | string | Empty — filled by operator after disabling |
| OwnerNotified | string | Empty — filled by operator |

---

### Owner Notification CSVs

One CSV file per unique owner UPN, containing only that owner's apps, sorted by `DeletionSafetyScore` descending.

Columns to include (human-readable subset):

`AppName`, `AppId`, `DeletionSafetyScore`, `BucketLabel`, `RecommendedAction`,
`LastUsedDate`, `UsageConfidence`, `UsageLocationSummary`, `DeletionBlastRadius`,
`HasExpiredSecret`, `OldestSecretAgeDays`, `AuthMethod`, `CreatedDate`

```powershell
# Generate per-owner files
# ✅ FIX: Capture $_ as $currentApp before inner ForEach-Object overwrites $_
$byOwner = $MasterReport | Where-Object { $_.OwnerUPNs -ne "NoOwner" } |
           ForEach-Object {
               $currentApp = $_
               $currentApp.OwnerUPNs -split ";" | ForEach-Object { @{ Owner = $_; App = $currentApp } }
           } | Group-Object -Property Owner

foreach ($ownerGroup in $byOwner) {
    $safeOwnerFileName = $ownerGroup.Name -replace '[\\/:*?"<>|@]', '_'
    $ownerApps = $ownerGroup.Group | Select-Object -ExpandProperty App
    $ownerApps | Select-Object $OwnerNotificationColumns |
        Export-Csv -Path "$OutputDirectory\OwnerNotifications\Owner_${safeOwnerFileName}_$DateStamp.csv" `
                   -NoTypeInformation -Encoding UTF8
}

# Escalation file for ownerless apps
$MasterReport | Where-Object { $_.OwnerUPNs -eq "NoOwner" -and $_.CleanupBucket -le 2 } |
    Select-Object $OwnerNotificationColumns |
    Export-Csv -Path "$OutputDirectory\OwnerNotifications\NoOwner_Escalation_$DateStamp.csv" `
               -NoTypeInformation -Encoding UTF8
```

---

## Console Summary

```
╔══════════════════════════════════════════════════════════════════╗
║      Azure App Registration Cleanup System — v5 Summary          ║
╠══════════════════════════════════════════════════════════════════╣
║  Tenant ID                    : <TenantId>                       ║
║  Run Date                     : <Date>                           ║
║  Duration                     : <X> min <Y> sec                  ║
║  Subscriptions Scanned        : <N>                              ║
╠══════════════════════════════════════════════════════════════════╣
║  INVENTORY                                                       ║
║  Total App Registrations      : 9,000                            ║
║  Managed Identities (separate): XXXX                             ║
╠══════════════════════════════════════════════════════════════════╣
║  CLEANUP PIPELINE RESULTS                                        ║
║  🔴 Bucket 1 — Safe to Disable     : XXXX  (Score 80–100)       ║
║  🟡 Bucket 2 — Needs Investigation : XXXX  (Score 50–79)        ║
║  🟠 Bucket 3 — Likely Active       : XXXX  (Score 20–49)        ║
║  🟢 Bucket 4 — Business Critical   : XXXX  (Score 0–19)         ║
╠══════════════════════════════════════════════════════════════════╣
║  OWNERSHIP                                                       ║
║  Apps With Owners             : XXXX                             ║
║  Apps Without Owners          : XXXX                             ║
║  Owner Notification Files     : XXXX                             ║
║  Ownerless Escalation Apps    : XXXX                             ║
╠══════════════════════════════════════════════════════════════════╣
║  USAGE SIGNAL COVERAGE                                           ║
║  Confirmed Active (High)      : XXXX                             ║
║  Likely Active (Medium)       : XXXX                             ║
║  No Signal Found (Low)        : XXXX                             ║
║  Apps w/ Interactive Sign-in  : XXXX                             ║
║  Apps w/ Daemon Sign-in       : XXXX                             ║
║  Apps w/ Azure RBAC Roles     : XXXX                             ║
║  Apps Used by External CI/CD  : XXXX                             ║
║  Apps Consumed by Other Apps  : XXXX                             ║
╠══════════════════════════════════════════════════════════════════╣
║  RISK FLAGS                                                       ║
║  Apps w/ Privileged Entra Role: XXXX                             ║
║  Apps w/ Privileged Azure Role: XXXX                             ║
║  Apps w/ Broad Graph Perms    : XXXX                             ║
║  Apps w/ Expired Secrets      : XXXX                             ║
║  Apps w/ Secrets > 1yr Old    : XXXX                             ║
║  Apps w/ Legacy Auth          : XXXX                             ║
║  Public Clients w/ Broad Perms: XXXX                             ║
╠══════════════════════════════════════════════════════════════════╣
║  OUTPUT FILES                                                    ║
║  🔴 Bucket 1 CSV    : <path>                                     ║
║  🟡 Bucket 2 CSV    : <path>                                     ║
║  🟠 Bucket 3 CSV    : <path>                                     ║
║  🟢 Bucket 4 CSV    : <path>                                     ║
║  📋 Master Audit    : <path>                                     ║
║  🔵 Managed IDs     : <path>                                     ║
║  📁 Owner Files     : <path>                                     ║
║  📝 Log File        : <path>                                     ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Error Handling & Throttling

### `Invoke-GraphWithRetry` Function

```powershell
function Invoke-GraphWithRetry {
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
                Write-Log "ERROR" $OperationName "HTTP $statusCode — $($_.Exception.Message)"
                return $null
            }
        }
    }
    Write-Log "ERROR" $OperationName "Failed after $MaxRetries retries. Returning null."
    return $null
}
```

---

## Logging

```powershell
function Write-Log {
    param(
        [ValidateSet("INFO","WARN","ERROR","DEBUG")]
        [string]$Level   = "INFO",
        [string]$Signal  = "General",
        [string]$Message
    )
    $ts    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] [$Level] [$Signal] $Message"
    Add-Content -Path $script:LogFile -Value $entry
    switch ($Level) {
        "ERROR" { Write-Warning $Message }
        "WARN"  { Write-Warning $Message }
        "DEBUG" { if ($VerboseMode) { Write-Verbose $Message } }
        default { Write-Host $entry }
    }
}
```

Log filename: `AuditLog_<TenantId>_<YYYYMMDD_HHmmss>.log`

Log mandatory events:
- Script start + auth identity + tenant + subscription count
- Each bulk load: record count loaded
- Each app at DEBUG: AppId, DeletionSafetyScore, BucketLabel
- Every throttle: signal name + wait duration + attempt number
- Every error: signal name + AppId + exception message
- Script end: duration + all summary counts

---

## Script Structure (enforce this exact layout)

```
 1.  Script header: .SYNOPSIS, .DESCRIPTION, .PARAMETER, .NOTES
     NOTES must include:
     - Sign-in log retention caveat (7-30 days depending on Entra ID license tier)
     - signInActivity provides ALL-TIME sign-in dates (no retention limit)
     - Managed Identity limitation (ARM resource link requires Resource Graph)
     - Microsoft 1st-party apps are auto-excluded from cleanup
     - Recommended: run with -SkipSignInLogs first for fast baseline, then full run
     - Estimated runtime: ~30min without sign-in logs / ~3-4hrs with sign-in logs

 2.  #Requires statements (including #Requires -Version 7.2)

 3.  [CmdletBinding(SupportsShouldProcess)] param() block
     Includes -DryRunLimit parameter for testing subset of apps

 4.  Constants and lookup hashtables (ALL declared here, NONE inside loops):
        $BroadPermissions       (GUID → permission name, 13+ entries)
        $PrivilegedEntraRoles   (string array)
        $PrivilegedAzureRoles   (string array)
        $FederatedIssuerLabels  (issuer URL → label)
        $DateStamp              (reused in all filenames)
        $MicrosoftTenantId      ('f8cdef31-a31e-4b4a-93e4-5f571e91255a')
        $MicrosoftAppIds        (HashSet of known Microsoft 1st-party app IDs)

 5.  Helper functions (in this order):
        Write-Log
        Invoke-GraphWithRetry
        Get-ExternalSystemType
        Get-DeletionSafetyScore   (includes Microsoft app override, age factor, signInActivity)
        Get-AppUsageStatus
        Get-CleanupBucket         (includes IsMicrosoftApp param for auto Bucket 4)
        Get-AppWhereUsed
        Get-NearestExpiry
        Test-BroadPermissions

 6.  Main block: try {} finally { Disconnect-MgGraph; Disconnect-AzAccount }

 7.  Pre-flight validation (5 scope checks + Az module)

 8.  Phase 1: All 8 bulk loads with logging
        - Bulk Load 1: Apps with $expand=owners,federatedIdentityCredentials
        - Bulk Load 2: SPs with signInActivity, alternativeNames
        - Bulk Load 6: Role definitions loaded SEPARATELY from assignments
        - Null guard after each bulk load

 9.  Phase 2: Per-app loop with Write-Progress
        - All signals A through M
        - Signal A includes VerifiedPublisher, IsMicrosoftApp, AppAgeDays
        - Signal B includes SPLastSignInDate, SPLastDaemonSignInDate
        - Signals C & D use $expand cache (no per-app Graph calls)
        - Signal L includes AllSecretsExpired, AllCertsExpired
        - Call Get-AppUsageStatus
        - Call Get-DeletionSafetyScore (pass IsMicrosoftApp, AppAgeDays, SP sign-in dates)
        - Call Get-CleanupBucket (pass -IsMicrosoftApp)
        - Call Get-AppWhereUsed
        - Build $masterRecord PSCustomObject
        - Add to $MasterReport list

10.  Phase 3: Managed Identity sweep (separate loop over $MiCache)
        - Use AlternativeNames for MI type detection (not Tags)
        - Use $miRecord variable (not $miReport) to avoid list collision

11.  Phase 4: Export all CSVs
        - MasterAudit
        - 4 Bucket CSVs
        - Owner Notification CSVs (with $currentApp fix)
        - NoOwner Escalation CSV
        - Managed Identity CSV

12.  Phase 5: Console summary output
```

---

## Anti-Hallucination Guardrails

- **Do not invent `Get-Mg*` parameter names.** Only use `-Filter`, `-All`, `-Top`, `-OrderBy`, `-Property`, `-ExpandProperty` — universally supported.
- **Do not use `AzureAD` or `MSOnline` cmdlets under any circumstance.**
- **`Get-MgServicePrincipalAppRoleAssignedTo` (inbound) ≠ `Get-MgServicePrincipalAppRoleAssignment` (outbound).** Never merge their results. Never confuse which direction each captures.
- **`Get-MgApplicationFederatedIdentityCredential` takes `-ApplicationId` (ObjectId), NOT AppId.**
- **Sign-in log retention:** Audit logs are retained for 7-30 days depending on Entra ID license tier. Always prefer `signInActivity` on the Service Principal (ALL-TIME, no retention limit) over audit log queries. Document the retention caveat in `.NOTES` and as inline comments.
- **`signInActivity` property:** Available only via `Get-MgServicePrincipal` with `-Property signInActivity`. Returns `LastSignInDateTime` and `LastNonInteractiveSignInDateTime` — these are ALL-TIME values, not subject to audit log retention.
- **Managed Identities do NOT appear in `Get-MgApplication`.** They are detected ONLY from `$SpCache` where `ServicePrincipalType -eq 'ManagedIdentity'`. Never attempt `Get-MgApplication` to find them.
- **MI type detection:** Use `AlternativeNames` (check for `/subscriptions/` prefix), NOT `Tags`. Tags do not reliably distinguish system-assigned from user-assigned MIs.
- **`$null` comparisons: always `$null -eq $var`** — never `$var -eq $null`.
- **String comparisons: always `-eq`** — never `==`.
- **All cache hashtables declared BEFORE all loops.** Never declare or populate a cache inside a per-app loop.
- **The Deletion Safety Score is a composite RECOMMENDATION, not a command.** The script must print a comment in the `.NOTES` header stating that no automatic deletions occur — all actions require human review.
- **`Get-AzRoleAssignment` for RBAC bulk-load MUST use the subscription-loop pattern.** Calling it without a subscription context produces incomplete results.
- **Bucket 1 output means DISABLE, not DELETE.** The ProposedDeleteDate is Today+30. The script must never generate delete commands. Disable only.
- **`$expand` for owners and federated credentials:** Use `$expand=owners,federatedIdentityCredentials` on `Get-MgApplication -All` to avoid per-app Graph calls. This saves ~18,000 API calls for a 9,000-app tenant.
- **Microsoft 1st-party detection:** Use `$MicrosoftTenantId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'` and compare against `$sp.AppOwnerOrganizationId`. Also check known Microsoft AppIds. Never clean up Microsoft-owned apps.
- **`AllSecretsExpired` vs `HasExpiredSecret`:** `HasExpiredSecret` means "at least one secret is expired" (some may still be valid). `AllSecretsExpired` means "every secret has expired and none are valid." Only use `AllSecretsExpired` for the scoring bonus.
- **Owner notification variable capture:** In nested `ForEach-Object` blocks, capture outer `$_` as `$currentApp` before the inner `ForEach-Object` overwrites `$_`.
- **MI report variable naming:** Use `$miRecord` for individual MI objects in the foreach loop; `$MiReport` is the list that collects them. Never use the same name for both.
