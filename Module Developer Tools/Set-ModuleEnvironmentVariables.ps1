$ErrorActionPreference = 'Stop'
if ($null -eq $env:BASE_MODULE_PATH) {
    Write-Host 'Environment variable ''$env:BASE_MODULE_PATH'' is not yet set!' -ForegroundColor Red
    Write-Host "Press Enter to use default 'C:\repos\OMG.PSUtilities', or provide a custom path" -ForegroundColor Red
    $BASE_MODULE_PATH = Read-Host

    if ([string]::IsNullOrWhiteSpace($BASE_MODULE_PATH)) {
        $BASE_MODULE_PATH = 'C:\repos\OMG.PSUtilities'
    }

    Write-Host "Setting BASE_MODULE_PATH to: $BASE_MODULE_PATH" -ForegroundColor Cyan
    
    if (Get-Command Set-PSUUserEnvironmentVariable -ErrorAction SilentlyContinue) {
        Set-PSUUserEnvironmentVariable -Name BASE_MODULE_PATH -Value $BASE_MODULE_PATH
    } else {
        Write-Warning "Set-PSUUserEnvironmentVariable not found. Installing OMG.PSUtilities.Core module to provide the functionality."
        Install-Module -Name OMG.PSUtilities.Core -Scope CurrentUser -Force -Repository PSGallery
        Set-PSUUserEnvironmentVariable -Name BASE_MODULE_PATH -Value $BASE_MODULE_PATH
        Write-Host '$env:BASE_MODULE_PATH ' -NoNewline -ForegroundColor Green
        Write-Host "is successfully set to: $BASE_MODULE_PATH" -ForegroundColor Green
    }
} else {
    Write-Host '$env:BASE_MODULE_PATH ' -NoNewline -ForegroundColor Green
    Write-Host "is already set to: $env:BASE_MODULE_PATH" -ForegroundColor Green
}