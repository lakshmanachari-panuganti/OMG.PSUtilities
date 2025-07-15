function Update-OMGModuleManifests {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    # Root of your modules
    $basePath = Split-Path -Parent $PSScriptRoot
    $modulePath = Join-Path $basePath $ModuleName

    if (-not (Test-Path $modulePath)) {
        Write-Warning "❌ Module path not found: $modulePath"
        return
    }

    $publicPath = Join-Path $modulePath "Public"
    $psm1Path   = Join-Path $modulePath "$ModuleName.psm1"
    $psd1Path   = Join-Path $modulePath "$ModuleName.psd1"

    if (-not (Test-Path $publicPath)) {
        Write-Warning "❌ Missing Public folder in $ModuleName"
        return
    }

    # Get all public functions
    $functions = Get-ChildItem -Path $publicPath -Filter *.ps1 | Select-Object -ExpandProperty BaseName

    if (-not $functions) {
        Write-Warning "⚠️ No functions found in $publicPath"
        return
    }

    # 1️⃣ Create .psm1 content
    $psm1Content = @"
# Auto-generated .psm1 for $ModuleName
# Loaded functions:
`$PublicFunctions = @(
$(@($functions | ForEach-Object { "    '$_'" }) -join "`n")
)

foreach (`$func in `$PublicFunctions) {
    . "`$PSScriptRoot\Public\$func.ps1"
}

Export-ModuleMember -Function `$PublicFunctions
"@

    $psm1Content | Set-Content -Path $psm1Path -Encoding UTF8
    Write-Host "✅ Updated: $ModuleName.psm1" -ForegroundColor Green

    # 2️⃣ Update .psd1 with FunctionsToExport
    if (Test-Path $psd1Path) {
        $psd1 = Get-Content $psd1Path
        $newExport = "FunctionsToExport = @(" + ($functions | ForEach-Object { "'$_'" } -join ", ") + ")"

        # Use regex replace
        if ($psd1 -match 'FunctionsToExport\s*=\s*@\([^\)]*\)') {
            $psd1 = $psd1 -replace 'FunctionsToExport\s*=\s*@\([^\)]*\)', $newExport
        } else {
            # If FunctionsToExport not found, append it
            $psd1 += "`n$newExport"
        }

        $psd1 | Set-Content -Path $psd1Path -Encoding UTF8
        Write-Host "🔄 Patched: $ModuleName.psd1" -ForegroundColor Cyan
    } else {
        Write-Warning "❌ $ModuleName.psd1 not found"
    }
}
