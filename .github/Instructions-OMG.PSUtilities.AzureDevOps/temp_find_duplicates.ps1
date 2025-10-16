# Script to fix duplicate code in process{} blocks
$functionsToFix = @(
    'Get-PSUADORepoBranchList',
    'Get-PSUADOWorkItem',
    'Invoke-PSUADORepoClone',
    'New-PSUADOBug',
    'New-PSUADOSpike',
    'New-PSUADOTask',
    'New-PSUADOUserStory',
    'New-PSUADOVariable',
    'New-PSUADOVariableGroup',
    'New-PSUADOPullRequest',
    'Set-PSUADOBug',
    'Set-PSUADOSpike',
    'Set-PSUADOTask',
    'Set-PSUADOUserStory',
    'Set-PSUADOVariable',
    'Set-PSUADOVariableGroup'
)

$basePath = "c:\repos\OMG.PSUtilities\OMG.PSUtilities.AzureDevOps\Public"
$fixed = 0
$errors = 0

foreach ($funcName in $functionsToFix) {
    $filePath = Join-Path $basePath "$funcName.ps1"
    
    if (Test-Path $filePath) {
        Write-Host "Processing $funcName..." -ForegroundColor Cyan
        
        $content = Get-Content $filePath -Raw
        
        # Pattern to find duplicate code in process block
        # Look for the specific duplicate validation pattern
        $pattern = @'
(?ms)process \{\s*try \{\s*(?:if \(\$param\.Key -eq 'PAT'\) \{[^}]*\}[^}]*\}[^}]*\}|.*?)# Validate Organization.*?# Validate PAT.*?\$headers = Get-PSUAdoAuthHeader
'@
        
        if ($content -match $pattern) {
            Write-Host "  Found duplicate code pattern" -ForegroundColor Yellow
            $fixed++
        } else {
            Write-Host "  No duplicate pattern found (may already be fixed)" -ForegroundColor Green
        }
    } else {
        Write-Host "File not found: $filePath" -ForegroundColor Red
        $errors++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor White
Write-Host "  Files with duplicates found: $fixed" -ForegroundColor Yellow
Write-Host "  Files not found: $errors" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
