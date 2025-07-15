# ===============================================
# Script: Tools\Auto-BuildAndVersionChangedModules.ps1
# Author: Lakshmanachari Panuganti
# Purpose: Detect changes, bump versions, update changelog & readme, auto-build
# ===============================================

param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$rootPath = Split-Path $PSScriptRoot -Parent
$toolsPath = Join-Path $rootPath 'Tools'

# Import reusable build functions
. "$toolsPath\Build-OMGModuleLocally.ps1"
. "$toolsPath\Update-OMGModuleManifests.ps1"
. "$toolsPath\Bump-ModuleVersion.ps1"

Write-Host "🚀 Scanning for modified modules..." -ForegroundColor Cyan

# Get list of modified files via Git
$changedFiles = git status --porcelain | Where-Object { $_ -match '^ [AMR] ' } | ForEach-Object {
    ($_ -split ' +', 2)[1]
}

# Get unique list of modified modules (based on folder name)
$changedModules = $changedFiles | ForEach-Object {
    if ($_ -match '^OMG\.PSUtilities\.([^\/\\]+)\\Public\\(.+?)\.ps1$') {
        [PSCustomObject]@{
            Module = $matches[1]
            Function = $matches[2]
            File = $_
        }
    }
} | Group-Object Module | ForEach-Object {
    [PSCustomObject]@{
        ModuleName = $_.Name
        Functions  = $_.Group.Function
        Files      = $_.Group.File
    }
}

if (-not $changedModules) {
    Write-Host "✅ No changes found in any module. Exiting..." -ForegroundColor Green
    return
}

foreach ($mod in $changedModules) {
    $modRoot = Join-Path $rootPath "OMG.PSUtilities.$($mod.ModuleName)"
    $psd1Path = Get-ChildItem -Path $modRoot -Filter *.psd1 | Select-Object -First 1
    $readmePath = Join-Path $modRoot 'README.md'
    $changelogPath = Join-Path $modRoot 'CHANGELOG.md'

    Write-Host "\n📦 Module: $($mod.ModuleName)" -ForegroundColor Yellow

    # Prompt for changelog per function
    $changeDetails = @()
    foreach ($fn in $mod.Functions) {
        $msg = Read-Host "[CHANGELOG] [$($mod.ModuleName)][$fn.ps1] → Enter change description"
        $changeDetails += "- $fn : $msg"
    }

    # Bump module version and get new version
    $newVersion = Bump-ModuleVersion -ModulePath $modRoot -DryRun:$DryRun

    # Update CHANGELOG
    if (-not $DryRun) {
        $date = (Get-Date).ToString('yyyy-MM-dd')
        Add-Content -Path $changelogPath -Value "\n## [$newVersion] - $date"
        $changeDetails | ForEach-Object { Add-Content -Path $changelogPath -Value $_ }
        Write-Host "📝 CHANGELOG updated."
    } else {
        Write-Host "💡 [DryRun] Would update CHANGELOG with version $newVersion"
    }

    # Update README
    if (-not $DryRun) {
        $readmeLines = Get-Content $readmePath
        $metaLine = "> Module version: $newVersion | Last updated: $(Get-Date -Format 'yyyy-MM-dd')"
        $readmeLines = $readmeLines | Where-Object { $_ -notmatch '^> Module version:' }
        $readmeLines += "\n$metaLine\n"

        $readmeLines += "### 🚀 Recently Updated Functions"
        $readmeLines += ($changeDetails | ForEach-Object { "- $_" })

        Set-Content -Path $readmePath -Value $readmeLines
        Write-Host "📘 README updated."
    } else {
        Write-Host "💡 [DryRun] Would update README with version and function list."
    }

    # Update Manifest + Build
    if (-not $DryRun) {
        Update-OMGModuleManifests -ModulePath $modRoot
        Build-OMGModuleLocally -ModulePath $modRoot
    } else {
        Write-Host "💡 [DryRun] Would update manifest and build module."
    }
}

Write-Host "\n✅ All modified modules processed." -ForegroundColor Green
