function Invoke-GitAutoTagAndPush {
    param (
        [Parameter(Mandatory)]
        [string]$ModuleName  # Example: OMG.PSUtilities.Core
    )

    $modulePath = Join-Path $env:BASE_MODULE_PATH $ModuleName

    if (-not (Test-Path $modulePath)) {
        Write-Error "Module path not found: $modulePath"
        return
    }

    $psd1Path = Get-ChildItem -Path $modulePath -Filter *.psd1 | Select-Object -First 1
    if (-not $psd1Path) {
        Write-Error ".psd1 file not found in $modulePath"
        return
    }

    # Get version from .psd1
    $versionLine = Get-Content $psd1Path.FullName | Where-Object { $_ -match 'ModuleVersion\s*=' }
    $version = "$(($versionLine -split '=')[1].Trim().Trim("'\""))"

    # Tag format: OMG.PSUtilities.Core-v1.0.0
    $tagName = "$($ModuleName + '-v' + $version)"

    Set-Location $modulePath

    # Safety Check: If tag already exists, skip
    if (git tag --list $tagName) {
        Write-Warning "Tag '$tagName' already exists. Skipping."
        return
    }

    # Optional: Warn for uncommitted changes
    if (git status --porcelain) {
        $Proceed = Read-Host "Uncommitted changes detected, shall I proceed anyway (Y/N)..."
        if ($Proceed -notin @('Y', 'y')) {
            Write-Host "Aborting due to uncommitted changes." -ForegroundColor Yellow
            return
        }
    }

    # Commit, tag, and push
    git add .
    git commit -m "Release $tagName"
    git tag $tagName

    $currentBranch = git rev-parse --abbrev-ref HEAD
    git push origin $currentBranch
    git push origin $tagName

    Write-Host "Tagged and pushed $tagName" -ForegroundColor Green
}
