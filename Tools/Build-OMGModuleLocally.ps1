function Build-OMGModuleLocally {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName  # Example: OMG.PSUtilities.Core
    )

    # Resolve base path dynamically
    $basePath = Split-Path -Parent $PSScriptRoot
    $modulePath = Join-Path $basePath $ModuleName
    $psd1Path = Join-Path $modulePath "$ModuleName.psd1"
    
    if (-not (Test-Path $psd1Path)) {
        Write-Error "Module manifest not found: $psd1Path"
        return
    }

    # Remove the module if already loaded (base name only)
    $existingModule = Get-Module | Where-Object { $_.Name -eq $ModuleName}
    if ($existingModule) {
        Write-Host "Removing previously loaded module '$ModuleName'" -ForegroundColor Yellow
        $existingModule | Remove-Module -Force -ErrorAction SilentlyContinue
    }

    # Import with a _temp prefix so functions don't clash
    try {
        Import-Module $psd1Path -Force -Verbose -ErrorAction Stop
        Write-Host "✅ Imported module locally '$ModuleName'" -ForegroundColor Green
    } catch {
        Write-Error "Failed to import module: $_"
    }
}