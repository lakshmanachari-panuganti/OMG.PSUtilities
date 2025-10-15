# Quick Validation Script
# Run this first to ensure everything is ready for the comprehensive test

Write-Host "=== Pre-Test Validation ===" -ForegroundColor Cyan
Write-Host ""

$validationPassed = $true

# 1. Check PowerShell Version
Write-Host "1. PowerShell Version Check" -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
    Write-Host "   ✓ PowerShell $psVersion - OK" -ForegroundColor Green
} else {
    Write-Host "   ✗ PowerShell $psVersion - Need 5.1 or later" -ForegroundColor Red
    $validationPassed = $false
}

# 2. Check Environment Variables
Write-Host "`n2. Environment Variables" -ForegroundColor Yellow
if ($env:ORGANIZATION) {
    Write-Host "   ✓ ORGANIZATION = $env:ORGANIZATION" -ForegroundColor Green
} else {
    Write-Host "   ✗ ORGANIZATION not set" -ForegroundColor Red
    Write-Host "      Run: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value 'Lakshmanachari'" -ForegroundColor Gray
    $validationPassed = $false
}

if ($env:PAT) {
    Write-Host "   ✓ PAT = $($env:PAT.Substring(0,3))... (Length: $($env:PAT.Length))" -ForegroundColor Green
} else {
    Write-Host "   ✗ PAT not set" -ForegroundColor Red
    Write-Host "      Run: Set-PSUUserEnvironmentVariable -Name 'PAT' -Value '<your_token>'" -ForegroundColor Gray
    $validationPassed = $false
}

# 3. Check Module File Exists
Write-Host "`n3. Module File Check" -ForegroundColor Yellow
$modulePath = ".\OMG.PSUtilities.AzureDevOps\OMG.PSUtilities.AzureDevOps.psm1"
if (Test-Path $modulePath) {
    Write-Host "   ✓ Module file found: $modulePath" -ForegroundColor Green
} else {
    Write-Host "   ✗ Module file not found: $modulePath" -ForegroundColor Red
    Write-Host "      Make sure you're in the root of OMG.PSUtilities repo" -ForegroundColor Gray
    $validationPassed = $false
}

# 4. Try to import module
Write-Host "`n4. Module Import Test" -ForegroundColor Yellow
try {
    Import-Module $modulePath -Force -ErrorAction Stop
    $module = Get-Module OMG.PSUtilities.AzureDevOps
    Write-Host "   ✓ Module imported successfully" -ForegroundColor Green
    Write-Host "      Version: $($module.Version)" -ForegroundColor Gray
    Write-Host "      Functions: $($module.ExportedFunctions.Count)" -ForegroundColor Gray
} catch {
    Write-Host "   ✗ Module import failed: $($_.Exception.Message)" -ForegroundColor Red
    $validationPassed = $false
}

# 5. Test Azure DevOps Connectivity
Write-Host "`n5. Azure DevOps Connectivity Test" -ForegroundColor Yellow
if ($env:ORGANIZATION -and $env:PAT) {
    try {
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$env:PAT"))
        $headers = @{
            Authorization = "Basic $base64AuthInfo"
        }
        
        $testUri = "https://dev.azure.com/$env:ORGANIZATION/_apis/projects?api-version=7.1"
        $response = Invoke-RestMethod -Uri $testUri -Headers $headers -Method Get -ErrorAction Stop
        
        Write-Host "   ✓ Successfully connected to Azure DevOps" -ForegroundColor Green
        Write-Host "      Projects found: $($response.count)" -ForegroundColor Gray
        
        # Check for OMG.PSUtilities project
        $targetProject = $response.value | Where-Object { $_.name -eq 'OMG.PSUtilities' }
        if ($targetProject) {
            Write-Host "   ✓ Found project 'OMG.PSUtilities'" -ForegroundColor Green
        } else {
            Write-Host "   ⚠ Project 'OMG.PSUtilities' not found" -ForegroundColor Yellow
            Write-Host "      Available projects: $($response.value.name -join ', ')" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "   ✗ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
        $validationPassed = $false
    }
}

# 6. Check for Test-Repo1
Write-Host "`n6. Test Repository Check" -ForegroundColor Yellow
if ($env:ORGANIZATION -and $env:PAT) {
    try {
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$env:PAT"))
        $headers = @{
            Authorization = "Basic $base64AuthInfo"
        }
        
        $repoUri = "https://dev.azure.com/$env:ORGANIZATION/OMG.PSUtilities/_apis/git/repositories?api-version=7.1"
        $repos = Invoke-RestMethod -Uri $repoUri -Headers $headers -Method Get -ErrorAction Stop
        
        $testRepo = $repos.value | Where-Object { $_.name -eq 'Test-Repo1' }
        if ($testRepo) {
            Write-Host "   ✓ Found repository 'Test-Repo1'" -ForegroundColor Green
            Write-Host "      ID: $($testRepo.id)" -ForegroundColor Gray
            Write-Host "      URL: $($testRepo.webUrl)" -ForegroundColor Gray
        } else {
            Write-Host "   ⚠ Repository 'Test-Repo1' not found" -ForegroundColor Yellow
            Write-Host "      Available repositories: $($repos.value.name -join ', ')" -ForegroundColor Gray
            Write-Host "      The test will work but some tests may be skipped" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "   ✗ Repository check failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 7. Check ThreadJob module (optional for parallel processing)
Write-Host "`n7. ThreadJob Module Check (Optional)" -ForegroundColor Yellow
if (Get-Module -ListAvailable -Name ThreadJob) {
    Write-Host "   ✓ ThreadJob module available - parallel processing enabled" -ForegroundColor Green
} else {
    Write-Host "   ⚠ ThreadJob module not installed - will use sequential processing" -ForegroundColor Yellow
    Write-Host "      Install with: Install-Module ThreadJob -Scope CurrentUser" -ForegroundColor Gray
}

# 8. Check write permissions in script folder
Write-Host "`n8. File Write Permission Check" -ForegroundColor Yellow
try {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $testFile = Join-Path $scriptPath ".validation-test-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
    "test" | Out-File $testFile -ErrorAction Stop
    Remove-Item $testFile -ErrorAction Stop
    Write-Host "   ✓ Can write to script folder" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Cannot write to script folder: $($_.Exception.Message)" -ForegroundColor Red
    $validationPassed = $false
}

# Final Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
if ($validationPassed) {
    Write-Host "✅ VALIDATION PASSED - Ready to run comprehensive tests!" -ForegroundColor Green
    Write-Host "`nRun the comprehensive test suite with:" -ForegroundColor White
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    Write-Host "   $scriptPath\Test-AzureDevOps-Comprehensive.ps1" -ForegroundColor Cyan
    Write-Host "`nOr with verbose output:" -ForegroundColor White
    Write-Host "   $scriptPath\Test-AzureDevOps-Comprehensive.ps1 -VerboseOutput" -ForegroundColor Cyan
} else {
    Write-Host "❌ VALIDATION FAILED - Please fix the issues above" -ForegroundColor Red
    Write-Host "`nCommon fixes:" -ForegroundColor White
    Write-Host "   1. Set environment variables using Set-PSUUserEnvironmentVariable" -ForegroundColor Gray
    Write-Host "   2. Ensure you're in the OMG.PSUtilities repo root folder" -ForegroundColor Gray
    Write-Host "   3. Check your PAT has the required permissions" -ForegroundColor Gray
}
Write-Host ("=" * 60) -ForegroundColor Cyan

# Return validation status
return $validationPassed
