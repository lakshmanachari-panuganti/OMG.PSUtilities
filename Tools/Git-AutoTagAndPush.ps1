param (
    [Parameter(Mandatory)]
    [string]$ModulePath  # Ex: C:\repos\OMG.PSUtilities\OMG.PSUtilities.Core
)

# Get current version from psd1
$psd1Path = Get-ChildItem -Path $ModulePath -Filter *.psd1 | Select-Object -First 1
$versionLine = Get-Content $psd1Path.FullName | Where-Object { $_ -match 'ModuleVersion\s*=' }
$version = ($versionLine -split '=')[1].Trim().Trim("'\"")

# Get module name
$moduleName = Split-Path $ModulePath -Leaf
$tagName = "$moduleName-v$version"

# Git commit and tag
Set-Location $ModulePath
git add .
git commit -m "Release $tagName"
git tag $tagName
git push origin main
git push origin $tagName

Write-Host "✅ Tagged and pushed $tagName" -ForegroundColor Green
