function Update-PSUModuleVersion {
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Major", "Minor", "Patch")]
        [string]$Increment,

        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    $modulePath = Join-Path $env:BASE_MODULE_PATH $ModuleName

    if (-not (Test-Path $modulePath)) {
        Write-Error "Module path not found: $modulePath"
        return
    }

    $psd1Path = Get-ChildItem -Path $modulePath -Filter *.psd1 | Select-Object -First 1
    if (-not $psd1Path) {
        Write-Error "Could not find .psd1 in $modulePath"
        return
    }

    $content = Get-Content $psd1Path.FullName
    $currentVersionLine = $content | Where-Object { $_ -match 'ModuleVersion\s*=' } | Select-Object -First 1
    $currentVersion = $currentVersionLine -replace '.*=\s*["'']?', '' -replace '["'']', ''

    if (-not $currentVersion -or $currentVersion -notmatch '^\d+\.\d+\.\d+$') {
        Write-Error "Invalid or missing version in $($psd1Path.Name)"
        return
    }

    # Split and bump version
    $versionParts = $currentVersion -split '\.'
    [int]$major = $versionParts[0]
    [int]$minor = $versionParts[1]
    [int]$patch = $versionParts[2]

    switch ($Increment) {
        "Major" { $major++; $minor = 0; $patch = 0 }
        "Minor" { $minor++; $patch = 0 }
        "Patch" { $patch++ }
    }

    $newVersion = "$major.$minor.$patch"
    Write-Host "Attempting to update module version from $currentVersion to $newVersion..." -ForegroundColor Cyan

    # 🔧 Update .psd1
    $newContent = $content -replace "(ModuleVersion\s*=\s*)['""][^'""]+['""]", "`$1'$newVersion'"
    Set-Content -Path $psd1Path.FullName -Value $newContent -Encoding UTF8
    Write-Host "Updated $newVersion in $($psd1Path.Name)" -ForegroundColor Green

    # 🔧 Update plasterManifest.xml
    $plasterManifestPath = Join-Path $modulePath "plasterManifest.xml"
    if (Test-Path $plasterManifestPath) {
        $xml = [xml](Get-Content $plasterManifestPath)
        $xml.plasterManifest.metadata.version = $newVersion
        $xml.Save($plasterManifestPath)
        Write-Host "Updated $newVersion in $plasterManifestPath " -ForegroundColor DarkCyan
    } else {
        Write-Warning "plasterManifest.xml not found in $ModuleName — skipping update."
    }

    return $newVersion
}