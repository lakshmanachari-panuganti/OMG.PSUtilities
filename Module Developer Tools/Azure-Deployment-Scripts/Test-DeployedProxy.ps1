<#
.SYNOPSIS
    Tests deployed Azure Function App and APIM proxy endpoints.

.DESCRIPTION
    This script validates the deployed proxy by sending test requests to either
    the Function App directly or through APIM with rate limiting.

.PARAMETER FunctionUrl
    Direct Function App URL (with function key).

.PARAMETER APIMUrl
    APIM API endpoint URL.

.PARAMETER SubscriptionKey
    APIM subscription key (required when using APIM).

.PARAMETER TestPrompt
    Test prompt to send to Azure OpenAI. Default: "Test deployment"

.PARAMETER MaxTokens
    Maximum tokens for response. Default: 100

.PARAMETER RunMultipleTests
    Run multiple tests to validate rate limiting. Default: $false

.PARAMETER NumberOfTests
    Number of tests to run when RunMultipleTests is true. Default: 5

.EXAMPLE
    # Test Function App directly
    .\Test-DeployedProxy.ps1 -FunctionUrl "https://psu-openai-proxy-1234.azurewebsites.net/api/ProxyOpenAI?code=xxx"

.EXAMPLE
    # Test APIM endpoint
    .\Test-DeployedProxy.ps1 `
        -APIMUrl "https://psu-openai-apim.azure-api.net/openai/ProxyOpenAI" `
        -SubscriptionKey "abc123..."

.EXAMPLE
    # Test rate limiting
    .\Test-DeployedProxy.ps1 `
        -APIMUrl "https://psu-openai-apim.azure-api.net/openai/ProxyOpenAI" `
        -SubscriptionKey "abc123..." `
        -RunMultipleTests `
        -NumberOfTests 10

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 2025-12-05
    Version: 1.0
#>

[CmdletBinding(DefaultParameterSetName = 'FunctionApp')]
param(
    [Parameter(Mandatory, ParameterSetName = 'FunctionApp')]
    [string]$FunctionUrl,

    [Parameter(Mandatory, ParameterSetName = 'APIM')]
    [string]$APIMUrl,

    [Parameter(Mandatory, ParameterSetName = 'APIM')]
    [string]$SubscriptionKey,

    [Parameter()]
    [string]$TestPrompt = "Explain Azure OpenAI in one sentence",

    [Parameter()]
    [int]$MaxTokens = 100,

    [Parameter()]
    [switch]$RunMultipleTests,

    [Parameter()]
    [int]$NumberOfTests = 5
)

# ═══════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n$('─' * 70)" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "$('─' * 70)" -ForegroundColor Cyan
}

function Test-ProxyEndpoint {
    param(
        [string]$Url,
        [hashtable]$Headers,
        [string]$TestNumber = ""
    )

    $requestBody = @{
        Prompt = $TestPrompt
        MaxTokens = $MaxTokens
        Temperature = 0.7
    } | ConvertTo-Json

    $testLabel = if ($TestNumber) { "Test #$TestNumber" } else { "Test" }

    Write-Host "`n[$testLabel] Sending request..." -ForegroundColor Yellow
    Write-Host "  Prompt: $TestPrompt" -ForegroundColor Gray
    Write-Host "  MaxTokens: $MaxTokens" -ForegroundColor Gray

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $response = Invoke-RestMethod `
            -Method Post `
            -Uri $Url `
            -Headers $Headers `
            -Body $requestBody `
            -ContentType 'application/json' `
            -TimeoutSec 60 `
            -ErrorAction Stop

        $stopwatch.Stop()

        Write-Host "`n✅ SUCCESS!" -ForegroundColor Green
        Write-Host "  Response Time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Response:" -ForegroundColor Yellow
        Write-Host "  $($response.response)" -ForegroundColor White
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  Prompt Tokens:     $($response.usage.prompt_tokens)" -ForegroundColor Gray
        Write-Host "  Completion Tokens: $($response.usage.completion_tokens)" -ForegroundColor Gray
        Write-Host "  Total Tokens:      $($response.usage.total_tokens)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Model: $($response.model)" -ForegroundColor Gray

        return @{
            Success = $true
            ResponseTime = $stopwatch.ElapsedMilliseconds
            Tokens = $response.usage.total_tokens
        }

    } catch {
        $stopwatch.Stop()

        $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue

        if ($_.Exception.Response.StatusCode -eq 429) {
            Write-Host "`n⚠️  RATE LIMITED!" -ForegroundColor Yellow
            Write-Host "  This is expected when testing rate limits" -ForegroundColor Gray
            Write-Host "  Error: $($errorDetails.error)" -ForegroundColor Red
        } else {
            Write-Host "`n❌ FAILED!" -ForegroundColor Red
            Write-Host "  Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            
            if ($errorDetails) {
                Write-Host "  Details: $($errorDetails.error)" -ForegroundColor Red
            }
        }

        return @{
            Success = $false
            ResponseTime = $stopwatch.ElapsedMilliseconds
            Error = $_.Exception.Message
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════

Write-Host "`n$('═' * 70)" -ForegroundColor Cyan
Write-Host "AZURE PROXY DEPLOYMENT TEST" -ForegroundColor Cyan
Write-Host "$('═' * 70)" -ForegroundColor Cyan

# Determine endpoint type
if ($PSCmdlet.ParameterSetName -eq 'FunctionApp') {
    Write-Host "`nTesting: Direct Function App" -ForegroundColor Yellow
    Write-Host "URL: $FunctionUrl" -ForegroundColor Gray
    $testUrl = $FunctionUrl
    $headers = @{ 'Content-Type' = 'application/json' }
} else {
    Write-Host "`nTesting: APIM Endpoint" -ForegroundColor Yellow
    Write-Host "URL: $APIMUrl" -ForegroundColor Gray
    Write-Host "Subscription Key: $($SubscriptionKey.Substring(0, 8))..." -ForegroundColor Gray
    $testUrl = $APIMUrl
    $headers = @{
        'Content-Type' = 'application/json'
        'Ocp-Apim-Subscription-Key' = $SubscriptionKey
    }
}

# Run tests
if ($RunMultipleTests) {
    Write-TestHeader "Running Multiple Tests (Rate Limit Validation)"
    
    $results = @()
    
    for ($i = 1; $i -le $NumberOfTests; $i++) {
        $result = Test-ProxyEndpoint -Url $testUrl -Headers $headers -TestNumber $i
        $results += $result
        
        if ($i -lt $NumberOfTests) {
            Write-Host "`nWaiting 2 seconds before next test..." -ForegroundColor Gray
            Start-Sleep -Seconds 2
        }
    }

    # Summary
    Write-Host "`n$('═' * 70)" -ForegroundColor Cyan
    Write-Host "TEST SUMMARY" -ForegroundColor Cyan
    Write-Host "$('═' * 70)" -ForegroundColor Cyan
    
    $successCount = ($results | Where-Object { $_.Success }).Count
    $failureCount = $NumberOfTests - $successCount
    
    Write-Host "`nTotal Tests:    $NumberOfTests" -ForegroundColor White
    Write-Host "Successful:     $successCount" -ForegroundColor Green
    Write-Host "Failed:         $failureCount" -ForegroundColor Red
    
    if ($successCount -gt 0) {
        $avgResponseTime = ($results | Where-Object { $_.Success } | Measure-Object -Property ResponseTime -Average).Average
        $totalTokens = ($results | Where-Object { $_.Success } | Measure-Object -Property Tokens -Sum).Sum
        
        Write-Host "`nAvg Response Time: $([math]::Round($avgResponseTime, 0))ms" -ForegroundColor Gray
        Write-Host "Total Tokens Used: $totalTokens" -ForegroundColor Gray
    }

} else {
    Write-TestHeader "Running Single Test"
    $result = Test-ProxyEndpoint -Url $testUrl -Headers $headers
    
    if ($result.Success) {
        Write-Host "`n$('═' * 70)" -ForegroundColor Green
        Write-Host "DEPLOYMENT VALIDATED SUCCESSFULLY!" -ForegroundColor Green
        Write-Host "$('═' * 70)" -ForegroundColor Green
        Write-Host "`nThe proxy is working correctly and can communicate with Azure OpenAI." -ForegroundColor White
    } else {
        Write-Host "`n$('═' * 70)" -ForegroundColor Red
        Write-Host "TEST FAILED" -ForegroundColor Red
        Write-Host "$('═' * 70)" -ForegroundColor Red
        Write-Host "`nPlease check:" -ForegroundColor Yellow
        Write-Host "  1. Function App environment variables (AZURE_OPENAI_KEY, ENDPOINT, DEPLOYMENT)" -ForegroundColor White
        Write-Host "  2. Network connectivity between Function App and OpenAI endpoint" -ForegroundColor White
        Write-Host "  3. Function App logs in Azure Portal" -ForegroundColor White
    }
}

Write-Host ""
