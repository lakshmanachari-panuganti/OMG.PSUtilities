<#
.SYNOPSIS
    Requires a version increase when publishable module content changes.

.DESCRIPTION
    Compares two Git revisions, identifies changes copied by Build-Modules.ps1,
    and verifies that each affected module has a higher working-tree version
    than its manifest at the base revision.

.PARAMETER BaseRef
    The Git revision used as the comparison base.

.PARAMETER HeadRef
    The Git revision containing the changes. Defaults to HEAD.

.PARAMETER RepositoryRoot
    The repository root. Defaults to the parent folder of this script.

.EXAMPLE
    .\build\Test-ModuleVersionChange.ps1 -BaseRef origin/main

    Checks changes between origin/main and HEAD.

.OUTPUTS
    [PSCustomObject]
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$BaseRef,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$HeadRef = 'HEAD',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$repositoryPath = (Resolve-Path -LiteralPath $RepositoryRoot).Path

function Invoke-RepositoryGit {
    param (
        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $output = @(& git -C $repositoryPath @ArgumentList 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git $($ArgumentList -join ' ') failed: $($output -join [Environment]::NewLine)"
    }

    $output
}

function Resolve-RepositoryCommit {
    param (
        [Parameter(Mandatory)]
        [string]$Ref
    )

    $commitOutput = @(Invoke-RepositoryGit -ArgumentList @('rev-parse', '--verify', "$Ref^{commit}"))
    $commitOutput[-1].Trim()
}

function Get-ManifestVersion {
    param (
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$Source
    )

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $Content,
        [ref]$tokens,
        [ref]$parseErrors
    )

    if ($parseErrors.Count -gt 0) {
        throw "Unable to parse module manifest '$Source': $($parseErrors[0].Message)"
    }

    $hashtableAst = $ast.Find(
        { param ($node) $node -is [System.Management.Automation.Language.HashtableAst] },
        $false
    )

    if (-not $hashtableAst) {
        throw "Module manifest '$Source' does not contain a data hashtable."
    }

    try {
        $manifest = $hashtableAst.SafeGetValue()
        [version]$manifest.ModuleVersion
    } catch {
        throw "Unable to read ModuleVersion from '$Source': $($_.Exception.Message)"
    }
}

$baseCommit = Resolve-RepositoryCommit -Ref $BaseRef
$headCommit = Resolve-RepositoryCommit -Ref $HeadRef
$changedPaths = @(Invoke-RepositoryGit -ArgumentList @(
        'diff',
        '--name-only',
        '--no-renames',
        "$baseCommit...$headCommit",
        '--'
    ))

$moduleDirectories = @(Get-ChildItem -LiteralPath $repositoryPath -Directory |
    Where-Object {
        $_.Name -eq 'OMG.PSUtilities' -or
        $_.Name -like 'OMG.PSUtilities.*'
    } |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "$($_.Name).psd1") } |
    Sort-Object Name)

if ($moduleDirectories.Count -eq 0) {
    throw "No publishable PowerShell modules were found in '$repositoryPath'."
}

$changedModules = [System.Collections.Generic.List[string]]::new()
$versionErrors = [System.Collections.Generic.List[string]]::new()

foreach ($moduleDirectory in $moduleDirectories) {
    $moduleName = $moduleDirectory.Name
    $modulePrefix = "$moduleName/"
    $publishableChanges = @($changedPaths | Where-Object {
            if (-not $_.StartsWith($modulePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $false
            }

            $moduleRelativePath = $_.Substring($modulePrefix.Length)
            $segments = @($moduleRelativePath -split '/')
            $fileName = $segments[-1]

            '.github' -notin $segments -and
            $fileName -ne 'plasterManifest.xml' -and
            $fileName -notlike '*--wip.ps1'
        })

    if ($publishableChanges.Count -eq 0) {
        continue
    }

    $changedModules.Add($moduleName)
    $manifestRelativePath = "$moduleName/$moduleName.psd1"
    $baseManifestContent = (Invoke-RepositoryGit -ArgumentList @(
            'show',
            "${baseCommit}:$manifestRelativePath"
        )) -join "`n"
    $currentManifestPath = Join-Path $moduleDirectory.FullName "$moduleName.psd1"
    $baseVersion = Get-ManifestVersion -Content $baseManifestContent -Source "$BaseRef`:$manifestRelativePath"
    $currentVersion = Get-ManifestVersion -Content (Get-Content -LiteralPath $currentManifestPath -Raw) -Source $currentManifestPath

    if ($currentVersion -eq $baseVersion) {
        $versionErrors.Add("[$moduleName] Publishable content changed, but ModuleVersion remains $currentVersion.")
    } elseif ($currentVersion -lt $baseVersion) {
        $versionErrors.Add("[$moduleName] Publishable content changed, but ModuleVersion decreased from $baseVersion to $currentVersion.")
    }
}

if ($versionErrors.Count -gt 0) {
    throw "Module version validation failed:`n - $($versionErrors -join "`n - ")"
}

[PSCustomObject]@{
    BaseRef       = $BaseRef
    HeadRef       = $HeadRef
    ModulesChanged = @($changedModules)
    Status        = 'Passed'
}
