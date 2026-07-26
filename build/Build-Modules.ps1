<#
.SYNOPSIS
    Builds publishable artifacts for all repository modules.

.DESCRIPTION
    Validates the repository and copies each PowerShell module to a clean output
    directory. Work-in-progress scripts and repository-only files are excluded
    from the artifacts.

.PARAMETER RepositoryRoot
    The repository root. Defaults to the parent folder of this script.

.PARAMETER OutputPath
    The artifact output path. Defaults to artifacts/modules in the repository.

.PARAMETER ModuleName
    Optional names of modules to build. All modules are built when omitted.

.PARAMETER Clean
    Removes the existing output directory before building.

.EXAMPLE
    .\build\Build-Modules.ps1 -Clean

    Validates and builds every module.

.EXAMPLE
    .\build\Build-Modules.ps1 -ModuleName OMG.PSUtilities.Core

    Builds only the Core module.

.OUTPUTS
    [System.IO.DirectoryInfo]

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 26th July 2026
    Last Modified: 26th July 2026
    Version: 1.0
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts/modules'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$ModuleName,

    [Parameter()]
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'Test-Repository.ps1')
if ($LASTEXITCODE -ne 0) {
    throw 'Repository validation failed.'
}

if ($Clean -and (Test-Path $OutputPath)) {
    Remove-Item -Path $OutputPath -Recurse -Force
}

New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null

$moduleDirectories = Get-ChildItem -Path $RepositoryRoot -Directory |
    Where-Object {
        $_.Name -eq 'OMG.PSUtilities' -or
        $_.Name -like 'OMG.PSUtilities.*'
    } |
    Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psd1") } |
    Sort-Object Name

if ($ModuleName) {
    $moduleDirectories = $moduleDirectories | Where-Object { $_.Name -in $ModuleName }
    $missingModules = $ModuleName | Where-Object { $_ -notin $moduleDirectories.Name }
    if ($missingModules) {
        throw "Module(s) not found: $($missingModules -join ', ')"
    }
}

foreach ($moduleDirectory in $moduleDirectories) {
    $destination = Join-Path $OutputPath $moduleDirectory.Name
    if (Test-Path $destination) {
        Remove-Item -Path $destination -Recurse -Force
    }

    Copy-Item -Path $moduleDirectory.FullName -Destination $destination -Recurse

    Get-ChildItem -Path $destination -Recurse -File |
        Where-Object {
            $_.Name -like '*--wip.ps1' -or
            $_.Name -eq 'plasterManifest.xml'
        } |
        Remove-Item -Force

    Get-ChildItem -Path $destination -Recurse -Directory |
        Where-Object { $_.Name -eq '.github' } |
        Sort-Object FullName -Descending |
        Remove-Item -Recurse -Force

    $manifestPath = Join-Path $destination "$($moduleDirectory.Name).psd1"
    Test-ModuleManifest -Path $manifestPath -ErrorAction Stop | Out-Null
    Get-Item -Path $destination
}