<#
.SYNOPSIS
    Deploys Azure API Management and configures rate limiting for the Function App proxy.

.DESCRIPTION
    This script creates an Azure APIM instance in Consumption tier, imports the deployed
    Function App as an API backend, and configures rate limiting and quota policies.

.PARAMETER SubscriptionId
    Azure subscription ID where APIM will be deployed (same as Function App).

.PARAMETER ResourceGroupName
    Name of the resource group (same as Function App).

.PARAMETER APIMName
    Name for the APIM instance. Must be globally unique.

.PARAMETER PublisherEmail
    Email address for APIM publisher (required for APIM creation).

.PARAMETER PublisherName
    Name of the APIM publisher.

.PARAMETER FunctionAppName
    Name of the deployed Function App to import as API backend.

.PARAMETER APISuffix
    URL suffix for the API. Default: openai

.PARAMETER RateLimitCalls
    Number of calls allowed per hour per subscription. Default: 100

.PARAMETER QuotaCalls
    Number of calls allowed per month per subscription. Default: 50000

.EXAMPLE
    .\Deploy-APIM.ps1 `
        -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
        -ResourceGroupName "rg-psu-openai-proxy" `
        -APIMName "psu-openai-apim" `
        -PublisherEmail "your@email.com" `
        -PublisherName "Your Name" `
        -FunctionAppName "psu-openai-proxy-1234"

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 2025-12-05
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter()]
    [string]$APIMName = "psu-openai-apim-$(Get-Random -Minimum 100 -Maximum 999)",

    [Parameter(Mandatory)]
    [string]$PublisherEmail,

    [Parameter(Mandatory)]
    [string]$PublisherName,

    [Parameter(Mandatory)]
    [string]$FunctionAppName,

    [Parameter()]
    [string]$APISuffix = "openai",

    [Parameter()]
    [int]$RateLimitCalls = 100,

    [Parameter()]
    [int]$QuotaCalls = 50000
)

# ═══════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

function Write-StepHeader {
    param([string]$Message)
    Write-Host "`n$('═' * 70)" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "$('═' * 70)`n" -ForegroundColor Cyan
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 1: Verify Azure login
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 1: Verifying Azure subscription"

az account set --subscription $SubscriptionId

$account = az account show | ConvertFrom-Json
Write-Host "✅ Using subscription: $($account.name)" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
# STEP 2: Verify Function App exists
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 2: Verifying Function App exists"

$functionApp = az functionapp show `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    2>&1 | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Function App not found: $FunctionAppName" -ForegroundColor Red
    Write-Host "   Run Deploy-AzureFunctionApp.ps1 first" -ForegroundColor Yellow
    return
}

Write-Host "✅ Function App found: $FunctionAppName" -ForegroundColor Green
Write-Host "   Location: $($functionApp.location)" -ForegroundColor Gray

# ═══════════════════════════════════════════════════════════════════════════
# STEP 3: Create APIM instance
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 3: Creating APIM instance (Consumption tier)"

Write-Host "⚠️  APIM creation takes 5-10 minutes. Please wait..." -ForegroundColor Yellow
Write-Host ""

az apim create `
    --name $APIMName `
    --resource-group $ResourceGroupName `
    --publisher-email $PublisherEmail `
    --publisher-name $PublisherName `
    --sku-name Consumption `
    --location $functionApp.location `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ APIM instance created: $APIMName" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create APIM instance" -ForegroundColor Red
    return
}

# Wait for APIM to be fully provisioned
Write-Host "Waiting for APIM provisioning to complete..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0

do {
    Start-Sleep -Seconds 10
    $attempt++
    $apimState = az apim show `
        --name $APIMName `
        --resource-group $ResourceGroupName `
        --query provisioningState -o tsv
    
    Write-Host "  Attempt $attempt/$maxAttempts - State: $apimState" -ForegroundColor Gray
} while ($apimState -ne "Succeeded" -and $attempt -lt $maxAttempts)

if ($apimState -ne "Succeeded") {
    Write-Host "⚠️  APIM provisioning timeout. Continue manually." -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 4: Get Function App resource ID
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 4: Preparing to import Function App as API"

$functionAppId = az functionapp show `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --query id -o tsv

Write-Host "Function App Resource ID:" -ForegroundColor Yellow
Write-Host "  $functionAppId" -ForegroundColor Gray

# ═══════════════════════════════════════════════════════════════════════════
# STEP 5: Import Function App into APIM
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 5: Importing Function App as API"

$apiId = "openai-proxy-api"

# Create API from Function App
az apim api create `
    --resource-group $ResourceGroupName `
    --service-name $APIMName `
    --api-id $apiId `
    --path $APISuffix `
    --display-name "OpenAI Proxy API" `
    --protocols https `
    --subscription-required true `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ API created: $apiId" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create API" -ForegroundColor Red
    return
}

# Add operation for ProxyOpenAI function
az apim api operation create `
    --resource-group $ResourceGroupName `
    --service-name $APIMName `
    --api-id $apiId `
    --url-template "/ProxyOpenAI" `
    --method POST `
    --display-name "Proxy OpenAI Request" `
    --description "Forwards prompts to Azure OpenAI via Function App" `
    --output none

Write-Host "✅ API operation created: POST /$APISuffix/ProxyOpenAI" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
# STEP 6: Configure backend (Function App)
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 6: Configuring Function App backend"

$functionUrl = "https://$FunctionAppName.azurewebsites.net/api"

# Create backend
az apim backend create `
    --resource-group $ResourceGroupName `
    --service-name $APIMName `
    --backend-id "function-backend" `
    --url $functionUrl `
    --protocol http `
    --description "Azure Function App Backend" `
    --output none

# Link API to backend
az apim api update `
    --resource-group $ResourceGroupName `
    --service-name $APIMName `
    --api-id $apiId `
    --service-url $functionUrl `
    --output none

Write-Host "✅ Backend configured: $functionUrl" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
# STEP 7: Configure rate limiting policy
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 7: Configuring rate limiting and quota policies"

$policyXml = @"
<policies>
    <inbound>
        <base />
        <check-header name="Ocp-Apim-Subscription-Key" failed-check-httpcode="401" failed-check-error-message="Missing or invalid subscription key" />
        <rate-limit-by-key calls="$RateLimitCalls" renewal-period="3600" counter-key="@(context.Subscription.Id)" />
        <quota-by-key calls="$QuotaCalls" renewal-period="2592000" counter-key="@(context.Subscription.Id)" />
        <set-header name="Ocp-Apim-Subscription-Key" exists-action="delete" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
"@

$policyFile = "$env:TEMP\apim-policy-$APIMName.xml"
$policyXml | Out-File -FilePath $policyFile -Encoding UTF8

az apim api policy create `
    --resource-group $ResourceGroupName `
    --service-name $APIMName `
    --api-id $apiId `
    --xml-file $policyFile `
    --output none

Remove-Item $policyFile -Force

Write-Host "✅ Rate limiting policy applied:" -ForegroundColor Green
Write-Host "   - $RateLimitCalls calls per hour per subscription" -ForegroundColor Gray
Write-Host "   - $QuotaCalls calls per month per subscription" -ForegroundColor Gray

# ═══════════════════════════════════════════════════════════════════════════
# STEP 8: Get subscription key
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 8: Retrieving subscription key"

$subscriptions = az apim subscription list `
    --resource-group $ResourceGroupName `
    --service-name $APIMName `
    --output json | ConvertFrom-Json

$masterSubscription = $subscriptions | Where-Object { $_.scope -like "*/apis" } | Select-Object -First 1

$subscriptionKey = $masterSubscription.primaryKey

# Get APIM gateway URL
$apimDetails = az apim show `
    --name $APIMName `
    --resource-group $ResourceGroupName `
    --output json | ConvertFrom-Json

$apimUrl = "https://$($apimDetails.gatewayUrl.Replace('https://', ''))/$APISuffix/ProxyOpenAI"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 9: Display summary
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`n"
Write-Host "$('═' * 70)" -ForegroundColor Green
Write-Host "APIM DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
Write-Host "$('═' * 70)" -ForegroundColor Green
Write-Host ""
Write-Host "APIM Details:" -ForegroundColor Yellow
Write-Host "  Name:              $APIMName" -ForegroundColor White
Write-Host "  Resource Group:    $ResourceGroupName" -ForegroundColor White
Write-Host "  Gateway URL:       $($apimDetails.gatewayUrl)" -ForegroundColor White
Write-Host ""
Write-Host "API Endpoint (save this):" -ForegroundColor Yellow
Write-Host "  $apimUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Subscription Key (save this):" -ForegroundColor Yellow
Write-Host "  $subscriptionKey" -ForegroundColor Cyan
Write-Host ""
Write-Host "Rate Limits:" -ForegroundColor Yellow
Write-Host "  Hourly:   $RateLimitCalls calls per subscription" -ForegroundColor White
Write-Host "  Monthly:  $QuotaCalls calls per subscription" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Test APIM endpoint: .\Test-DeployedProxy.ps1 -APIMUrl '<url>' -SubscriptionKey '<key>'" -ForegroundColor White
Write-Host "  2. Update PowerShell module to use APIM endpoint" -ForegroundColor White
Write-Host "  3. Generate additional subscription keys for users via Azure Portal" -ForegroundColor White
Write-Host ""

# Export APIM info
$apimInfo = @{
    APIMName = $APIMName
    ResourceGroupName = $ResourceGroupName
    GatewayUrl = $apimDetails.gatewayUrl
    APIEndpoint = $apimUrl
    SubscriptionKey = $subscriptionKey
    RateLimitCallsPerHour = $RateLimitCalls
    QuotaCallsPerMonth = $QuotaCalls
    FunctionAppName = $FunctionAppName
    DeploymentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$apimInfo | ConvertTo-Json | Out-File "$PSScriptRoot\apim-info.json"
Write-Host "APIM info saved to: $PSScriptRoot\apim-info.json" -ForegroundColor Gray
Write-Host ""
