# initiate
. $($env:BASE_MODULE_PATH + '\Module Developer Tools\Set-ModuleEnvironmentVariables.ps1')

# importing all the Module Developer Tools functions
Write-Host "Importing Module Developer Tools functions..." -ForegroundColor Green
Get-ChildItem -Path ($env:BASE_MODULE_PATH + '\Module Developer Tools\functions') -Filter *.ps1 | ForEach-Object {
    try {
        . $_.FullName
    } catch {
        Write-Error "Failed to load $($_.FullName): $_"
    }
}

# Test-PSUCommentBasedHelp
Test-PSUCommentBasedHelp -ModulePath $env:BASE_MODULE_PATH | Where-Object{$_.HasHelpBlock -eq $false} | ForEach-Object {
    Write-Host "Missing help block in: $($_.File)" -ForegroundColor Red
    Write-Host "Missing tags: $($_.MissingTags)" -ForegroundColor Yellow
    Write-Host ""
}

# Reset-OMGModuleManifests
Get-OMGModules | Reset-OMGModuleManifests -Verbose

# NOTE: Increment of the module version is required when it is publishing to PSGallery!