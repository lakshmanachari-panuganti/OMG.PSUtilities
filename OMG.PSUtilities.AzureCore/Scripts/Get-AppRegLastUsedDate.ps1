<#
.SYNOPSIS
    Returns all App Registrations with their last used date from the current tenant.

.DESCRIPTION
    Queries Microsoft Graph for all App Registrations and their corresponding
    Service Principals to extract the signInActivity (ALL-TIME last sign-in dates).

    Returns a simple PSObject list with app name, appId, created date, owner,
    and the most recent sign-in date from signInActivity.

    Requires an active Graph session (Connect-MgGraph).

.PARAMETER IncludeMicrosoftApps
    (Optional) Include Microsoft 1st-party apps in the output.
    By default they are excluded to reduce noise.

.EXAMPLE
    .\Get-AppRegLastUsedDate.ps1
    # Returns all non-Microsoft app registrations with last used dates.

.EXAMPLE
    .\Get-AppRegLastUsedDate.ps1 | Sort-Object LastUsedDate | Format-Table -AutoSize
    # Sorted by last used date ascending (oldest/never-used first).

.EXAMPLE
    .\Get-AppRegLastUsedDate.ps1 | Where-Object { $_.LastUsedDate -eq "Never" } | Export-Csv -Path "C:\unused_apps.csv" -NoTypeInformation
    # Export apps that have never been used.

.EXAMPLE
    .\Get-AppRegLastUsedDate.ps1 -IncludeMicrosoftApps
    # Include Microsoft 1st-party apps in the output.

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 8th March 2026
    Version: 1.0
    Prerequisites: PowerShell 7.2+, Microsoft.Graph.Authentication, Microsoft.Graph.Applications
    Required Scopes: Application.Read.All, Directory.Read.All
#>

#Requires -Version 7.2

[CmdletBinding()]
param (
    [switch]$IncludeMicrosoftApps
)

$ErrorActionPreference = "Stop"
$MicrosoftTenantId = "f8cdef31-a31e-4b4a-93e4-5f571e91255a"

# ── Validate Graph session ──
$mgContext = Get-MgContext
if ($null -eq $mgContext) {
    throw "No Graph session. Run: Connect-MgGraph -Scopes 'Application.Read.All','Directory.Read.All'"
}

try {
    $null = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1
} catch {
    throw "Graph token invalid or expired. Reconnect with: Connect-MgGraph -Scopes 'Application.Read.All','Directory.Read.All'"
}

$tenantId = $mgContext.TenantId
Write-Host "Tenant: $tenantId | Account: $($mgContext.Account ?? $mgContext.AppName)" -ForegroundColor Cyan

# ── Load App Registrations ──
Write-Host "Loading App Registrations..." -ForegroundColor White
$allApps = Get-MgApplication -All -ExpandProperty "owners" -Property @(
    "id", "appId", "displayName", "createdDateTime", "signInAudience",
    "passwordCredentials", "keyCredentials"
)
Write-Host "  $($allApps.Count) App Registrations loaded" -ForegroundColor Green

# ── Load Service Principals (for signInActivity) ──
Write-Host "Loading Service Principals (signInActivity)..." -ForegroundColor White
$allSPs = Get-MgServicePrincipal -All -Property @(
    "appId", "displayName", "accountEnabled", "appOwnerOrganizationId",
    "servicePrincipalType", "signInActivity"
)
Write-Host "  $($allSPs.Count) Service Principals loaded" -ForegroundColor Green

# Build SP lookup by AppId
$spLookup = @{}
foreach ($sp in $allSPs) { $spLookup[$sp.AppId] = $sp }

# ── Build result ──
Write-Host "Processing..." -ForegroundColor White
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($app in $allApps) {
    $sp = $spLookup[$app.AppId]

    # Skip Microsoft 1st-party unless requested
    if (-not $IncludeMicrosoftApps -and $null -ne $sp -and $sp.AppOwnerOrganizationId -eq $MicrosoftTenantId) {
        continue
    }

    # Best sign-in date from signInActivity (ALL-TIME, no retention limit)
    $lastInteractive    = $sp.SignInActivity.LastSignInDateTime
    $lastNonInteractive = $sp.SignInActivity.LastNonInteractiveSignInDateTime

    $bestDate = $null
    if ($null -ne $lastInteractive)    { $bestDate = $lastInteractive }
    if ($null -ne $lastNonInteractive -and ($null -eq $bestDate -or $lastNonInteractive -gt $bestDate)) {
        $bestDate = $lastNonInteractive
    }

    $daysSinceUse = if ($null -ne $bestDate) { [int]((Get-Date) - $bestDate).TotalDays } else { -1 }

    # Owner
    $ownerUPN = if ($app.Owners.Count -gt 0) {
        ($app.Owners | ForEach-Object {
            $_.AdditionalProperties.userPrincipalName ?? $_.AdditionalProperties.displayName ?? $_.Id
        }) -join ";"
    } else { "NoOwner" }

    # Credential status
    $now = Get-Date
    $secretCount = $app.PasswordCredentials.Count
    $hasActiveSecret = ($app.PasswordCredentials | Where-Object { $_.EndDateTime -ge $now }).Count -gt 0
    $certCount = $app.KeyCredentials.Count

    $results.Add([PSCustomObject]@{
        AppName                = $app.DisplayName
        AppId                  = $app.AppId
        ObjectId               = $app.Id
        CreatedDate            = $app.CreatedDateTime
        SignInAudience         = $app.SignInAudience
        Owner                  = $ownerUPN
        HasServicePrincipal    = ($null -ne $sp)
        SPEnabled              = if ($null -ne $sp) { $sp.AccountEnabled } else { "N/A" }
        LastInteractiveSignIn  = if ($null -ne $lastInteractive) { $lastInteractive } else { "Never" }
        LastDaemonSignIn       = if ($null -ne $lastNonInteractive) { $lastNonInteractive } else { "Never" }
        LastUsedDate           = if ($null -ne $bestDate) { $bestDate } else { "Never" }
        DaysSinceLastUse       = $daysSinceUse
        SecretCount            = $secretCount
        HasActiveSecret        = $hasActiveSecret
        CertCount              = $certCount
    })
}

Write-Host "  $($results.Count) apps processed" -ForegroundColor Green
Write-Host ""

# Return the object for pipeline use
$results
