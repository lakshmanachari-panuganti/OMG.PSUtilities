$manifest = Import-PowerShellDataFile -Path "c:\repos\OMG.PSUtilities\OMG.PSUtilities.AzureDevOps\OMG.PSUtilities.AzureDevOps.psd1"
$exportedFunctions = $manifest.FunctionsToExport | Sort-Object

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PARAMETER ORDERING VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$results = @()
foreach ($funcName in $exportedFunctions) {
    $file = "c:\repos\OMG.PSUtilities\OMG.PSUtilities.AzureDevOps\Public\$funcName.ps1"
    
    if (Test-Path $file) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$null)
        $funcDef = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | Select-Object -First 1
        
        if ($funcDef -and $funcDef.Body.ParamBlock) {
            $params = $funcDef.Body.ParamBlock.Parameters
            $paramNames = $params | ForEach-Object { $_.Name.VariablePath.UserPath }
            
            $orgIndex = [array]::IndexOf($paramNames, 'Organization')
            $patIndex = [array]::IndexOf($paramNames, 'PAT')
            $lastIndex = $paramNames.Count - 1
            $secondLastIndex = $paramNames.Count - 2
            
            $isCorrect = ($orgIndex -eq $secondLastIndex) -and ($patIndex -eq $lastIndex)
            
            $results += [PSCustomObject]@{
                Function = $funcName
                TotalParams = $paramNames.Count
                OrgPosition = if ($orgIndex -ge 0) { "$orgIndex" } else { "N/A" }
                PATPosition = if ($patIndex -ge 0) { "$patIndex" } else { "N/A" }
                ExpectedOrg = $secondLastIndex
                ExpectedPAT = $lastIndex
                Status = if ($isCorrect) { "✅" } else { "❌" }
            }
        }
    }
}

$results | Format-Table -AutoSize

$correct = ($results | Where-Object { $_.Status -eq "✅" }).Count
$total = $results.Count

Write-Host "`n========================================" -ForegroundColor Cyan
if ($correct -eq $total) {
    Write-Host "✅ RESULT: $correct/$total CORRECT" -ForegroundColor Green
} else {
    Write-Host "❌ RESULT: $correct/$total CORRECT" -ForegroundColor Red
    Write-Host "`nFunctions needing correction:" -ForegroundColor Yellow
    $results | Where-Object { $_.Status -eq "❌" } | ForEach-Object { Write-Host "  - $($_.Function)" -ForegroundColor Red }
}
Write-Host "========================================`n" -ForegroundColor Cyan
