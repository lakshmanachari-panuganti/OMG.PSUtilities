function Build-OMGModuleLocally {
    param (
        [Parameter(Mandatory)]
        [string]$ModuleName  # Example: OMG.PSUtilities.AI
    )

    $modulePath = Join-Path "C:\repos\OMG.PSUtilities\$ModuleName" "$ModuleName.psd1"

    if (-not (Test-Path $modulePath)) {
        Write-Error "❌ Module not found: $modulePath"
        return
    }

    # Import with a _temp prefix for testing
    Import-Module $modulePath -Prefix _temp -Force -Verbose
    Write-Host "✅ Module '$ModuleName' imported with prefix _temp" -ForegroundColor Green
}