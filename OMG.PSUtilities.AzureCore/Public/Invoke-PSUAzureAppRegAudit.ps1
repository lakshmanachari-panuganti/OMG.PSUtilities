<#
.SYNOPSIS
    Performs a comprehensive audit and cleanup assessment of all Azure App Registrations in a tenant.

.DESCRIPTION
    Collects 13 signals per app across 9,000+ App Registrations, calculates a
    Deletion Safety Score (0-100), assigns each app to one of four cleanup buckets,
    and produces actionable output files for the IT team.

    Architecture: Collect -> Score -> Bucket -> Output -> Act

    The four cleanup buckets are:
    - Bucket 1 (SafeToDisable)      : Score 80-100 - safe to disable now, delete in 30 days
    - Bucket 2 (NeedsInvestigation) : Score 50-79  - send to app owner for review
    - Bucket 3 (LikelyActive)       : Score 20-49  - do not touch, gather more evidence
    - Bucket 4 (BusinessCritical)   : Score 0-19   - never touch without change request

    The script uses:
    - Microsoft Graph PowerShell SDK v2+ for Entra ID data
    - Az.Resources module for Azure RBAC coverage
    - Bulk-load caching architecture for performance (O(1) hashtable lookups)
    - signInActivity property for ALL-TIME sign-in dates (no retention limit)

    No automatic deletions occur. All actions require human review.

.PARAMETER TenantId
    (Optional) The Entra ID tenant ID. If not supplied, reads from Get-MgContext.

.PARAMETER OutputDirectory
    (Optional) Path where output CSV files are written.
    Default is $PSScriptRoot.

.PARAMETER LogDirectory
    (Optional) Path where the audit log file is written.
    Default is $PSScriptRoot.

.PARAMETER SkipAzureRBAC
    (Optional) Skip Azure RBAC data collection. Use this if the Az.Resources module
    is not available or Azure subscription access is not granted.

.PARAMETER SkipSignInLogs
    (Optional) Skip per-app sign-in log queries. This makes the script much faster
    (30 min vs 3-4 hours) but reduces signal coverage. The signInActivity property
    on Service Principals still provides ALL-TIME sign-in dates.

.PARAMETER ThrottleDelayMs
    (Optional) Base delay in milliseconds between per-app Graph calls.
    Default is 200ms.

.PARAMETER DryRunLimit
    (Optional) If greater than 0, process only this many apps. Use for testing.
    Default is 0 (process all apps).

.PARAMETER VerboseMode
    (Optional) Enable verbose logging to the log file.

.EXAMPLE
    Invoke-PSUAzureAppRegAudit -OutputDirectory "C:\AuditOutput" -SkipSignInLogs

    Runs a fast audit (no per-app sign-in log queries) and saves output to C:\AuditOutput.

.EXAMPLE
    Invoke-PSUAzureAppRegAudit -DryRunLimit 50 -VerboseMode

    Processes only the first 50 apps with verbose logging enabled.

.EXAMPLE
    Invoke-PSUAzureAppRegAudit -TenantId "abc-123" -SkipAzureRBAC

    Runs a full audit without Azure RBAC data collection.

.OUTPUTS
    [System.Collections.Generic.List[PSCustomObject]]
    Returns the MasterReport list containing all app audit records.

    Output files:
    - MasterAudit_Full_<TenantId>_<Date>.csv
    - Bucket1_SafeToDisable_<TenantId>_<Date>.csv
    - Bucket2_NeedsInvestigation_<TenantId>_<Date>.csv
    - Bucket3_LikelyActive_<TenantId>_<Date>.csv
    - Bucket4_BusinessCritical_<TenantId>_<Date>.csv
    - ManagedIdentity_Audit_<TenantId>_<Date>.csv
    - OwnerNotifications\Owner_<UPN>_<Date>.csv (one per owner)
    - OwnerNotifications\NoOwner_Escalation_<Date>.csv
    - AuditLog_<TenantId>_<DateTime>.log

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 7th March 2026
    Last Modified: 7th March 2026
    Version: 1.0

    IMPORTANT:
    - Sign-in log retention: 7-30 days depending on Entra ID license tier.
      signInActivity on Service Principals provides ALL-TIME sign-in dates.
    - Managed Identity ARM resource link requires Azure Resource Graph (future enhancement).
    - Microsoft 1st-party apps are auto-excluded from cleanup buckets 1-3.
    - No automatic deletions occur. All actions require human review.
    - Estimated runtime: ~30min with -SkipSignInLogs / ~3-4hrs without.

    PREREQUISITES:
    - PowerShell 7.2+
    - Microsoft.Graph.Authentication 2.0.0+
    - Microsoft.Graph.Applications 2.0.0+
    - Microsoft.Graph.Reports 2.0.0+
    - Microsoft.Graph.Identity.Governance 2.0.0+
    - Microsoft.Graph.Identity.DirectoryManagement 2.0.0+
    - Az.Resources 6.0.0+ (unless -SkipAzureRBAC)

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureCore
#>
function Invoke-PSUAzureAppRegAudit {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [string]$OutputDirectory = $PSScriptRoot,

        [Parameter()]
        [string]$LogDirectory = $PSScriptRoot,

        [Parameter()]
        [switch]$SkipAzureRBAC,

        [Parameter()]
        [switch]$SkipSignInLogs,

        [Parameter()]
        [int]$ThrottleDelayMs = 200,

        [Parameter()]
        [int]$DryRunLimit = 0,

        [Parameter()]
        [switch]$VerboseMode
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Parameters:"
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            Write-Verbose "  $($param.Key) = $($param.Value)"
        }

        #region Constants and Lookup Hashtables
        $DateStamp = Get-Date -Format "yyyyMMdd"
        $script:LogFile = Join-Path $LogDirectory "AuditLog_PENDING_$( Get-Date -Format 'yyyyMMdd_HHmmss' ).log"
        $ScriptStartTime = Get-Date

        # Microsoft 1st-party tenant ID
        $MicrosoftTenantId = "f8cdef31-a31e-4b4a-93e4-5f571e91255a"

        # Broad Graph Permissions (GUID -> permission name)
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

        $graphResourceId = "00000003-0000-0000-c000-000000000000"

        $OwnerNotificationColumns = @(
            "AppName", "AppId", "DeletionSafetyScore", "BucketLabel", "RecommendedAction",
            "LastUsedDate", "UsageConfidence", "UsageLocationSummary", "DeletionBlastRadius",
            "HasExpiredSecret", "OldestSecretAgeDays", "AuthMethod", "CreatedDate"
        )
        #endregion

        #region Write-Log function
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
                "DEBUG" { if ($VerboseMode) { Write-Verbose $Message } }
                default { Write-Host $entry }
            }
        }
        #endregion

        # LogFunction scriptblock for passing to Invoke-PSUGraphWithRetry
        $LogFunc = {
            param($Level, $Signal, $Message)
            Write-Log -Level $Level -Signal $Signal -Message $Message
        }
    }

    process {
        try {
            #region Pre-flight Validation
            Write-Log "INFO" "PreFlight" "Starting pre-flight validation..."

            # Check 1: Graph context
            $mgContext = Get-MgContext
            if ($null -eq $mgContext) {
                throw "ERROR: No Graph context. Run Connect-MgGraph first."
            }

            # Check 2: Required scopes
            $requiredScopes = @(
                "Application.Read.All", "Directory.Read.All", "AuditLog.Read.All",
                "Policy.Read.All"
            )
            $currentScopes = $mgContext.Scopes
            $missingScopes = $requiredScopes | Where-Object { $_ -notin $currentScopes }
            if ($missingScopes.Count -gt 0) {
                throw "ERROR: Missing Graph scopes: $($missingScopes -join ', '). Re-run Connect-MgGraph with required scopes."
            }

            # Check 2b: Validate Graph token with a lightweight API call
            try {
                $null = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1
                Write-Log "INFO" "PreFlight" "Graph token validated (Get-MgOrganization succeeded)"
            } catch {
                throw "ERROR: Graph token is invalid or expired. Re-authenticate with: Connect-MgGraph -Scopes @('Application.Read.All','Directory.Read.All','AuditLog.Read.All','Policy.Read.All'). Inner error: $($_.Exception.Message)"
            }

            # Check 3: Azure context (if RBAC not skipped)
            if (-not $SkipAzureRBAC) {
                $azContext = Get-AzContext
                if ($null -eq $azContext) {
                    throw "ERROR: No Azure context. Run Connect-AzAccount or use -SkipAzureRBAC."
                }
            }

            # Check 4: Resolve TenantId
            if ([string]::IsNullOrWhiteSpace($TenantId)) {
                $TenantId = $mgContext.TenantId
            }

            # Update log filename with TenantId
            $newLogFile = Join-Path $LogDirectory "AuditLog_${TenantId}_$( Get-Date -Format 'yyyyMMdd_HHmmss' ).log"
            if (Test-Path $script:LogFile) {
                Rename-Item -Path $script:LogFile -NewName (Split-Path $newLogFile -Leaf) -ErrorAction SilentlyContinue
            }
            $script:LogFile = $newLogFile

            # Check 5: Cache Azure subscriptions
            $AzSubscriptions = @()
            if (-not $SkipAzureRBAC) {
                $AzSubscriptions = @(Get-AzSubscription -TenantId $TenantId)
                Write-Log "INFO" "PreFlight" "Cached $($AzSubscriptions.Count) Azure subscriptions"
            }

            # Create output directories
            $ownerNotifDir = Join-Path $OutputDirectory "OwnerNotifications"
            if (-not (Test-Path $OutputDirectory)) { New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null }
            if (-not (Test-Path $ownerNotifDir)) { New-Item -Path $ownerNotifDir   -ItemType Directory -Force | Out-Null }

            $authIdentity = $mgContext.Account ?? $mgContext.AppName ?? "Unknown"
            Write-Log "INFO" "PreFlight" "Authenticated: $authIdentity | Tenant: $TenantId | Subscriptions: $($AzSubscriptions.Count)"
            Write-Log "INFO" "PreFlight" "Pre-flight validation PASSED"
            #endregion

            #region Phase 1: Bulk Pre-Load

            # -- Bulk Load 1: All App Registrations (with owners + federated creds) --
            Write-Log "INFO" "Bulk" "Loading all App Registrations with owners and federated credentials..."
            $AllApps = Get-MgApplication -All `
                -ExpandProperty "owners,federatedIdentityCredentials" `
                -Property @(
                "id", "appId", "displayName", "createdDateTime",
                "signInAudience", "publisherDomain", "tags",
                "passwordCredentials", "keyCredentials", "requiredResourceAccess",
                "web", "spa", "publicClient",
                "api", "info", "notes",
                "verifiedPublisher"
            )

            if ($null -eq $AllApps -or $AllApps.Count -eq 0) {
                Write-Log "ERROR" "Bulk" "ZERO App Registrations returned. Check Application.Read.All scope."
                throw "Bulk load returned no applications. Verify permissions and try again."
            }

            $AppCache = @{}
            foreach ($app in $AllApps) { $AppCache[$app.AppId] = $app }
            Write-Log "INFO" "Bulk" "Loaded $($AllApps.Count) App Registrations (with owners + federated creds)"

            # -- Bulk Load 2: All Service Principals (with sign-in activity) --
            Write-Log "INFO" "Bulk" "Loading all Service Principals with signInActivity..."
            $AllSPs = Get-MgServicePrincipal -All -Property @(
                "id", "appId", "displayName", "accountEnabled",
                "appOwnerOrganizationId", "servicePrincipalType", "createdDateTime",
                "signInActivity", "tags", "homepage", "replyUrls",
                "alternativeNames"
            )

            if ($null -eq $AllSPs -or $AllSPs.Count -eq 0) {
                Write-Log "ERROR" "Bulk" "ZERO Service Principals returned. Check Directory.Read.All scope."
                throw "Bulk load returned no service principals. Verify permissions and try again."
            }

            $SpCache = @{}
            $MiCache = @{}
            $MicrosoftAppIds = [System.Collections.Generic.HashSet[string]]::new()

            foreach ($sp in $AllSPs) {
                $SpCache[$sp.AppId] = $sp
                if ($sp.ServicePrincipalType -eq "ManagedIdentity") {
                    $MiCache[$sp.Id] = $sp
                }
                if ($sp.AppOwnerOrganizationId -eq $MicrosoftTenantId) {
                    [void]$MicrosoftAppIds.Add($sp.AppId)
                }
            }
            Write-Log "INFO" "Bulk" "Loaded $($AllSPs.Count) Service Principals ($($MiCache.Count) MIs, $($MicrosoftAppIds.Count) Microsoft 1st-party)"

            # -- Bulk Load 3: All OAuth2 Permission Grants --
            Write-Log "INFO" "Bulk" "Loading OAuth2 Permission Grants..."
            $AllOAuthGrants = Get-MgOauth2PermissionGrant -All -Property @(
                "id", "clientId", "resourceId", "scope", "consentType", "principalId"
            )
            $OAuthGrantCache = @{}
            foreach ($grant in $AllOAuthGrants) {
                if (-not $OAuthGrantCache.ContainsKey($grant.ClientId)) {
                    $OAuthGrantCache[$grant.ClientId] = [System.Collections.Generic.List[object]]::new()
                }
                $OAuthGrantCache[$grant.ClientId].Add($grant)
            }
            Write-Log "INFO" "Bulk" "Loaded $(if ($AllOAuthGrants) { $AllOAuthGrants.Count } else { 0 }) OAuth2 Permission Grants"

            # -- Bulk Load 4: All App Role Assignments (Outbound) --
            Write-Log "INFO" "Bulk" "Loading outbound App Role Assignments (iterating SPs)..."
            $OutboundRoleCache = @{}
            $outboundTotal = 0

            foreach ($sp in $AllSPs) {
                if ($sp.ServicePrincipalType -eq "ManagedIdentity") { continue }
                if ($MicrosoftAppIds.Contains($sp.AppId)) { continue }

                $assignments = Invoke-PSUGraphWithRetry -OperationName "OutboundRoles-$($sp.Id)" -ScriptBlock {
                    Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -All
                } -LogFunction $LogFunc

                if ($null -ne $assignments -and $assignments.Count -gt 0) {
                    $OutboundRoleCache[$sp.Id] = [System.Collections.Generic.List[object]]::new()
                    foreach ($assignment in $assignments) {
                        $OutboundRoleCache[$sp.Id].Add($assignment)
                    }
                    $outboundTotal += $assignments.Count
                }

                if ($ThrottleDelayMs -gt 0) { Start-Sleep -Milliseconds $ThrottleDelayMs }
            }
            Write-Log "INFO" "Bulk" "Loaded $outboundTotal outbound App Role Assignments across $($OutboundRoleCache.Count) SPs"

            # -- Bulk Load 5: All Inbound App Role Assignments (Consumers) --
            Write-Log "INFO" "Bulk" "Loading inbound App Role Assignments (iterating SPs)..."
            $InboundRoleCache = @{}
            $inboundTotal = 0

            foreach ($sp in $AllSPs) {
                if ($sp.ServicePrincipalType -eq "ManagedIdentity") { continue }
                if ($MicrosoftAppIds.Contains($sp.AppId)) { continue }

                $assignments = Invoke-PSUGraphWithRetry -OperationName "InboundRoles-$($sp.Id)" -ScriptBlock {
                    Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $sp.Id -All
                } -LogFunction $LogFunc

                if ($null -ne $assignments -and $assignments.Count -gt 0) {
                    $InboundRoleCache[$sp.Id] = [System.Collections.Generic.List[object]]::new()
                    foreach ($assignment in $assignments) {
                        $InboundRoleCache[$sp.Id].Add($assignment)
                    }
                    $inboundTotal += $assignments.Count
                }

                if ($ThrottleDelayMs -gt 0) { Start-Sleep -Milliseconds $ThrottleDelayMs }
            }
            Write-Log "INFO" "Bulk" "Loaded $inboundTotal inbound App Role Assignments across $($InboundRoleCache.Count) SPs"

            # -- Bulk Load 6: All Directory Role Assignments --
            Write-Log "INFO" "Bulk" "Loading Directory Role Definitions..."
            $AllRoleDefinitions = Get-MgRoleManagementDirectoryRoleDefinition -All -Property @(
                "id", "displayName", "isBuiltIn"
            )
            $RoleDefCache = @{}
            foreach ($rd in $AllRoleDefinitions) { $RoleDefCache[$rd.Id] = $rd }
            Write-Log "INFO" "Bulk" "Loaded $($AllRoleDefinitions.Count) Directory Role Definitions"

            Write-Log "INFO" "Bulk" "Loading Directory Role Assignments..."
            $AllDirRoleAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All `
                -Property "id,principalId,roleDefinitionId,directoryScopeId"

            $DirRoleCache = @{}
            foreach ($ra in $AllDirRoleAssignments) {
                $ra | Add-Member -NotePropertyName "RoleDefinition" -NotePropertyValue $RoleDefCache[$ra.RoleDefinitionId] -Force
                if (-not $DirRoleCache.ContainsKey($ra.PrincipalId)) {
                    $DirRoleCache[$ra.PrincipalId] = [System.Collections.Generic.List[object]]::new()
                }
                $DirRoleCache[$ra.PrincipalId].Add($ra)
            }
            Write-Log "INFO" "Bulk" "Loaded $($AllDirRoleAssignments.Count) Directory Role Assignments"

            # -- Bulk Load 7: Azure RBAC Assignments --
            $AzureRbacCache = @{}
            if (-not $SkipAzureRBAC) {
                Write-Log "INFO" "Bulk" "Loading Azure RBAC Assignments across $($AzSubscriptions.Count) subscriptions..."
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
                        Write-Log "WARN" "AzureRBAC" "Could not load RBAC from sub $($sub.Id): $($_.Exception.Message)"
                    }
                }
                Write-Log "INFO" "Bulk" "Loaded Azure RBAC assignments across $($AzSubscriptions.Count) subscriptions"
            }

            # -- Bulk Load 8: Conditional Access Policies --
            Write-Log "INFO" "Bulk" "Loading Conditional Access Policies..."
            $AllCAPolicies = Get-MgIdentityConditionalAccessPolicy -All -Property @(
                "id", "displayName", "state", "conditions"
            )
            $CaProtectedAppIds = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($policy in $AllCAPolicies) {
                if ($policy.State -in @("enabled", "Enabled", "enabledForReportingButNotEnforced")) {
                    foreach ($appId in $policy.Conditions.Applications.IncludeApplications) {
                        [void]$CaProtectedAppIds.Add($appId)
                    }
                }
            }
            Write-Log "INFO" "Bulk" "Loaded $($AllCAPolicies.Count) CA policies. Protected apps: $($CaProtectedAppIds.Count)"

            #endregion

            #region Phase 2: Per-App Signal Collection

            $MasterReport = [System.Collections.Generic.List[object]]::new()
            $appsToProcess = if ($DryRunLimit -gt 0) { $AllApps | Select-Object -First $DryRunLimit } else { $AllApps }
            $totalApps = @($appsToProcess).Count
            $currentApp = 0

            if (-not $SkipSignInLogs -and $totalApps -gt 100) {
                Write-Log "WARN" "SignIn" "Processing $totalApps apps WITH sign-in log queries. Estimated time: 2-4 hours."
            }

            foreach ($app in $appsToProcess) {
                $currentApp++
                Write-Progress -Activity "Auditing App Registrations" -Status "$currentApp / $totalApps - $($app.DisplayName)" -PercentComplete (($currentApp / $totalApps) * 100)

                #region Signal A: App Registration Base Properties
                $ObjectId = $app.Id
                $AppId = $app.AppId
                $DisplayName = $app.DisplayName
                $CreatedDateTime = $app.CreatedDateTime
                $SignInAudience = $app.SignInAudience
                $PublisherDomain = $app.PublisherDomain
                $Tags = ($app.Tags -join ";")

                $VerifiedPublisher = $app.VerifiedPublisher.DisplayName ?? "NotVerified"
                $IsVerifiedPublisher = ($null -ne $app.VerifiedPublisher -and
                    -not [string]::IsNullOrWhiteSpace($app.VerifiedPublisher.DisplayName))
                $IsMicrosoftApp = $MicrosoftAppIds.Contains($AppId)
                $AppAgeDays = [int]((Get-Date) - $CreatedDateTime).TotalDays

                $WebRedirectUris = ($app.Web.RedirectUris -join ";")
                $SpaRedirectUris = ($app.Spa.RedirectUris -join ";")
                $PublicClientUris = ($app.PublicClient.RedirectUris -join ";")
                $AllRedirectUris = @($app.Web.RedirectUris + $app.Spa.RedirectUris + $app.PublicClient.RedirectUris) | Where-Object { $_ }
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
                #endregion

                #region Signal B: Service Principal + ALL-TIME Sign-in Activity
                $sp = $SpCache[$AppId]

                if ($null -eq $sp) {
                    $ServicePrincipalId = "NoSP"
                    $IsEnabled = "N/A"
                    $NoServicePrincipal = $true
                    $ServicePrincipalType = "N/A"
                    $SPLastSignInDate = $null
                    $SPLastDaemonSignInDate = $null
                } else {
                    $ServicePrincipalId = $sp.Id
                    $IsEnabled = $sp.AccountEnabled
                    $NoServicePrincipal = $false
                    $ServicePrincipalType = $sp.ServicePrincipalType
                    $SPLastSignInDate = $sp.SignInActivity.LastSignInDateTime
                    $SPLastDaemonSignInDate = $sp.SignInActivity.LastNonInteractiveSignInDateTime
                }
                #endregion

                #region Signal C: Owners (from $expand cache)
                $owners = $app.Owners
                $OwnerUPNs = if ($owners.Count -gt 0) {
                    ($owners | ForEach-Object { $_.AdditionalProperties.userPrincipalName ?? $_.AdditionalProperties.displayName ?? $_.Id }) -join ";"
                } else { "NoOwner" }
                $OwnerCount = $owners.Count
                $HasOwner = $owners.Count -gt 0
                #endregion

                #region Signal D: Federated Identity Credentials (from $expand cache)
                $fedCreds = $app.FederatedIdentityCredentials
                $FederatedCredentialCount = if ($null -ne $fedCreds) { $fedCreds.Count } else { 0 }
                $FederatedCredentials = if ($FederatedCredentialCount -gt 0) { ($fedCreds | ForEach-Object { $_.Name }) -join ";" } else { "None" }
                $FederatedIssuers = if ($FederatedCredentialCount -gt 0) { ($fedCreds | ForEach-Object { $_.Issuer }) -join ";" } else { "None" }
                $FederatedSubjects = if ($FederatedCredentialCount -gt 0) { ($fedCreds | ForEach-Object { $_.Subject }) -join ";" } else { "None" }
                $UsedByExternalSystem = $FederatedCredentialCount -gt 0
                $ExternalSystemType = Get-PSUExternalSystemType -Issuers $fedCreds.Issuer
                #endregion

                #region Signal E: Interactive Sign-in Logs (Optional)
                $LastInteractiveSignInDate = $null
                $LastSignInResourceName = "NoData"
                $LastSignInUserUPN = "NoData"
                $LastSignInIPAddress = "NoData"
                $LastSignInLocation = "NoData"
                $LastSignInClientApp = "NoData"
                $LegacyAuthDetected = $false
                $IsCoveredByCAPolicy = $CaProtectedAppIds.Contains($AppId)

                if (-not $SkipSignInLogs -and -not $NoServicePrincipal) {
                    $siDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
                    $signIn = Invoke-PSUGraphWithRetry -OperationName "InteractiveSignIn-$AppId" -ScriptBlock {
                        Get-MgAuditLogSignIn `
                            -Filter "appId eq '$AppId' and createdDateTime ge $siDate" `
                            -Top 1 -OrderBy "createdDateTime desc" `
                            -Property @(
                            "createdDateTime", "resourceDisplayName", "resourceId",
                            "userPrincipalName", "ipAddress", "location",
                            "clientAppUsed", "conditionalAccessStatus", "status"
                        )
                    } -LogFunction $LogFunc

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
                #endregion

                #region Signal F: SP/Daemon Sign-in Logs (Optional)
                $LastSPSignInDate = $null
                $LastSPSignInResourceName = "NoData"
                $DaemonUsageDetected = $false

                if (-not $SkipSignInLogs -and -not $NoServicePrincipal) {
                    $spSiDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
                    $spSignIn = Invoke-PSUGraphWithRetry -OperationName "SPSignIn-$AppId" -ScriptBlock {
                        Get-MgAuditLogSignIn `
                            -Filter "appId eq '$AppId' and signInEventTypes/any(t: t eq 'servicePrincipal') and createdDateTime ge $spSiDate" `
                            -Top 1 -OrderBy "createdDateTime desc" `
                            -Property @("createdDateTime", "resourceDisplayName", "ipAddress", "status")
                    } -LogFunction $LogFunc

                    if ($null -ne $spSignIn) {
                        $LastSPSignInDate = $spSignIn.CreatedDateTime
                        $LastSPSignInResourceName = $spSignIn.ResourceDisplayName ?? "NoData"
                        $DaemonUsageDetected = $true
                    }

                    if ($ThrottleDelayMs -gt 0) { Start-Sleep -Milliseconds $ThrottleDelayMs }
                }
                #endregion

                #region Signal G: Outbound App Role Assignments
                $outbound = if ($ServicePrincipalId -ne "NoSP") { $OutboundRoleCache[$ServicePrincipalId] } else { $null }
                $AppRoleAssignmentCount = if ($outbound) { $outbound.Count } else { 0 }
                $AppRoleAssignedResources = if ($outbound) { ($outbound | ForEach-Object { $_.ResourceDisplayName } | Select-Object -Unique) -join ";" } else { "None" }
                #endregion

                #region Signal H: Inbound Consumers
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
                #endregion

                #region Signal I: OAuth2 Permission Grants
                $grants = if ($ServicePrincipalId -ne "NoSP") { $OAuthGrantCache[$ServicePrincipalId] } else { $null }
                $OAuthGrantCount = if ($grants) { $grants.Count } else { 0 }
                $OAuthGrantScopes = if ($grants) { ($grants | ForEach-Object { $_.Scope }) -join ";" } else { "None" }
                $AdminConsentGranted = ($grants | Where-Object { $_.ConsentType -eq "AllPrincipals" }).Count -gt 0
                #endregion

                #region Signal J: Directory Role Assignments
                $dirRoles = if ($ServicePrincipalId -ne "NoSP") { $DirRoleCache[$ServicePrincipalId] } else { $null }
                $DirectoryRoles = if ($dirRoles) { ($dirRoles | ForEach-Object { $_.RoleDefinition.DisplayName }) -join ";" } else { "None" }
                $DirectoryRoleCount = if ($dirRoles) { $dirRoles.Count } else { 0 }
                $HasPrivilegedEntraRole = ($dirRoles | Where-Object {
                        $_.RoleDefinition.DisplayName -in $PrivilegedEntraRoles
                    }).Count -gt 0
                #endregion

                #region Signal K: Azure RBAC
                $rbac = if ($ServicePrincipalId -ne "NoSP") { $AzureRbacCache[$ServicePrincipalId] } else { $null }
                $AzureRBACRoleCount = if ($rbac) { $rbac.Count } else { 0 }
                $AzureRBACRoles = if ($rbac) { ($rbac | ForEach-Object { $_.RoleDefinitionName } | Select-Object -Unique) -join ";" } else { "None" }
                $AzureRBACScopes = if ($rbac) { ($rbac | ForEach-Object { $_.Scope } | Select-Object -Unique) -join ";" } else { "None" }
                $HasAzureRBACRoles = $AzureRBACRoleCount -gt 0
                $HasPrivilegedAzureRole = ($rbac | Where-Object { $_.RoleDefinitionName -in $PrivilegedAzureRoles }).Count -gt 0
                #endregion

                #region Signal L: Credential Health + Secret Age
                $now = Get-Date

                $secrets = $app.PasswordCredentials
                $SecretCount = $secrets.Count
                $HasExpiredSecret = ($secrets | Where-Object { $_.EndDateTime -lt $now }).Count -gt 0
                $NearestSecretExpiry = if ($SecretCount -gt 0) { ($secrets | Sort-Object EndDateTime | Select-Object -First 1).EndDateTime } else { "NoSecret" }
                $OldestSecretAgeDays = if ($SecretCount -gt 0) {
                    $oldest = ($secrets | Sort-Object StartDateTime | Select-Object -First 1).StartDateTime
                    if ($null -ne $oldest) { [int]($now - $oldest).TotalDays } else { -1 }
                } else { -1 }

                $AllSecretsExpired = ($SecretCount -gt 0 -and
                    ($secrets | Where-Object { $_.EndDateTime -ge $now }).Count -eq 0)

                $certs = $app.KeyCredentials
                $CertCount = $certs.Count
                $HasExpiredCert = ($certs | Where-Object { $_.EndDateTime -lt $now }).Count -gt 0
                $NearestCertExpiry = if ($CertCount -gt 0) { ($certs | Sort-Object EndDateTime | Select-Object -First 1).EndDateTime } else { "NoCert" }
                $AllCertsExpired = ($CertCount -gt 0 -and
                    ($certs | Where-Object { $_.EndDateTime -ge $now }).Count -eq 0)

                $UsesPasswordlessAuth = ($FederatedCredentialCount -gt 0 -or $CertCount -gt 0 -or
                    $ServicePrincipalType -eq "ManagedIdentity")
                $AuthMethod = if ($ServicePrincipalType -eq "ManagedIdentity") { "ManagedIdentity" }
                elseif ($FederatedCredentialCount -gt 0) { "FederatedCredential" }
                elseif ($CertCount -gt 0 -and $SecretCount -eq 0) { "CertificateOnly" }
                elseif ($SecretCount -gt 0) { "ClientSecret" }
                else { "NoCredential" }
                #endregion

                #region Signal M: Broad Permission Detection
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
                #endregion

                #region Scoring, Classification, Bucketing
                $signalHash = @{
                    IsMicrosoftApp            = $IsMicrosoftApp
                    ConsumedByAppsCount       = $ConsumedByAppsCount
                    HasPrivilegedEntraRole    = $HasPrivilegedEntraRole
                    HasPrivilegedAzureRole    = $HasPrivilegedAzureRole
                    AssignedUsersCount        = $AssignedUsersCount
                    SPLastSignInDate          = $SPLastSignInDate
                    SPLastDaemonSignInDate    = $SPLastDaemonSignInDate
                    LastInteractiveSignInDate = $LastInteractiveSignInDate
                    DaemonUsageDetected       = $DaemonUsageDetected
                    UsedByExternalSystem      = $UsedByExternalSystem
                    ExternalSystemType        = $ExternalSystemType
                    HasAzureRBACRoles         = $HasAzureRBACRoles
                    AzureRBACRoleCount        = $AzureRBACRoleCount
                    AssignedGroupsCount       = $AssignedGroupsCount
                    AdminConsentGranted       = $AdminConsentGranted
                    AppRoleAssignmentCount    = $AppRoleAssignmentCount
                    OAuthGrantCount           = $OAuthGrantCount
                    IsApiProvider             = $IsApiProvider
                    ExposedScopeCount         = $ExposedScopeCount
                    DirectoryRoleCount        = $DirectoryRoleCount
                    HasExpiredSecret          = $HasExpiredSecret
                    SecretCount               = $SecretCount
                    HasExpiredCert            = $HasExpiredCert
                    CertCount                 = $CertCount
                    IsCoveredByCAPolicy       = $IsCoveredByCAPolicy
                    NoServicePrincipal        = $NoServicePrincipal
                    AllSecretsExpired         = $AllSecretsExpired
                    AppAgeDays                = $AppAgeDays
                    IsVerifiedPublisher       = $IsVerifiedPublisher
                    FederatedCredentialCount  = $FederatedCredentialCount
                    LastSPSignInDate          = $LastSPSignInDate
                    AppRoleAssignedResources  = $AppRoleAssignedResources
                    ConsumedByApps            = $ConsumedByApps
                    AzureRBACScopes           = $AzureRBACScopes
                    AssignedGroupNames        = $AssignedGroupNames
                    ExposedPermissions        = $ExposedPermissions
                    LastSignInResourceName    = $LastSignInResourceName
                    LastSPSignInResourceName  = $LastSPSignInResourceName
                }

                $scoreResult = Get-PSUDeletionSafetyScore -Signals $signalHash
                $usageResult = Get-PSUAppUsageStatus -Signals $signalHash
                $bucketResult = Get-PSUCleanupBucket -Score $scoreResult.Score `
                    -IsUnused $usageResult.IsUnused `
                    -UsageConfidence $usageResult.UsageConfidence `
                    -IsMicrosoftApp $IsMicrosoftApp
                $whereUsed = Get-PSUAppWhereUsed -Signals $signalHash

                $DaysSinceInteractiveSignIn = if ($LastInteractiveSignInDate -is [datetime]) {
                    [int]((Get-Date) - $LastInteractiveSignInDate).TotalDays
                } else { -1 }
                $DaysSinceSPSignIn = if ($LastSPSignInDate -is [datetime]) {
                    [int]((Get-Date) - $LastSPSignInDate).TotalDays
                } else { -1 }
                #endregion

                #region Build Master Record
                $masterRecord = [PSCustomObject]@{
                    # Identity & Classification
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
                    PublisherDomain            = $PublisherDomain
                    IsMicrosoftApp             = $IsMicrosoftApp
                    AppAgeDays                 = $AppAgeDays

                    # Ownership
                    OwnerUPNs                  = $OwnerUPNs
                    OwnerCount                 = $OwnerCount
                    HasOwner                   = $HasOwner

                    # Usage Classification
                    IsUnused                   = $usageResult.IsUnused
                    UnusedMoreThan1Year        = $usageResult.UnusedMoreThan1Year
                    UsageConfidence            = $usageResult.UsageConfidence
                    LastUsedDate               = $usageResult.LastUsedDate
                    DaysSinceLastUse           = $usageResult.DaysSinceLastUse
                    UsageLocationSummary       = $whereUsed

                    # Interactive Sign-in
                    LastInteractiveSignInDate  = if ($null -ne $LastInteractiveSignInDate) { $LastInteractiveSignInDate } else { "NoData" }
                    DaysSinceInteractiveSignIn = $DaysSinceInteractiveSignIn
                    LastSignInResourceName     = $LastSignInResourceName
                    LastSignInUserUPN          = $LastSignInUserUPN
                    LastSignInIPAddress        = $LastSignInIPAddress
                    LastSignInLocation         = $LastSignInLocation
                    LastSignInClientApp        = $LastSignInClientApp
                    LegacyAuthDetected         = $LegacyAuthDetected
                    IsCoveredByCAPolicy        = $IsCoveredByCAPolicy

                    # SP Sign-in Activity
                    SPLastSignInDate           = if ($null -ne $SPLastSignInDate) { $SPLastSignInDate } else { "NoData" }
                    SPLastDaemonSignInDate     = if ($null -ne $SPLastDaemonSignInDate) { $SPLastDaemonSignInDate } else { "NoData" }

                    # SP/Daemon Sign-in
                    LastSPSignInDate           = if ($null -ne $LastSPSignInDate) { $LastSPSignInDate } else { "NoData" }
                    DaysSinceSPSignIn          = $DaysSinceSPSignIn
                    LastSPSignInResourceName   = $LastSPSignInResourceName
                    DaemonUsageDetected        = $DaemonUsageDetected

                    # Inbound Consumers
                    DeletionBlastRadius        = $DeletionBlastRadius
                    ConsumedByAppsCount        = $ConsumedByAppsCount
                    ConsumedByApps             = $ConsumedByApps
                    AssignedUsersCount         = $AssignedUsersCount
                    AssignedGroupsCount        = $AssignedGroupsCount
                    AssignedGroupNames         = $AssignedGroupNames
                    IsActingAsResourceApp      = $IsActingAsResourceApp

                    # Outbound API Usage
                    AppRoleAssignmentCount     = $AppRoleAssignmentCount
                    AppRoleAssignedResources   = $AppRoleAssignedResources

                    # Delegated Permissions
                    OAuthGrantCount            = $OAuthGrantCount
                    OAuthGrantScopes           = $OAuthGrantScopes
                    AdminConsentGranted        = $AdminConsentGranted

                    # Directory Roles
                    DirectoryRoles             = $DirectoryRoles
                    DirectoryRoleCount         = $DirectoryRoleCount
                    HasPrivilegedEntraRole     = $HasPrivilegedEntraRole

                    # Azure RBAC
                    AzureRBACRoleCount         = $AzureRBACRoleCount
                    AzureRBACRoles             = $AzureRBACRoles
                    AzureRBACScopes            = $AzureRBACScopes
                    HasAzureRBACRoles          = $HasAzureRBACRoles
                    HasPrivilegedAzureRole     = $HasPrivilegedAzureRole

                    # Federated Credentials
                    FederatedCredentialCount   = $FederatedCredentialCount
                    FederatedCredentials       = $FederatedCredentials
                    FederatedIssuers           = $FederatedIssuers
                    FederatedSubjects          = $FederatedSubjects
                    UsedByExternalSystem       = $UsedByExternalSystem
                    ExternalSystemType         = $ExternalSystemType

                    # Credential Health
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

                    # Application Architecture
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
                    PublicClientUris           = $PublicClientUris
                    HasLocalhostUri            = $HasLocalhostUri
                    HasHttpUri                 = $HasHttpUri
                    HasNgrokUri                = $HasNgrokUri
                }

                $MasterReport.Add($masterRecord)
                Write-Log "DEBUG" "App" "[$currentApp/$totalApps] $AppId | Score=$($scoreResult.Score) | $($bucketResult.Label)"
                #endregion
            }

            Write-Progress -Activity "Auditing App Registrations" -Completed
            Write-Log "INFO" "Phase2" "Completed per-app signal collection for $totalApps apps"

            #endregion

            #region Phase 3: Managed Identity Sweep

            Write-Log "INFO" "MI" "Starting Managed Identity governance sweep ($($MiCache.Count) MIs)..."
            $MiReport = [System.Collections.Generic.List[object]]::new()

            foreach ($mi in $MiCache.Values) {
                $miRbac = $AzureRbacCache[$mi.Id]
                $miDirRole = $DirRoleCache[$mi.Id]

                $miRBACRoles = if ($miRbac) { ($miRbac | ForEach-Object { $_.RoleDefinitionName }) -join ";" } else { "None" }
                $miDirRoles = if ($miDirRole) { ($miDirRole | ForEach-Object { $_.RoleDefinition.DisplayName }) -join ";" } else { "None" }

                # Determine MI type from AlternativeNames
                $altNames = $mi.AlternativeNames
                $isSystemAssigned = ($altNames | Where-Object { $_ -like '/subscriptions/*' }).Count -gt 0
                $miType = if ($isSystemAssigned) { "SystemAssigned" } else { "UserAssigned" }

                $LinkedResource = if ($isSystemAssigned) {
                    ($altNames | Where-Object { $_ -like '/subscriptions/*' }) | Select-Object -First 1
                } else {
                    $mi.DisplayName
                }

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
                    HasPrivilegedAzureRole = ($miRbac | Where-Object { $_.RoleDefinitionName -in $PrivilegedAzureRoles }).Count -gt 0
                    DirectoryRoles         = $miDirRoles
                    HasPrivilegedEntraRole = ($miDirRole | Where-Object { $_.RoleDefinition.DisplayName -in $PrivilegedEntraRoles }).Count -gt 0
                    PossiblyOrphaned       = ($miRbac.Count -eq 0 -and $miDirRole.Count -eq 0)
                }
                $MiReport.Add($miRecord)
            }
            Write-Log "INFO" "MI" "Completed MI sweep: $($MiReport.Count) Managed Identities processed"

            #endregion

            #region Phase 4: Export CSVs

            Write-Log "INFO" "Export" "Exporting output files..."

            # Master Audit CSV
            $masterPath = Join-Path $OutputDirectory "MasterAudit_Full_${TenantId}_${DateStamp}.csv"
            $MasterReport | Export-Csv -Path $masterPath -NoTypeInformation -Encoding UTF8
            Write-Log "INFO" "Export" "Master Audit: $masterPath"

            # Bucket CSVs
            for ($b = 1; $b -le 4; $b++) {
                $bucketLabels = @{ 1 = "Bucket1_SafeToDisable"; 2 = "Bucket2_NeedsInvestigation"; 3 = "Bucket3_LikelyActive"; 4 = "Bucket4_BusinessCritical" }
                $bucketApps = $MasterReport | Where-Object { $_.CleanupBucket -eq $b }
                $bucketPath = Join-Path $OutputDirectory "$($bucketLabels[$b])_${TenantId}_${DateStamp}.csv"

                if ($b -eq 1) {
                    # Add Bucket 1 extra columns
                    $bucketApps | Select-Object *, @{N = 'ProposedDisableDate'; E = { Get-Date -Format 'yyyy-MM-dd' } },
                    @{N = 'ProposedDeleteDate'; E = { (Get-Date).AddDays(30).ToString('yyyy-MM-dd') } },
                    @{N = 'DisabledConfirmed'; E = { '' } },
                    @{N = 'OwnerNotified'; E = { '' } } |
                        Export-Csv -Path $bucketPath -NoTypeInformation -Encoding UTF8
                } else {
                    $bucketApps | Export-Csv -Path $bucketPath -NoTypeInformation -Encoding UTF8
                }
                Write-Log "INFO" "Export" "$($bucketLabels[$b]): $(@($bucketApps).Count) apps -> $bucketPath"
            }

            # Managed Identity CSV
            $miPath = Join-Path $OutputDirectory "ManagedIdentity_Audit_${TenantId}_${DateStamp}.csv"
            $MiReport | Export-Csv -Path $miPath -NoTypeInformation -Encoding UTF8
            Write-Log "INFO" "Export" "Managed Identity: $($MiReport.Count) MIs -> $miPath"

            # Owner Notification CSVs
            $byOwner = $MasterReport | Where-Object { $_.OwnerUPNs -ne "NoOwner" } |
                ForEach-Object {
                    $currentAppRecord = $_
                    $currentAppRecord.OwnerUPNs -split ";" | ForEach-Object {
                        @{ Owner = $_; App = $currentAppRecord }
                    }
                } | Group-Object -Property Owner

            foreach ($ownerGroup in $byOwner) {
                $safeOwnerFileName = $ownerGroup.Name -replace '[\\/:*?"<>|@]', '_'
                $ownerApps = $ownerGroup.Group | Select-Object -ExpandProperty App
                $ownerPath = Join-Path $ownerNotifDir "Owner_${safeOwnerFileName}_${DateStamp}.csv"
                $ownerApps | Select-Object $OwnerNotificationColumns |
                    Export-Csv -Path $ownerPath -NoTypeInformation -Encoding UTF8
            }
            Write-Log "INFO" "Export" "Owner Notifications: $(@($byOwner).Count) owner files -> $ownerNotifDir"

            # NoOwner Escalation
            $noOwnerApps = $MasterReport | Where-Object { $_.OwnerUPNs -eq "NoOwner" -and $_.CleanupBucket -le 2 }
            $escalationPath = Join-Path $ownerNotifDir "NoOwner_Escalation_${DateStamp}.csv"
            $noOwnerApps | Select-Object $OwnerNotificationColumns |
                Export-Csv -Path $escalationPath -NoTypeInformation -Encoding UTF8
            Write-Log "INFO" "Export" "NoOwner Escalation: $(@($noOwnerApps).Count) apps -> $escalationPath"

            #endregion

            #region Phase 5: Console Summary

            $duration = (Get-Date) - $ScriptStartTime
            $durationStr = "$([int]$duration.TotalMinutes) min $($duration.Seconds) sec"

            $bucket1Count = @($MasterReport | Where-Object { $_.CleanupBucket -eq 1 }).Count
            $bucket2Count = @($MasterReport | Where-Object { $_.CleanupBucket -eq 2 }).Count
            $bucket3Count = @($MasterReport | Where-Object { $_.CleanupBucket -eq 3 }).Count
            $bucket4Count = @($MasterReport | Where-Object { $_.CleanupBucket -eq 4 }).Count

            $withOwners = @($MasterReport | Where-Object { $_.HasOwner }).Count
            $withoutOwners = @($MasterReport | Where-Object { -not $_.HasOwner }).Count

            $highConf = @($MasterReport | Where-Object { $_.UsageConfidence -eq "High" }).Count
            $medConf = @($MasterReport | Where-Object { $_.UsageConfidence -eq "Medium" }).Count
            $lowConf = @($MasterReport | Where-Object { $_.UsageConfidence -eq "Low" }).Count

            $withInteractive = @($MasterReport | Where-Object { $_.LastInteractiveSignInDate -ne "NoData" }).Count
            $withDaemon = @($MasterReport | Where-Object { $_.DaemonUsageDetected }).Count
            $withRBAC = @($MasterReport | Where-Object { $_.HasAzureRBACRoles }).Count
            $withExternalCI = @($MasterReport | Where-Object { $_.UsedByExternalSystem }).Count
            $withConsumers = @($MasterReport | Where-Object { $_.ConsumedByAppsCount -gt 0 }).Count

            $privEntra = @($MasterReport | Where-Object { $_.HasPrivilegedEntraRole }).Count
            $privAzure = @($MasterReport | Where-Object { $_.HasPrivilegedAzureRole }).Count
            $broadPerms = @($MasterReport | Where-Object { $_.HasBroadGraphPermissions }).Count
            $expiredSecrets = @($MasterReport | Where-Object { $_.HasExpiredSecret }).Count
            $oldSecrets = @($MasterReport | Where-Object { $_.OldestSecretAgeDays -gt 365 }).Count
            $legacyAuth = @($MasterReport | Where-Object { $_.LegacyAuthDetected }).Count
            $publicBroad = @($MasterReport | Where-Object { $_.IsPublicClient -and $_.HasBroadGraphPermissions }).Count

            Write-Host ""
            Write-Host ([string]::new([char]0x2550, 66)) -ForegroundColor Cyan
            Write-Host "      Azure App Registration Cleanup System - v5 Summary" -ForegroundColor Cyan
            Write-Host ([string]::new([char]0x2550, 66)) -ForegroundColor Cyan
            Write-Host "  Tenant ID                    : $TenantId"
            Write-Host "  Run Date                     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Write-Host "  Duration                     : $durationStr"
            Write-Host "  Subscriptions Scanned        : $($AzSubscriptions.Count)"
            Write-Host ([string]::new([char]0x2500, 66)) -ForegroundColor DarkGray
            Write-Host "  INVENTORY" -ForegroundColor White
            Write-Host "  Total App Registrations      : $($MasterReport.Count)"
            Write-Host "  Managed Identities (separate): $($MiReport.Count)"
            Write-Host ([string]::new([char]0x2500, 66)) -ForegroundColor DarkGray
            Write-Host "  CLEANUP PIPELINE RESULTS" -ForegroundColor White
            Write-Host "  Bucket 1 - Safe to Disable   : $bucket1Count  (Score 80-100)" -ForegroundColor Red
            Write-Host "  Bucket 2 - Needs Investigation: $bucket2Count  (Score 50-79)" -ForegroundColor Yellow
            Write-Host "  Bucket 3 - Likely Active      : $bucket3Count  (Score 20-49)" -ForegroundColor DarkYellow
            Write-Host "  Bucket 4 - Business Critical  : $bucket4Count  (Score 0-19)" -ForegroundColor Green
            Write-Host ([string]::new([char]0x2500, 66)) -ForegroundColor DarkGray
            Write-Host "  OWNERSHIP" -ForegroundColor White
            Write-Host "  Apps With Owners             : $withOwners"
            Write-Host "  Apps Without Owners          : $withoutOwners"
            Write-Host "  Owner Notification Files     : $(@($byOwner).Count)"
            Write-Host "  Ownerless Escalation Apps    : $(@($noOwnerApps).Count)"
            Write-Host ([string]::new([char]0x2500, 66)) -ForegroundColor DarkGray
            Write-Host "  USAGE SIGNAL COVERAGE" -ForegroundColor White
            Write-Host "  Confirmed Active (High)      : $highConf"
            Write-Host "  Likely Active (Medium)       : $medConf"
            Write-Host "  No Signal Found (Low)        : $lowConf"
            Write-Host "  Apps w/ Interactive Sign-in   : $withInteractive"
            Write-Host "  Apps w/ Daemon Sign-in        : $withDaemon"
            Write-Host "  Apps w/ Azure RBAC Roles      : $withRBAC"
            Write-Host "  Apps Used by External CI/CD   : $withExternalCI"
            Write-Host "  Apps Consumed by Other Apps   : $withConsumers"
            Write-Host ([string]::new([char]0x2500, 66)) -ForegroundColor DarkGray
            Write-Host "  RISK FLAGS" -ForegroundColor White
            Write-Host "  Apps w/ Privileged Entra Role : $privEntra"
            Write-Host "  Apps w/ Privileged Azure Role : $privAzure"
            Write-Host "  Apps w/ Broad Graph Perms     : $broadPerms"
            Write-Host "  Apps w/ Expired Secrets       : $expiredSecrets"
            Write-Host "  Apps w/ Secrets > 1yr Old     : $oldSecrets"
            Write-Host "  Apps w/ Legacy Auth           : $legacyAuth"
            Write-Host "  Public Clients w/ Broad Perms : $publicBroad"
            Write-Host ([string]::new([char]0x2500, 66)) -ForegroundColor DarkGray
            Write-Host "  OUTPUT FILES" -ForegroundColor White
            Write-Host "  Master Audit     : $masterPath"
            Write-Host "  Managed IDs      : $miPath"
            Write-Host "  Owner Files      : $ownerNotifDir"
            Write-Host "  Log File         : $($script:LogFile)"
            Write-Host ([string]::new([char]0x2550, 66)) -ForegroundColor Cyan

            Write-Log "INFO" "Summary" "Audit complete. Duration: $durationStr. Apps: $($MasterReport.Count). B1=$bucket1Count B2=$bucket2Count B3=$bucket3Count B4=$bucket4Count"

            #endregion

            # Return the master report for pipeline usage
            return $MasterReport

        } finally {
            # Note: Do NOT auto-disconnect here. The caller (orchestration script or
            # interactive session) owns the Graph/Azure sessions and may need them
            # after this function completes. Auto-disconnecting forces re-auth on
            # every retry attempt, which is hostile to the user.
            Write-Log "INFO" "Cleanup" "Audit function completed. Graph/Azure sessions left open for caller."
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}
