<#
═══════════════════════════════════════════════════════════════════════════════
  TEST SCRIPT: Test Azure Function Proxy Locally or in Azure
═══════════════════════════════════════════════════════════════════════════════

PURPOSE:
  Test the OpenAI proxy function to ensure it works correctly before using it
  in your PowerShell module.

USAGE:
  # Test locally (if running Azure Functions locally)
  .\Test-ProxyFunction.ps1 -ProxyUrl "http://localhost:7071/api/ProxyOpenAI"

  # Test in Azure
  .\Test-ProxyFunction.ps1 -ProxyUrl "https://psu-openai-proxy.azurewebsites.net/api/ProxyOpenAI?code=YOUR_FUNCTION_KEY"

═══════════════════════════════════════════════════════════════════════════════
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ProxyUrl,

    [Parameter()]
    [string]$TestPrompt = "Explain Azure OpenAI in one sentence"
)

Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Testing OpenAI Proxy Function" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "Proxy URL: $ProxyUrl" -ForegroundColor Gray
Write-Host "Test Prompt: $TestPrompt`n" -ForegroundColor Gray

$requestBody = @{
    Prompt = $TestPrompt
    MaxTokens = 100
    Temperature = 0.7
} | ConvertTo-Json

Write-Host "Sending request..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod `
        -Method Post `
        -Uri $ProxyUrl `
        -Body $requestBody `
        -ContentType 'application/json' `
        -TimeoutSec 60

    Write-Host "`n✅ SUCCESS! Proxy is working correctly.`n" -ForegroundColor Green

    Write-Host "Response:" -ForegroundColor Cyan
    Write-Host $response.response -ForegroundColor White

    if ($response.usage) {
        Write-Host "`nToken Usage:" -ForegroundColor Cyan
        Write-Host "  Prompt Tokens: $($response.usage.prompt_tokens)" -ForegroundColor Gray
        Write-Host "  Completion Tokens: $($response.usage.completion_tokens)" -ForegroundColor Gray
        Write-Host "  Total Tokens: $($response.usage.total_tokens)" -ForegroundColor Gray
    }

    Write-Host "`nModel: $($response.model)`n" -ForegroundColor Cyan

} catch {
    Write-Host "`n❌ ERROR: Proxy test failed`n" -ForegroundColor Red
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red

    if ($_.ErrorDetails.Message) {
        Write-Host "`nResponse from server:" -ForegroundColor Yellow
        Write-Host $_.ErrorDetails.Message -ForegroundColor Red
    }
}
