 
# Mapping of functions to their destination modules
$functionMap = @{
    "Get-PSUInstalledSoftware"      = "Core"
    "Uninstall-PSUInstalledSoftware"= "Core"
    "Get-PSUUserSession"            = "Core"
    "Remove-PSUUserSession"         = "Core"
    "Set-PSUUserEnvironmentVariable"= "Core"
    "Find-PSUFilesContainingText"   = "Core"
    "Get-PSUConnectedWifiInfo"      = "Core"
    "Test-PSUInternetConnection"    = "Core"

    "Invoke-PSUPromptAI"            = "AI"
    "Start-PSUAiChat"               = "AI"

    "Get-PSUAzToken"                = "AzureCore"
    "Test-PSUAzConnection"          = "AzureCore"

    "Get-PSUADOBuildDetails"        = "AzureDevOps"
    "Get-PSUADOPipelineLatestRun"   = "AzureDevOps"

    "New-PSUHTMLReport"             = "Core" 
    "Send-PSUHTMLReport"            = "Core"
    "Send-PSUTeamsMessage"          = "Core"
}

# Source location of existing .ps1 function files (old flat layout)
$sourcePublicFolder = "C:\repos\OMG.PSUtilities-Old\Public"

foreach ($func in $functionMap.Keys) {
    $moduleName = $functionMap[$func]
    $targetModuleFolder = Join-Path $env:BASE_MODULE_PATH "OMG.PSUtilities.$moduleName"
    $targetPublic = Join-Path $targetModuleFolder "Public"

    # Ensure destination exists
    if (-not (Test-Path $targetPublic)) {
        Write-Warning "Missing target: $targetPublic — skipping $func"
        continue
    }

    $sourceFile = Join-Path $sourcePublicFolder "$func.ps1"
    $destFile   = Join-Path $targetPublic "$func.ps1"

    if (Test-Path $sourceFile) {
        Move-Item -Path $sourceFile -Destination $destFile -Force
        Write-Host "Moved $func.ps1 to $targetPublic" -ForegroundColor Green
    } else {
        Write-Warning "File not found: $sourceFile"
    }
}
