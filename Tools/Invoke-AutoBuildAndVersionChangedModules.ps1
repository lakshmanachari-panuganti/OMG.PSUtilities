# ===============================================
# Script: Invoke-AutoBuildAndVersionChangedModules.ps1
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
. "$toolsPath\Reset-OMGModuleManifests.ps1.ps1"

Write-Host "Scanning for modified modules..." -ForegroundColor Cyan

# Get list of modified files via Git
$changedFiles = Get-PSUGitRepositoryChanges -RootPath $rootPath

# Get unique list of modified modules (based on folder name)
$changedModules = $changedFiles | ForEach-Object {
    $changedFile = $_

    # Regex pattern: Extract OMG.PSUtilities.<submoduleName>
    $regex = 'OMG\.PSUtilities\.[^\\]+'
    if ($changedFile.Path -match $regex) {
        $File = [PSCustomobject] @{
            Name       = $changedFile.Name
            Path       = $changedFile.Path
            ChangeType = $changedFile.ChangeType
            ItemType   = $changedFile.ItemType
        }
        [PSCustomobject] @{
            ModuleName = $matches[0]
            File       = $File
        }
    }
    
} | Group-Object ModuleName -AsHashTable

if (-not $changedModules) {
    Write-Host "No changes found in any module. Exiting..." -ForegroundColor Green
    return
}

foreach ($thismodule in $changedModules.Keys) {
    $thisModuleRoot = Join-Path $rootPath $thismodule
    $thisModuleReadmePath = Join-Path $thisModuleRoot 'README.md'
    $thisModuleChangelogPath = Join-Path $thisModuleRoot 'CHANGELOG.md'

    Write-Host ""
    Write-Host "Currently working on th module: $thismodule" -ForegroundColor Yellow

    # Prompt for changelog per function
    $changeDetails = @()

    foreach ($thisModuleFile in $changedModules.$thismodule.File) {
        $msg = $null
        $Synopsis = $null
        if ($thisModuleFile.ChangeType -like 'New') {
            $Synopsis = Get-PSUFunctionCommentBasedHelp -FunctionPath $thisModuleFile.Path -HelpType SYNOPSIS
            Write-Host "Hit Enter to update the description as [$Synopsis] for $($thisModuleFile.Name)" -ForegroundColor Cyan
        }
        
        $msg = Read-Host "[CHANGELOG] [$($thisModuleFile.ChangeType) $($thisModuleFile.ItemType)] [$($thisModuleFile.Name)] → Enter change description"

        if ( $null -ne $Synopsis -and ([string]::IsNullOrEmpty($msg) -or [string]::IsNullOrWhiteSpace($msg))) {
            $msg = $Synopsis
        }

        if ([string]::IsNullOrEmpty($msg) -or [string]::IsNullOrWhiteSpace($msg)) {
            # Skipping this file from updating in CHANGELOG
        } else {
            $changeDetails += "- [$($thisModuleFile.ChangeType) $($thisModuleFile.ItemType)] $($thisModuleFile.Name) : $msg"
        }
    }

    # TODO: Convert '$changeDetails' to natural language summary and update to Git commit message - Should achieve via Google Gemini.
    # $GitCommitMessage += $changeDetails
    # at the end $GitCommitMessage = $changeDetails -join "`n"
    # Set as environment variable Set-PSUUserEnvironmentVariable -Name AutoGitCommitMessage -Value $GitCommitMessage
    # While committing, use: git commit -m $env:AutoGitCommitMessage
    #Write-Host "Changes to commit: $($changeDetails.Count) items" -ForegroundColor Cyan
    #if ($DryRun) {
    #    Write-Host "💡 [DryRun] Would commit changes with message: $($changeDetails -join "`n")"
    #    continue
    #}
    #else {
    #    Write-Host "Committing changes to Git..." -ForegroundColor Green
    #    $gitCommitMessage = $changeDetails -join "`n"
    #    Set-PSUGitRepositoryChanges -RootPath $thisModuleRoot -Message $gitCommitMessage
    #}

    # Bump module version and get new version

    $newVersion = Update-OMGModuleVersion -ModuleName $thismodule -Increment Patch

    # Update CHANGELOG
    if (-not $DryRun) {
        $date = (Get-Date).ToString('yyyy-MM-dd')
        Add-Content -Path $thisModuleChangelogPath -Value ""
        Add-Content -Path $thisModuleChangelogPath -Value "## [$newVersion] - $date"
        $changeDetails | ForEach-Object {
            Add-Content -Path $changelogPath -Value $_
        }
        Write-Host "CHANGELOG updated."
    } else {
        Write-Host "[DryRun] [OMG.PSUtilities.$($thismodule)] Would update CHANGELOG with version $newVersion"
    }

    # Update README
    if (-not $DryRun) {
        $readmeLines = Get-Content $thisModuleReadmePath
        $metaLine = "> Module version: $newVersion | Last updated: $(Get-Date -Format 'yyyy-MM-dd')"

        # Remove previous metadata line
        $readmeLines = $readmeLines | Where-Object { $_ -notmatch '^> Module version:' }

        # Append updated metadata and function list
        $readmeLines += ""
        $readmeLines += $metaLine
        $readmeLines += "### 🚀 Recently Updated Functions"
        $readmeLines += ($changeDetails | ForEach-Object { "- $_" })
        Set-Content -Path $thisModuleReadmePath -Value $readmeLines
        Write-Host "README updated."
    } else {
        Write-Host "[DryRun] [OMG.PSUtilities.$thismodule] Would update README.md with version and function list."
    }

    # Update Manifest + Build
    if (-not $DryRun) {
        Reset-OMGModuleManifests.ps1 -ModuleName "OMG.PSUtilities.$thismodule"
        Build-OMGModuleLocally -ModuleName "OMG.PSUtilities.$thismodule"
    } else {
        Write-Host "[DryRun] Would update manifest and build module."
    }
}

Write-Host "All modified modules processed." -ForegroundColor Green
