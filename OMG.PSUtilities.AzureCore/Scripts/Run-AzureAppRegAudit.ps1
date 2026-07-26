<#
.SYNOPSIS
    Orchestration script for Azure App Registration audit.

.DESCRIPTION
    End-to-end orchestration script that handles:
    1. Pre-requisite module verification and installation
    2. Authentication to Microsoft Graph and Azure
    3. Output directory setup with timestamped folders
    4. Calling Invoke-PSUAzureAppRegAudit with the chosen audit mode
    5. Post-processing: HTML report generation, folder opening, console summary

    Three audit modes are available:
    - Quick  : Skips per-app sign-in log queries (~30 min for 9,000 apps)
    - Full   : Collects all 13 signals including sign-in logs (~3-4 hours)
    - DryRun : Processes only the first N apps for testing

    This script is NOT a module function. Run it directly from the Scripts/ folder.

.PARAMETER AuditMode
    Select the audit mode.
    - Quick   : SkipSignInLogs enabled (~30 min)
    - Full    : All signals collected (~3-4 hrs)
    - DryRun  : Process only -DryRunCount apps
    Default is Quick.

.PARAMETER TenantId
    (Optional) The Entra ID tenant ID. Auto-detected from Graph context if omitted.

.PARAMETER OutputRoot
    (Optional) Root folder for audit output. A timestamped subfolder is created.
    Default is C:\AuditOutput.

.PARAMETER DryRunCount
    (Optional) Number of apps to process in DryRun mode.
    Default is 50.

.PARAMETER SkipAzureRBAC
    (Optional) Skip Azure RBAC data collection even in Full mode.

.PARAMETER ThrottleDelayMs
    (Optional) Base delay in milliseconds between per-app Graph calls.
    Default is 200.

.PARAMETER SkipHtmlReport
    (Optional) Skip HTML report generation after audit.

.PARAMETER NoOpenFolder
    (Optional) Do not auto-open the output folder after audit.

.PARAMETER GraphScopes
    (Optional) Graph scopes to request during Connect-MgGraph.
    Default includes Application.Read.All, Directory.Read.All, AuditLog.Read.All,
    Policy.Read.All.

.EXAMPLE
    .\Run-AzureAppRegAudit.ps1

    Runs a Quick audit with default settings.

.EXAMPLE
    .\Run-AzureAppRegAudit.ps1 -AuditMode Full -OutputRoot "D:\Audits"

    Runs a Full audit with output saved under D:\Audits.

.EXAMPLE
    .\Run-AzureAppRegAudit.ps1 -AuditMode DryRun -DryRunCount 20 -SkipAzureRBAC

    Processes 20 apps without Azure RBAC, for testing.

.EXAMPLE
    .\Run-AzureAppRegAudit.ps1 -AuditMode Quick -TenantId "abc-123" -SkipHtmlReport

    Quick audit for specific tenant, no HTML report.

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 7th March 2026
    Last Modified: 7th March 2026
    Version: 1.0

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureCore
#>

#Requires -Version 7.2

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    [ValidateSet("Quick", "Full", "DryRun")]
    [string]$AuditMode = "Quick",

    [Parameter()]
    [string]$TenantId,

    [Parameter()]
    [string]$OutputRoot = "C:\AuditOutput",

    [Parameter()]
    [int]$DryRunCount = 50,

    [Parameter()]
    [switch]$SkipAzureRBAC,

    [Parameter()]
    [int]$ThrottleDelayMs = 200,

    [Parameter()]
    [switch]$SkipHtmlReport,

    [Parameter()]
    [switch]$NoOpenFolder,

    [Parameter()]
    [string[]]$GraphScopes = @(
        "Application.Read.All",
        "Directory.Read.All",
        "AuditLog.Read.All",
        "Policy.Read.All"
    )
)

$ErrorActionPreference = "Stop"
$scriptStart = Get-Date

#region Banner
$bannerChar = [char]0x2550
Write-Host ""
Write-Host ([string]::new($bannerChar, 70)) -ForegroundColor Cyan
Write-Host "  Azure App Registration Audit - Orchestration Script" -ForegroundColor Cyan
Write-Host "  Mode: $AuditMode | Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host ([string]::new($bannerChar, 70)) -ForegroundColor Cyan
Write-Host ""
#endregion

#region Step 1: Pre-requisite Module Check
Write-Host "[1/6] Checking pre-requisite modules..." -ForegroundColor White

$requiredModules = @(
    @{ Name = "Microsoft.Graph.Authentication";           MinVer = "2.0.0" },
    @{ Name = "Microsoft.Graph.Applications";             MinVer = "2.0.0" },
    @{ Name = "Microsoft.Graph.Reports";                  MinVer = "2.0.0" },
    @{ Name = "Microsoft.Graph.Identity.Governance";      MinVer = "2.0.0" },
    @{ Name = "Microsoft.Graph.Identity.DirectoryManagement"; MinVer = "2.0.0" }
)

if (-not $SkipAzureRBAC) {
    $requiredModules += @{ Name = "Az.Resources"; MinVer = "6.0.0" }
    $requiredModules += @{ Name = "Az.Accounts";  MinVer = "2.0.0" }
}

$missingModules = @()
foreach ($mod in $requiredModules) {
    $installed = Get-Module -ListAvailable -Name $mod.Name | Sort-Object Version -Descending | Select-Object -First 1
    if ($null -eq $installed) {
        $missingModules += $mod.Name
        Write-Host "  [MISSING] $($mod.Name)" -ForegroundColor Red
    } elseif ($installed.Version -lt [version]$mod.MinVer) {
        $missingModules += "$($mod.Name) (need >= $($mod.MinVer), found $($installed.Version))"
        Write-Host "  [OUTDATED] $($mod.Name) v$($installed.Version) (need >= $($mod.MinVer))" -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] $($mod.Name) v$($installed.Version)" -ForegroundColor Green
    }
}

if ($missingModules.Count -gt 0) {
    Write-Host ""
    Write-Host "  Missing or outdated modules detected:" -ForegroundColor Yellow
    $missingModules | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    Write-Host ""

    $installChoice = Read-Host "  Install missing modules now? (Y/N)"
    if ($installChoice -eq "Y" -or $installChoice -eq "y") {
        foreach ($mod in $requiredModules) {
            $installed = Get-Module -ListAvailable -Name $mod.Name | Sort-Object Version -Descending | Select-Object -First 1
            if ($null -eq $installed -or $installed.Version -lt [version]$mod.MinVer) {
                Write-Host "  Installing $($mod.Name)..." -ForegroundColor Cyan
                Install-Module -Name $mod.Name -MinimumVersion $mod.MinVer -Scope CurrentUser -Force -AllowClobber
            }
        }
        Write-Host "  Module installation complete." -ForegroundColor Green
    } else {
        throw "Cannot proceed without required modules. Install them and re-run."
    }
}

# Import the OMG.PSUtilities.AzureCore module
$moduleRoot = Split-Path $PSScriptRoot -Parent
$modulePsd1 = Join-Path $moduleRoot "OMG.PSUtilities.AzureCore.psd1"
if (Test-Path $modulePsd1) {
    Import-Module $modulePsd1 -Force
    Write-Host "  [OK] OMG.PSUtilities.AzureCore imported" -ForegroundColor Green
} else {
    throw "Cannot find OMG.PSUtilities.AzureCore.psd1 at: $modulePsd1"
}

Write-Host ""
#endregion

#region Step 2: Authentication
Write-Host "[2/6] Authenticating..." -ForegroundColor White

# Graph authentication
$mgContext = Get-MgContext -ErrorAction SilentlyContinue
if ($null -eq $mgContext) {
    Write-Host "  Connecting to Microsoft Graph..." -ForegroundColor Cyan
    if ($TenantId) {
        Connect-MgGraph -Scopes $GraphScopes -TenantId $TenantId -NoWelcome
    } else {
        Connect-MgGraph -Scopes $GraphScopes -NoWelcome
    }
    $mgContext = Get-MgContext
} else {
    # Validate existing scopes
    $currentScopes = $mgContext.Scopes
    $missingScopes = $GraphScopes | Where-Object { $_ -notin $currentScopes }
    if ($missingScopes.Count -gt 0) {
        Write-Host "  Existing Graph session missing scopes: $($missingScopes -join ', ')" -ForegroundColor Yellow
        Write-Host "  Reconnecting with required scopes..." -ForegroundColor Cyan
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        if ($TenantId) {
            Connect-MgGraph -Scopes $GraphScopes -TenantId $TenantId -NoWelcome
        } else {
            Connect-MgGraph -Scopes $GraphScopes -NoWelcome
        }
        $mgContext = Get-MgContext
    } else {
        Write-Host "  Reusing existing Graph session" -ForegroundColor Green
    }
}

$effectiveTenantId = $TenantId ?? $mgContext.TenantId
$authIdentity = $mgContext.Account ?? $mgContext.AppName ?? "Unknown"
Write-Host "  Graph : $authIdentity | Tenant: $effectiveTenantId" -ForegroundColor Green

# Azure authentication (if needed)
if (-not $SkipAzureRBAC) {
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if ($null -eq $azContext) {
        Write-Host "  Connecting to Azure..." -ForegroundColor Cyan
        if ($TenantId) {
            Connect-AzAccount -TenantId $TenantId
        } else {
            Connect-AzAccount
        }
        $azContext = Get-AzContext
    } else {
        Write-Host "  Reusing existing Azure session" -ForegroundColor Green
    }
    Write-Host "  Azure : $($azContext.Account.Id) | Subscription: $($azContext.Subscription.Name)" -ForegroundColor Green
} else {
    Write-Host "  Azure : SKIPPED (SkipAzureRBAC)" -ForegroundColor DarkGray
}

Write-Host ""
#endregion

#region Step 3: Output Directory Setup
Write-Host "[3/6] Setting up output directories..." -ForegroundColor White

$runTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$runFolder = Join-Path $OutputRoot "AppRegAudit_${effectiveTenantId}_${runTimestamp}"

if (-not (Test-Path $runFolder)) {
    New-Item -Path $runFolder -ItemType Directory -Force | Out-Null
}

$logDir = Join-Path $runFolder "Logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Write-Host "  Output : $runFolder" -ForegroundColor Green
Write-Host "  Logs   : $logDir" -ForegroundColor Green
Write-Host ""
#endregion

#region Step 4: Mode Configuration
Write-Host "[4/6] Configuring audit mode: $AuditMode..." -ForegroundColor White

$auditParams = @{
    TenantId        = $effectiveTenantId
    OutputDirectory = $runFolder
    LogDirectory    = $logDir
    ThrottleDelayMs = $ThrottleDelayMs
    VerboseMode     = $true
}

switch ($AuditMode) {
    "Quick" {
        $auditParams["SkipSignInLogs"] = $true
        $estimatedTime = "~30 minutes"
        Write-Host "  Skip Sign-in Logs : YES (fast mode)" -ForegroundColor Yellow
    }
    "Full" {
        $estimatedTime = "~3-4 hours"
        Write-Host "  Skip Sign-in Logs : NO (full signal coverage)" -ForegroundColor Green
    }
    "DryRun" {
        $auditParams["SkipSignInLogs"] = $true
        $auditParams["DryRunLimit"]    = $DryRunCount
        $estimatedTime = "~2-5 minutes"
        Write-Host "  Dry Run Limit     : $DryRunCount apps" -ForegroundColor Cyan
        Write-Host "  Skip Sign-in Logs : YES" -ForegroundColor Yellow
    }
}

if ($SkipAzureRBAC) {
    $auditParams["SkipAzureRBAC"] = $true
    Write-Host "  Skip Azure RBAC   : YES" -ForegroundColor Yellow
}

Write-Host "  Estimated Time    : $estimatedTime" -ForegroundColor White
Write-Host ""
#endregion

#region Step 5: Run Audit
Write-Host "[5/6] Running Azure App Registration Audit ($AuditMode mode)..." -ForegroundColor White
Write-Host "  Started at: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor DarkGray
Write-Host ""

$auditResult = Invoke-PSUAzureAppRegAudit @auditParams

$auditDuration = (Get-Date) - $scriptStart
Write-Host ""
Write-Host "  Audit completed in $([int]$auditDuration.TotalMinutes) min $($auditDuration.Seconds) sec" -ForegroundColor Green
Write-Host ""
#endregion

#region Step 6: Post-Processing
Write-Host "[6/6] Post-processing..." -ForegroundColor White

# Generate HTML report
if (-not $SkipHtmlReport) {
    $htmlScript = Join-Path $PSScriptRoot "ConvertTo-AuditHtmlReport.ps1"
    if (Test-Path $htmlScript) {
        Write-Host "  Generating HTML report..." -ForegroundColor Cyan
        try {
            & $htmlScript -InputDirectory $runFolder -TenantId $effectiveTenantId
            $htmlFile = Get-ChildItem -Path $runFolder -Filter "*.html" -File | Select-Object -First 1
            if ($htmlFile) {
                Write-Host "  HTML Report: $($htmlFile.FullName)" -ForegroundColor Green
            }
        } catch {
            Write-Host "  HTML report generation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ConvertTo-AuditHtmlReport.ps1 not found, skipping HTML report" -ForegroundColor DarkGray
    }
}

# Open output folder
if (-not $NoOpenFolder) {
    Write-Host "  Opening output folder..." -ForegroundColor Cyan
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        Start-Process explorer.exe -ArgumentList $runFolder
    } elseif ($IsMacOS) {
        Start-Process "open" -ArgumentList $runFolder
    } elseif ($IsLinux) {
        Start-Process "xdg-open" -ArgumentList $runFolder
    }
}

# Final summary
$totalDuration = (Get-Date) - $scriptStart
$totalDurationStr = "$([int]$totalDuration.TotalMinutes) min $($totalDuration.Seconds) sec"

Write-Host ""
Write-Host ([string]::new([char]0x2550, 70)) -ForegroundColor Cyan
Write-Host "  ORCHESTRATION COMPLETE" -ForegroundColor Cyan
Write-Host ([string]::new([char]0x2550, 70)) -ForegroundColor Cyan
Write-Host "  Mode           : $AuditMode"
Write-Host "  Duration       : $totalDurationStr"
Write-Host "  Tenant         : $effectiveTenantId"
Write-Host "  Apps Processed : $(@($auditResult).Count)"
Write-Host "  Output Folder  : $runFolder"

# List generated files
$outputFiles = Get-ChildItem -Path $runFolder -File -Recurse | Where-Object { $_.Extension -in @('.csv', '.html', '.log') }
Write-Host ""
Write-Host "  Generated Files ($($outputFiles.Count)):" -ForegroundColor White
foreach ($file in $outputFiles | Sort-Object Extension, Name) {
    $sizeKB = [math]::Round($file.Length / 1KB, 1)
    $relPath = $file.FullName.Replace($runFolder, "").TrimStart('\')
    Write-Host "    $($file.Extension.PadRight(6)) ${sizeKB}KB  $relPath" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host ([string]::new([char]0x2550, 70)) -ForegroundColor Cyan
Write-Host ""
#endregion
