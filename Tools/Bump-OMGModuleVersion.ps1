function Bump-OMGModuleVersion {
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Major", "Minor", "Patch")]
        [string]$Increment,

        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    $basePath = $basePath = Split-Path -Parent $PSScriptRoot
    $modulePath = Join-Path $basePath $ModuleName

    if (-not (Test-Path $modulePath)) {
        Write-Error "❌ Module path not found: $modulePath"
        return
    }

    $psd1Path = Get-ChildItem -Path $modulePath -Filter *.psd1 | Select-Object -First 1
    if (-not $psd1Path) {
        Write-Error "❌ Could not find .psd1 in $modulePath"
        return
    }

    $content = Get-Content $psd1Path.FullName
    $currentVersionLine = $content | Where-Object { $_ -match 'ModuleVersion\s*=' } | Select-Object -First 1
    $currentVersion = $currentVersionLine -replace '.*=\s*["'']?', '' -replace '["'']', ''

    if (-not $currentVersion -or $currentVersion -notmatch '^\d+\.\d+\.\d+$') {
        Write-Error "❌ Invalid or missing version in $($psd1Path.Name)"
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
    Write-Host "🔁 Bumping version from $currentVersion to $newVersion..." -ForegroundColor Cyan

    # Replace version in content
    $newContent = $content -replace "(ModuleVersion\s*=\s*)['""][^'""]+['""]", "`$1'$newVersion'"
    Set-Content -Path $psd1Path.FullName -Value $newContent -Encoding UTF8

    Write-Host "✅ Version bumped to $newVersion in $($psd1Path.Name)" -ForegroundColor Green

    return $newVersion
}
