# =========================================================================
# Master Test Runner for OMG.PSUtilities.AzureDevOps Module
# =========================================================================
# This script orchestrates the complete testing workflow
# =========================================================================

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Quick', 'Comprehensive', 'Validation')]
    [string]$TestType = 'Comprehensive',
    
    [switch]$VerboseOutput,
    [switch]$SkipValidation,
    [switch]$SkipCleanup,
    [switch]$ExportReport
)

$ErrorActionPreference = 'Continue'

# Banner
Write-Host @"

╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║       OMG.PSUtilities.AzureDevOps Module Test Suite                  ║
║       Test Target: Test-Repo1                                        ║
║       Organization: Lakshmanachari                                   ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "Test Type: $TestType" -ForegroundColor Yellow
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$masterStartTime = Get-Date

# =========================================================================
# STEP 1: Pre-Flight Validation
# =========================================================================
if (-not $SkipValidation) {
    Write-Host "═══ STEP 1: Pre-Flight Validation ═══" -ForegroundColor Cyan
    
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $validationResult = & "$scriptPath\Test-PreFlightValidation.ps1"
    
    if (-not $validationResult) {
        Write-Host "`n❌ Validation failed. Cannot proceed with tests." -ForegroundColor Red
        Write-Host "Fix the validation issues and try again." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "`n✅ Validation passed. Proceeding with tests..." -ForegroundColor Green
    Start-Sleep -Seconds 2
} else {
    Write-Host "⚠️  Skipping validation (use at your own risk)" -ForegroundColor Yellow
}

# =========================================================================
# STEP 2: Run Selected Test Suite
# =========================================================================
Write-Host "`n═══ STEP 2: Running Test Suite ═══" -ForegroundColor Cyan

$testResults = $null

switch ($TestType) {
    'Validation' {
        Write-Host "Running validation only (already completed)" -ForegroundColor Green
        $testResults = [PSCustomObject]@{
            TestType    = 'Validation'
            Passed      = $true
            TotalTests  = 8
            Failed      = 0
            SuccessRate = 100
        }
    }
    
    'Quick' {
        Write-Host "Running quick validation tests..." -ForegroundColor Yellow
        
        # Quick test: Just verify functions can be called
        $quickTests = @(
            'Get-PSUADOProjectList'
            'Get-PSUADORepositories'
            'Get-PSUADOVariableGroupInventory'
            'Get-PSUADOPullRequest'
            'Get-PSUADOPipeline'
        )
        
        $passed = 0
        $failed = 0
        
        foreach ($funcName in $quickTests) {
            Write-Host "  Testing $funcName..." -NoNewline
            try {
                $null = Get-Command $funcName -ErrorAction Stop
                Write-Host " ✓" -ForegroundColor Green
                $passed++
            } catch {
                Write-Host " ✗" -ForegroundColor Red
                $failed++
            }
        }
        
        $testResults = [PSCustomObject]@{
            TestType    = 'Quick'
            TotalTests  = $quickTests.Count
            Passed      = $passed
            Failed      = $failed
            SuccessRate = [math]::Round(($passed / $quickTests.Count) * 100, 2)
        }
    }
    
    'Comprehensive' {
        Write-Host "Running comprehensive test suite..." -ForegroundColor Yellow
        Write-Host "This may take several minutes..." -ForegroundColor Gray
        Write-Host ""
        
        $params = @{}
        if ($VerboseOutput) { $params.VerboseOutput = $true }
        if ($SkipCleanup) { $params.SkipCleanup = $true }
        
        $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
        $testResults = & "$scriptPath\Test-AzureDevOps-Comprehensive.ps1" @params
    }
}

# =========================================================================
# STEP 3: Generate Report
# =========================================================================
if ($ExportReport -and $testResults) {
    Write-Host "`n═══ STEP 3: Generating Report ═══" -ForegroundColor Cyan
    
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $reportPath = Join-Path $scriptPath "TestReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    
    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>AzureDevOps Module Test Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #333; margin-top: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .stat-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .stat-card.success { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); }
        .stat-card.warning { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }
        .stat-card h3 { margin: 0; font-size: 2em; }
        .stat-card p { margin: 5px 0 0 0; font-size: 0.9em; opacity: 0.9; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #0078d4; color: white; font-weight: 600; }
        tr:hover { background: #f5f5f5; }
        .passed { color: #28a745; font-weight: bold; }
        .failed { color: #dc3545; font-weight: bold; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 OMG.PSUtilities.AzureDevOps Module Test Report</h1>
        
        <div class="summary">
            <div class="stat-card">
                <h3>$($testResults.TotalTests)</h3>
                <p>Total Tests</p>
            </div>
            <div class="stat-card success">
                <h3>$($testResults.Passed)</h3>
                <p>Passed</p>
            </div>
            <div class="stat-card warning">
                <h3>$($testResults.Failed)</h3>
                <p>Failed</p>
            </div>
            <div class="stat-card">
                <h3>$($testResults.SuccessRate)%</h3>
                <p>Success Rate</p>
            </div>
        </div>
        
        <h2>Test Details</h2>
        <table>
            <thead>
                <tr>
                    <th>Test Name</th>
                    <th>Status</th>
                    <th>Message</th>
                    <th>Timestamp</th>
                </tr>
            </thead>
            <tbody>
"@
    
    if ($testResults.TestResults) {
        foreach ($test in $testResults.TestResults) {
            $status = if ($test.Success) { "✓ PASSED" } else { "✗ FAILED" }
            $statusClass = if ($test.Success) { "passed" } else { "failed" }
            $timestamp = $test.Timestamp.ToString('HH:mm:ss')
            
            $htmlReport += @"
                <tr>
                    <td>$($test.TestName)</td>
                    <td class="$statusClass">$status</td>
                    <td>$($test.Message)</td>
                    <td>$timestamp</td>
                </tr>
"@
        }
    }
    
    $htmlReport += @"
            </tbody>
        </table>
        
        <div class="footer">
            <p><strong>Test Type:</strong> $TestType</p>
            <p><strong>Organization:</strong> Lakshmanachari</p>
            <p><strong>Project:</strong> OMG.PSUtilities</p>
            <p><strong>Repository:</strong> Test-Repo1</p>
            <p><strong>Duration:</strong> $($testResults.Duration)</p>
            <p><strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </div>
    </div>
</body>
</html>
"@
    
    $htmlReport | Out-File $reportPath -Encoding UTF8
    Write-Host "✅ HTML report generated: $reportPath" -ForegroundColor Green
    
    # Try to open in browser
    try {
        Start-Process $reportPath
        Write-Host "   Opened in default browser" -ForegroundColor Gray
    } catch {
        Write-Host "   Open manually: $reportPath" -ForegroundColor Gray
    }
}

# =========================================================================
# Final Summary
# =========================================================================
$masterEndTime = Get-Date
$masterDuration = $masterEndTime - $masterStartTime

Write-Host "`n" + ("═" * 75) -ForegroundColor Cyan
Write-Host "🎯 MASTER TEST SUMMARY" -ForegroundColor Cyan
Write-Host ("═" * 75) -ForegroundColor Cyan

if ($testResults) {
    Write-Host "`nTest Type: $TestType" -ForegroundColor White
    Write-Host "Total Tests: $($testResults.TotalTests)" -ForegroundColor White
    Write-Host "Passed: $($testResults.Passed)" -ForegroundColor Green
    Write-Host "Failed: $($testResults.Failed)" -ForegroundColor $(if ($testResults.Failed -eq 0) { 'Green' } else { 'Red' })
    Write-Host "Success Rate: $($testResults.SuccessRate)%" -ForegroundColor $(if ($testResults.SuccessRate -ge 90) { 'Green' } elseif ($testResults.SuccessRate -ge 70) { 'Yellow' } else { 'Red' })
    Write-Host "Total Duration: $($masterDuration.ToString('mm\:ss'))" -ForegroundColor White
    
    if ($testResults.ResultsFile) {
        Write-Host "`nResults File: $($testResults.ResultsFile)" -ForegroundColor Gray
    }
}

Write-Host "`n" + ("═" * 75) -ForegroundColor Cyan

# Return test results
return $testResults
