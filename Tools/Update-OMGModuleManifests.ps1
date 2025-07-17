function Reset-OMGModuleManifests {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    $modulePath = Join-Path $env:BASE_MODULE_PATH $ModuleName

    if (-not (Test-Path $modulePath)) {
        Write-Warning "Module path not found: $modulePath"
        return
    }

    $publicPath = Join-Path $modulePath "Public"
    $psm1Path = Join-Path $modulePath "$ModuleName.psm1"
    $psd1Path = Join-Path $modulePath "$ModuleName.psd1"

    if (-not (Test-Path $publicPath)) {
        Write-Warning "Missing Public folder in $ModuleName"
        return
    }

    # Get all public function names
    $publicFunctions = Get-ChildItem -Path $publicPath -Filter *.ps1 -Recurse |
        Select-Object -ExpandProperty BaseName

    if (-not $publicFunctions) {
        Write-Warning "No functions found in $publicPath"
        return
    }

    # Generate .psm1 content
    $psm1Content = @"
# Load private functions
Get-ChildItem -Path "`$PSScriptRoot\Private\*.ps1" -Recurse | ForEach-Object {
    try {
        . `$(`$_.FullName)
    } catch {
        Write-Error "Failed to load private function `$(`$_.FullName): `$(`$_)"
    }
}

# Load public functions
Get-ChildItem -Path "`$PSScriptRoot\Public\*.ps1" -Recurse | ForEach-Object {
    try {
        . `$(`$_.FullName)
    } catch {
        Write-Error "Failed to load public function `$(`$_.FullName): `$(`$_)"
    }
}

# Export public functions
`$PublicFunctions = @(
$(@($publicFunctions | ForEach-Object { "    '$_'" }) -join "`n")
)

Export-ModuleMember -Function `$PublicFunctions
"@

    $psm1Content | Set-Content -Path $psm1Path -Encoding UTF8
    Write-Host "UPDATED: $ModuleName.psm1" -ForegroundColor Green

    # Patch .psd1 → FunctionsToExport
    if (Test-Path $psd1Path) {
        $psd1 = Get-Content $psd1Path
        $newExport = "FunctionsToExport = @(" + (($publicFunctions | ForEach-Object { "'$_'" } ) -join ", ") + ")"

        if ($psd1 -match 'FunctionsToExport\s*=\s*@\([^\)]*\)') {
            $psd1 = $psd1 -replace 'FunctionsToExport\s*=\s*@\([^\)]*\)', $newExport
        } else {
            $psd1 += "`n$newExport"
        }

        $psd1 | Set-Content -Path $psd1Path -Encoding UTF8
        Write-Host "PATCHED: $ModuleName.psd1" -ForegroundColor Green
    } else {
        Write-Warning "$ModuleName.psd1 not found"
    }
}
