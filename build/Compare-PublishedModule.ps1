<#
.SYNOPSIS
    Compares built module artifacts with exact PowerShell Gallery versions.

.DESCRIPTION
    Downloads each artifact's exact published version with Save-Module and
    compares normalized relative paths and SHA256 hashes. Save-Module extracts
    only the module payload, so no files are excluded from comparison.

    Build artifacts with Build-Modules.ps1 before running this script.

.PARAMETER ArtifactRoot
    The directory containing built module folders.

.PARAMETER ModuleName
    Optional module names to compare. All artifact module folders are used
    when omitted.

.PARAMETER Repository
    The registered PowerShell repository. Defaults to PSGallery.

.PARAMETER RequirePublishedVersion
    Fails when an artifact's exact version is not available. Use this after
    publishing; before publishing, an absent newer version is expected.

.PARAMETER RetryCount
    Maximum availability and download attempts when RequirePublishedVersion
    is specified. Defaults to one.

.PARAMETER RetryDelaySeconds
    Delay between required-version attempts. Defaults to ten seconds.

.EXAMPLE
    .\build\Build-Modules.ps1 -Clean
    .\build\Compare-PublishedModule.ps1

    Compares every built artifact whose exact version exists in PSGallery.

.EXAMPLE
    .\build\Compare-PublishedModule.ps1 -ModuleName OMG.PSUtilities.Core -RequirePublishedVersion -RetryCount 18

    Waits for the built Core version and verifies its published payload.

.OUTPUTS
    [PSCustomObject]
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ArtifactRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts/modules'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$ModuleName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Repository = 'PSGallery',

    [Parameter()]
    [switch]$RequirePublishedVersion,

    [Parameter()]
    [ValidateRange(1, 100)]
    [int]$RetryCount = 1,

    [Parameter()]
    [ValidateRange(0, 300)]
    [int]$RetryDelaySeconds = 10
)

$ErrorActionPreference = 'Stop'
$artifactPath = (Resolve-Path -LiteralPath $ArtifactRoot).Path
$downloadRoot = Join-Path ([System.IO.Path]::GetTempPath()) "psu-gallery-$([guid]::NewGuid().ToString('N'))"

function Get-FileInventory {
    param (
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $inventory = [System.Collections.Generic.Dictionary[string, string]]::new(
        [System.StringComparer]::Ordinal
    )

    foreach ($file in (Get-ChildItem -LiteralPath $RootPath -Recurse -File)) {
        $relativePath = [System.IO.Path]::GetRelativePath($RootPath, $file.FullName).Replace('\', '/')
        $inventory.Add(
            $relativePath,
            (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        )
    }

    $inventory
}

function Save-PublishedModuleVersion {
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [version]$Version
    )

    $lastFailure = $null

    foreach ($attempt in 1..$RetryCount) {
        try {
            $availableVersions = @(Find-Module -Name $Name -AllVersions -Repository $Repository -ErrorAction Stop)
        } catch {
            if ($_.FullyQualifiedErrorId -match 'NoMatchFoundForCriteria') {
                $availableVersions = @()
            } else {
                $lastFailure = "Unable to query $Repository for ${Name}: $($_.Exception.Message)"
                if (-not $RequirePublishedVersion) {
                    throw $lastFailure
                }

                if ($attempt -lt $RetryCount -and $RetryDelaySeconds -gt 0) {
                    Start-Sleep -Seconds $RetryDelaySeconds
                }
                continue
            }
        }

        $publishedVersion = $availableVersions |
            Where-Object { [version]$_.Version -eq $Version } |
            Select-Object -First 1

        if (-not $publishedVersion) {
            if (-not $RequirePublishedVersion) {
                return $null
            }

            $lastFailure = "Version $Version is not available in $Repository."
        } else {
            try {
                Save-Module `
                    -Name $Name `
                    -RequiredVersion $Version `
                    -Repository $Repository `
                    -Path $downloadRoot `
                    -Force `
                    -ErrorAction Stop

                $savedPath = Join-Path $downloadRoot "$Name/$Version"
                if (-not (Test-Path -LiteralPath $savedPath -PathType Container)) {
                    throw "Save-Module did not create '$savedPath'."
                }

                return (Resolve-Path -LiteralPath $savedPath).Path
            } catch {
                $lastFailure = $_.Exception.Message
                if (-not $RequirePublishedVersion) {
                    throw "Unable to download $Name $Version from ${Repository}: $lastFailure"
                }
            }
        }

        if ($attempt -lt $RetryCount -and $RetryDelaySeconds -gt 0) {
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }

    throw "Unable to retrieve $Name $Version from $Repository after $RetryCount attempt(s): $lastFailure"
}

$moduleNames = if ($ModuleName) {
    @($ModuleName | Sort-Object -Unique)
} else {
    @(Get-ChildItem -LiteralPath $artifactPath -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "$($_.Name).psd1") } |
            ForEach-Object { $_.Name } |
            Sort-Object -Unique)
}

if ($moduleNames.Count -eq 0) {
    throw "No built module artifacts were found in '$artifactPath'."
}

$comparisonErrors = [System.Collections.Generic.List[string]]::new()
$results = [System.Collections.Generic.List[object]]::new()

New-Item -Path $downloadRoot -ItemType Directory | Out-Null

try {
    foreach ($name in $moduleNames) {
        $localModulePath = Join-Path $artifactPath $name
        $manifestPath = Join-Path $localModulePath "$name.psd1"

        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            throw "Built manifest not found: $manifestPath"
        }

        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        try {
            $version = [version]$manifest.ModuleVersion
        } catch {
            throw "Built manifest '$manifestPath' has an invalid ModuleVersion: '$($manifest.ModuleVersion)'."
        }
        $publishedModulePath = Save-PublishedModuleVersion -Name $name -Version $version

        if (-not $publishedModulePath) {
            $results.Add([PSCustomObject]@{
                    ModuleName    = $name
                    Version       = $version
                    FilesCompared = 0
                    Status        = 'NotPublished'
                })
            continue
        }

        $localFiles = Get-FileInventory -RootPath $localModulePath
        $publishedFiles = Get-FileInventory -RootPath $publishedModulePath
        $missingLocally = @($publishedFiles.Keys |
                Where-Object { -not $localFiles.ContainsKey($_) } |
                Sort-Object)
        $missingRemotely = @($localFiles.Keys |
                Where-Object { -not $publishedFiles.ContainsKey($_) } |
                Sort-Object)
        $differentHashes = @($localFiles.Keys |
                Where-Object {
                    $publishedFiles.ContainsKey($_) -and
                    $localFiles[$_] -ne $publishedFiles[$_]
                } |
                Sort-Object)

        if ($missingLocally.Count -gt 0 -or $missingRemotely.Count -gt 0 -or $differentHashes.Count -gt 0) {
            $missingLocallyText = if ($missingLocally.Count -gt 0) { $missingLocally -join ', ' } else { '(none)' }
            $missingRemotelyText = if ($missingRemotely.Count -gt 0) { $missingRemotely -join ', ' } else { '(none)' }
            $differentHashesText = if ($differentHashes.Count -gt 0) { $differentHashes -join ', ' } else { '(none)' }
            $comparisonErrors.Add(
                "[$name $version] Gallery package differs from the local artifact.`n" +
                "  Files missing locally: $missingLocallyText`n" +
                "  Files missing remotely: $missingRemotelyText`n" +
                "  Files with different hashes: $differentHashesText"
            )
            continue
        }

        $results.Add([PSCustomObject]@{
                ModuleName    = $name
                Version       = $version
                FilesCompared = $localFiles.Count
                Status        = 'Matched'
            })
    }
} finally {
    Remove-Item -LiteralPath $downloadRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if ($comparisonErrors.Count -gt 0) {
    throw "Published module comparison failed:`n$($comparisonErrors -join "`n")"
}

$results
