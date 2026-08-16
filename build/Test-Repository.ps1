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

.PARAMETER WarningBaseline
    Path to the committed PSScriptAnalyzer warning baseline. Relative paths are
    resolved from RepositoryRoot.

.PARAMETER UpdateWarningBaseline
    Regenerates WarningBaseline from the complete current warning backlog.
    Implies IncludeScriptAnalyzer.

.EXAMPLE
    .\build\Test-Repository.ps1

    Validates every module in the current repository.

.EXAMPLE
    .\build\Test-Repository.ps1 -IncludeScriptAnalyzer

    Validates every module and runs PSScriptAnalyzer.

.EXAMPLE
    .\build\Test-Repository.ps1 -UpdateWarningBaseline

    Validates every module and intentionally regenerates the warning baseline.

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
    [switch]$IncludeScriptAnalyzer,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$WarningBaseline = (Join-Path $PSScriptRoot 'psscriptanalyzer-baseline.json'),

    [Parameter()]
    [switch]$UpdateWarningBaseline
)

$ErrorActionPreference = 'Stop'
$IncludeScriptAnalyzer = $IncludeScriptAnalyzer -or $UpdateWarningBaseline
$env:PSModulePath = "$RepositoryRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
$validationErrors = [System.Collections.Generic.List[string]]::new()
$validationWarnings = [System.Collections.Generic.List[string]]::new()
$analyzerWarningRecords = [System.Collections.Generic.List[object]]::new()
$newAnalyzerWarningCount = 0
$staleBaselineWarningCount = 0

function Get-StringSha256 {
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $algorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value))
        ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Get-AnalyzerWarningRecord {
    param (
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [object]$AnalysisResult
    )

    $relativePath = if ($AnalysisResult.ScriptPath) {
        [System.IO.Path]::GetRelativePath($RepositoryRoot, $AnalysisResult.ScriptPath).Replace('\', '/')
    } else {
        [string]$AnalysisResult.ScriptName
    }
    $context = [string]$AnalysisResult.Extent.Text
    if ([string]::IsNullOrWhiteSpace($context) -and
        $AnalysisResult.ScriptPath -and
        (Test-Path -LiteralPath $AnalysisResult.ScriptPath -PathType Leaf)) {
        $sourceLines = [System.IO.File]::ReadAllLines($AnalysisResult.ScriptPath)
        $lineIndex = [int]$AnalysisResult.Line - 1
        if ($lineIndex -ge 0 -and $lineIndex -lt $sourceLines.Count) {
            $context = $sourceLines[$lineIndex]
        }
    }
    if ([string]::IsNullOrWhiteSpace($context)) {
        $context = [string]$AnalysisResult.Message
    }

    $normalizedContext = ([regex]::Replace($context, '\s+', ' ')).Trim()
    $message = "[$ModuleName] $relativePath`:$($AnalysisResult.Line) [$($AnalysisResult.RuleName)] $($AnalysisResult.Message)"

    [PSCustomObject]@{
        RuleName    = [string]$AnalysisResult.RuleName
        Path        = $relativePath
        ContextHash = Get-StringSha256 -Value $normalizedContext
        Message     = $message
    }
}

function Get-AnalyzerWarningKey {
    param (
        [Parameter(Mandatory)]
        [object]$WarningRecord
    )

    $separator = [char]31
    "$($WarningRecord.RuleName)$separator$($WarningRecord.Path)$separator$($WarningRecord.ContextHash)"
}

function Import-AnalyzerWarningBaseline {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "PSScriptAnalyzer warning baseline not found: '$Path'. Run Test-Repository.ps1 -UpdateWarningBaseline."
    }

    try {
        $baseline = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Unable to read PSScriptAnalyzer warning baseline '$Path': $($_.Exception.Message)"
    }
    if ([int]$baseline.schemaVersion -ne 1) {
        throw "Unsupported PSScriptAnalyzer warning baseline schema '$($baseline.schemaVersion)' in '$Path'."
    }

    $remainingFindings = @{}
    foreach ($finding in @($baseline.findings)) {
        if (-not $finding.ruleName -or -not $finding.path -or -not $finding.contextHash -or [int]$finding.count -lt 1) {
            throw "Invalid PSScriptAnalyzer warning baseline entry in '$Path'."
        }

        $key = Get-AnalyzerWarningKey -WarningRecord ([PSCustomObject]@{
                RuleName    = [string]$finding.ruleName
                Path        = [string]$finding.path
                ContextHash = [string]$finding.contextHash
            })
        if ($remainingFindings.ContainsKey($key)) {
            $remainingFindings[$key] += [int]$finding.count
        } else {
            $remainingFindings[$key] = [int]$finding.count
        }
    }

    $remainingFindings
}

function Export-AnalyzerWarningBaseline {
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$WarningRecord,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $findings = @($WarningRecord |
        Group-Object RuleName, Path, ContextHash |
        ForEach-Object {
            $record = $_.Group[0]
            [PSCustomObject][ordered]@{
                ruleName    = $record.RuleName
                path        = $record.Path
                contextHash = $record.ContextHash
                count       = $_.Count
            }
        } |
        Sort-Object ruleName, path, contextHash)
    $baseline = [ordered]@{
        schemaVersion = 1
        identity      = 'RuleName + repository-relative path + SHA256 of normalized diagnostic source context; duplicate identities retain an exact count.'
        warningCount  = $WarningRecord.Count
        findings      = $findings
    }
    $parentPath = Split-Path -Parent $Path
    if ($parentPath -and -not (Test-Path -LiteralPath $parentPath)) {
        New-Item -Path $parentPath -ItemType Directory -Force | Out-Null
    }

    $json = $baseline | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8
}

$warningBaselinePath = if ([System.IO.Path]::IsPathRooted($WarningBaseline)) {
    $WarningBaseline
} else {
    Join-Path $RepositoryRoot $WarningBaseline
}
$baselineRemainingFindings = if ($IncludeScriptAnalyzer -and -not $UpdateWarningBaseline) {
    Import-AnalyzerWarningBaseline -Path $warningBaselinePath
} else {
    @{}
}

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
            $relativePath = [System.IO.Path]::GetRelativePath($RepositoryRoot, $analysisResult.ScriptPath).Replace('\', '/')
            $message = "[$moduleName] $relativePath`:$($analysisResult.Line) [$($analysisResult.RuleName)] $($analysisResult.Message)"
            if ($analysisResult.Severity -eq 'Error') {
                $validationErrors.Add($message)
            } else {
                $analyzerWarningRecords.Add(
                    (Get-AnalyzerWarningRecord -ModuleName $moduleName -AnalysisResult $analysisResult)
                )
            }
        }
    }
}

if ($IncludeScriptAnalyzer) {
    if ($UpdateWarningBaseline) {
        if ($validationErrors.Count -eq 0) {
            Export-AnalyzerWarningBaseline `
                -WarningRecord @($analyzerWarningRecords) `
                -Path $warningBaselinePath
        }
        foreach ($warningRecord in $analyzerWarningRecords) {
            $validationWarnings.Add("[BASELINED] $($warningRecord.Message)")
        }
    } else {
        foreach ($warningRecord in $analyzerWarningRecords) {
            $key = Get-AnalyzerWarningKey -WarningRecord $warningRecord
            if ($baselineRemainingFindings.ContainsKey($key) -and $baselineRemainingFindings[$key] -gt 0) {
                $baselineRemainingFindings[$key]--
                $validationWarnings.Add("[BASELINED] $($warningRecord.Message)")
            } else {
                $newAnalyzerWarningCount++
                $validationErrors.Add("[NEW ANALYZER WARNING] $($warningRecord.Message)")
            }
        }

        $staleBaselineWarningCount = @($baselineRemainingFindings.Values |
                Measure-Object -Sum).Sum
        if ($staleBaselineWarningCount -gt 0) {
            Write-Warning "The analyzer baseline contains $staleBaselineWarningCount warning(s) that are no longer present. Regenerate it with -UpdateWarningBaseline to record the reduction."
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
    ModulesValidated       = $moduleDirectories.Count
    AnalyzerWarnings       = $analyzerWarningRecords.Count
    NewAnalyzerWarnings    = $newAnalyzerWarningCount
    StaleBaselineWarnings  = $staleBaselineWarningCount
    WarningBaseline        = if ($IncludeScriptAnalyzer) { $warningBaselinePath } else { $null }
    Status                 = 'Passed'
}

$result
