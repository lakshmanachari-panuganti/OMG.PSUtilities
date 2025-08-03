# Check environment variables if not exist ask for create
@(
    '$env:BASE_MODULE_PATH'
    '$env:API_KEY_GEMINI'
    '$env:API_KEY_CLAUDE'
    '$env:API_KEY_OPENAI'
    '$env:API_KEY_PERPLEXITY'
    '$env:API_KEY_PSGALLERY'
).foreach({
    $envVarName = $_
    $envVarValue = Invoke-Expression $envVarName

    if([string]::IsNullOrEmpty($envVarValue) -or [string]::IsNullOrWhiteSpace($envVarValue)){
        $readHost = $null
        $readHost = Read-Host "The variable $envVarName is not set or empty. Please enter a value or press Enter to skip."
        
        If(-not [string]::IsNullOrEmpty($readHost) -or -not [string]::IsNullOrWhiteSpace($readHost)){
            Set-PSUUserEnvironmentVariable -Name $($envVarName.replace('$env:','')) -Value $readHost
        }
    } else{
        Write-Host "The variable $envVarName is already set! skipping..." -ForegroundColor Green
    }
})

# Initiate
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

# Build Module locally with Reset-OMGModuleManifests (Reset-OMGModuleManifests is built in Build-OMGModuleLocally)
Get-OMGModules | Build-OMGModuleLocally
# NOTE: Increment of the module version is required when it is publishing to PSGallery!