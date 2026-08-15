<#
.SYNOPSIS
    Validates all PowerShell modules in the repository.

.DESCRIPTION
    Performs syntax, manifest, export, and comment-based help validation for
    every OMG.PSUtilities module. The script returns a non-zero exit code when
    a blocking validation error is found, making it suitable for local use and
    continuous integration.

.PARAMETER RepositoryRoot
    The repository root. Defaults to the parent folder of this script.

.PARAMETER BaseRef
    Optional Git revision used to enforce module version increases.

.PARAMETER HeadRef
    The Git revision containing changes relative to BaseRef. Defaults to HEAD.

.PARAMETER IncludeScriptAnalyzer
    Runs PSScriptAnalyzer when the module is installed.

.EXAMPLE
    .\build\Test-Repository.ps1

    Validates every module in the current repository.

.EXAMPLE
    .\build\Test-Repository.ps1 -IncludeScriptAnalyzer

    Validates every module and runs PSScriptAnalyzer.

.EXAMPLE
    .\build\Test-Repository.ps1 -BaseRef origin/main

    Validates the repository and requires version increases for changed modules.

.OUTPUTS
    [PSCustomObject]

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
    [string]$BaseRef,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$HeadRef = 'HEAD',

    [Parameter()]
    [switch]$IncludeScriptAnalyzer
)

$ErrorActionPreference = 'Stop'
$env:PSModulePath = "$RepositoryRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
$validationErrors = [System.Collections.Generic.List[string]]::new()
$validationWarnings = [System.Collections.Generic.List[string]]::new()

$moduleDirectories = Get-ChildItem -Path $RepositoryRoot -Directory |
    Where-Object {
        $_.Name -eq 'OMG.PSUtilities' -or
        $_.Name -like 'OMG.PSUtilities.*' -or
        $_.Name -eq 'OMG.DevTools'
    } |
    Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psd1") } |
    Sort-Object Name

if ($moduleDirectories.Count -eq 0) {
    throw "No PowerShell modules were found in '$RepositoryRoot'."
}

if ($BaseRef) {
    & (Join-Path $PSScriptRoot 'Test-ModuleVersionChange.ps1') `
        -RepositoryRoot $RepositoryRoot `
        -BaseRef $BaseRef `
        -HeadRef $HeadRef | Out-Null
}

foreach ($moduleDirectory in $moduleDirectories) {
    $moduleName = $moduleDirectory.Name
    $manifestPath = Join-Path $moduleDirectory.FullName "$moduleName.psd1"
    Write-Host "Validating $moduleName" -ForegroundColor Cyan

    try {
        $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    } catch {
        $validationErrors.Add("[$moduleName] Invalid manifest: $($_.Exception.Message)")
        continue
    }

    $scriptFiles = Get-ChildItem -Path $moduleDirectory.FullName -Recurse -File |
        Where-Object { $_.Extension -in '.ps1', '.psm1' }

    foreach ($scriptFile in $scriptFiles) {
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptFile.FullName,
            [ref]$null,
            [ref]$parseErrors
        ) | Out-Null

        foreach ($parseError in $parseErrors) {
            $relativePath = [System.IO.Path]::GetRelativePath($RepositoryRoot, $scriptFile.FullName)
            $validationErrors.Add("[$moduleName] $($relativePath):$($parseError.Extent.StartLineNumber) $($parseError.Message)")
        }
    }

    $publicPath = Join-Path $moduleDirectory.FullName 'Public'
    if (Test-Path $publicPath) {
        $publicFunctions = Get-ChildItem -Path $publicPath -Recurse -Filter '*.ps1' -File |
            Where-Object { $_.Name -notlike '*--wip.ps1' } |
            ForEach-Object { $_.BaseName } |
            Sort-Object -Unique

        $manifestFunctions = @($manifest.ExportedFunctions.Keys) | Sort-Object -Unique
        $exportDifference = Compare-Object -ReferenceObject $publicFunctions -DifferenceObject $manifestFunctions

        foreach ($difference in $exportDifference) {
            $direction = if ($difference.SideIndicator -eq '<=') { 'missing from manifest' } else { 'not found in Public' }
            $validationErrors.Add("[$moduleName] Export '$($difference.InputObject)' is $direction.")
        }

        foreach ($publicFile in (Get-ChildItem -Path $publicPath -Recurse -Filter '*.ps1' -File | Where-Object { $_.Name -notlike '*--wip.ps1' })) {
            $content = Get-Content -Path $publicFile.FullName -Raw
            foreach ($requiredHelpTag in '.SYNOPSIS', '.DESCRIPTION', '.EXAMPLE', '.OUTPUTS', '.NOTES') {
                if ($content -notmatch [regex]::Escape($requiredHelpTag)) {
                    $relativePath = [System.IO.Path]::GetRelativePath($RepositoryRoot, $publicFile.FullName)
                    $validationErrors.Add("[$moduleName] $relativePath is missing $requiredHelpTag help.")
                }
            }
        }
    }

    if ($IncludeScriptAnalyzer) {
        if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            $validationErrors.Add('PSScriptAnalyzer is required when -IncludeScriptAnalyzer is specified.')
            break
        }

        $settingsPath = Join-Path $RepositoryRoot 'PSScriptAnalyzerSettings.psd1'
        $analysisResults = Invoke-ScriptAnalyzer -Path $moduleDirectory.FullName -Recurse -Settings $settingsPath
        foreach ($analysisResult in $analysisResults) {
            $message = "[$moduleName] $($analysisResult.ScriptName):$($analysisResult.Line) [$($analysisResult.RuleName)] $($analysisResult.Message)"
            if ($analysisResult.Severity -eq 'Error') {
                $validationErrors.Add($message)
            } else {
                $validationWarnings.Add($message)
            }
        }
    }
}

foreach ($warningMessage in $validationWarnings) {
    Write-Warning $warningMessage
}

if ($validationErrors.Count -gt 0) {
    Write-Host "`nRepository validation failed with $($validationErrors.Count) error(s):" -ForegroundColor Red
    foreach ($validationError in $validationErrors) {
        Write-Host " - $validationError" -ForegroundColor Red
    }
    throw 'Repository validation failed.'
}

$result = [PSCustomObject]@{
    ModulesValidated = $moduleDirectories.Count
    AnalyzerWarnings = $validationWarnings.Count
    Status           = 'Passed'
}

$result
