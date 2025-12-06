<#
.SYNOPSIS
    Retrieves deployment information for Azure Function App and APIM.

.DESCRIPTION
    This script queries Azure to retrieve URLs, keys, and configuration details
    for deployed Function App and APIM resources.

.PARAMETER SubscriptionId
    Azure subscription ID.

.PARAMETER ResourceGroupName
    Name of the resource group.

.PARAMETER FunctionAppName
    Name of the Function App.

.PARAMETER APIMName
    Name of the APIM instance (optional).

.PARAMETER ExportToFile
    Export results to JSON file. Default: $false

.EXAMPLE
    .\Get-DeploymentInfo.ps1 `
        -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
        -ResourceGroupName "rg-psu-openai-proxy" `
        -FunctionAppName "psu-openai-proxy-1234"

.EXAMPLE
    .\Get-DeploymentInfo.ps1 `
        -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
        -ResourceGroupName "rg-psu-openai-proxy" `
        -FunctionAppName "psu-openai-proxy-1234" `
        -APIMName "psu-openai-apim" `
        -ExportToFile

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

    [Parameter(Mandatory)]
    [string]$FunctionAppName,

    [Parameter()]
    [string]$APIMName,

    [Parameter()]
    [switch]$ExportToFile
)

# ═══════════════════════════════════════════════════════════════════════════
# Set subscription
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "Setting subscription: $SubscriptionId" -ForegroundColor Yellow
az account set --subscription $SubscriptionId

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to set subscription. Please login with: az login" -ForegroundColor Red
    return
}

$account = az account show | ConvertFrom-Json
Write-Host "✅ Using subscription: $($account.name)" -ForegroundColor Green
Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════
# Get Function App details
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "$('─' * 70)" -ForegroundColor Cyan
Write-Host "FUNCTION APP DETAILS" -ForegroundColor Cyan
Write-Host "$('─' * 70)" -ForegroundColor Cyan

$functionApp = az functionapp show `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Function App not found: $FunctionAppName" -ForegroundColor Red
    return
}

Write-Host "`nFunction App:" -ForegroundColor Yellow
Write-Host "  Name:     $($functionApp.name)" -ForegroundColor White
Write-Host "  Location: $($functionApp.location)" -ForegroundColor White
Write-Host "  State:    $($functionApp.state)" -ForegroundColor White
Write-Host "  Runtime:  PowerShell $($functionApp.siteConfig.powerShellVersion)" -ForegroundColor White

# Get function keys
$functionKeys = az functionapp function keys list `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --function-name ProxyOpenAI `
    --output json 2>$null | ConvertFrom-Json

if ($functionKeys) {
    $functionUrl = "https://$($functionApp.defaultHostName)/api/ProxyOpenAI?code=$($functionKeys.default)"
    
    Write-Host "`nFunction URL:" -ForegroundColor Yellow
    Write-Host "  $functionUrl" -ForegroundColor Cyan
    
    Write-Host "`nFunction Key:" -ForegroundColor Yellow
    Write-Host "  $($functionKeys.default)" -ForegroundColor Cyan
}

# Get outbound IPs
$outboundIps = az functionapp show `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --query outboundIpAddresses -o tsv

Write-Host "`nOutbound IPs (for OpenAI firewall):" -ForegroundColor Yellow
$outboundIps -split ',' | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

# Get environment variables (masked)
$appSettings = az functionapp config appsettings list `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --output json | ConvertFrom-Json

$openAISettings = $appSettings | Where-Object { $_.name -like "AZURE_OPENAI*" }

Write-Host "`nAzure OpenAI Configuration:" -ForegroundColor Yellow
foreach ($setting in $openAISettings) {
    if ($setting.name -eq "AZURE_OPENAI_KEY") {
        Write-Host "  $($setting.name): ****" -ForegroundColor Gray
    } else {
        Write-Host "  $($setting.name): $($setting.value)" -ForegroundColor Gray
    }
}

$functionInfo = @{
    Name = $functionApp.name
    ResourceGroup = $ResourceGroupName
    Location = $functionApp.location
    State = $functionApp.state
    DefaultHostName = $functionApp.defaultHostName
    FunctionUrl = $functionUrl
    FunctionKey = $functionKeys.default
    OutboundIPs = $outboundIps -split ','
    OpenAIEndpoint = ($openAISettings | Where-Object { $_.name -eq "AZURE_OPENAI_ENDPOINT" }).value
    OpenAIDeployment = ($openAISettings | Where-Object { $_.name -eq "AZURE_OPENAI_DEPLOYMENT" }).value
    OpenAIApiVersion = ($openAISettings | Where-Object { $_.name -eq "AZURE_OPENAI_API_VERSION" }).value
}

# ═══════════════════════════════════════════════════════════════════════════
# Get APIM details (if provided)
# ═══════════════════════════════════════════════════════════════════════════
$apimInfo = $null

if ($APIMName) {
    Write-Host "`n$('─' * 70)" -ForegroundColor Cyan
    Write-Host "APIM DETAILS" -ForegroundColor Cyan
    Write-Host "$('─' * 70)" -ForegroundColor Cyan

    $apim = az apim show `
        --name $APIMName `
        --resource-group $ResourceGroupName `
        --output json 2>$null | ConvertFrom-Json

    if ($apim) {
        Write-Host "`nAPIM Instance:" -ForegroundColor Yellow
        Write-Host "  Name:     $($apim.name)" -ForegroundColor White
        Write-Host "  Location: $($apim.location)" -ForegroundColor White
        Write-Host "  State:    $($apim.provisioningState)" -ForegroundColor White
        Write-Host "  SKU:      $($apim.sku.name)" -ForegroundColor White

        Write-Host "`nGateway URL:" -ForegroundColor Yellow
        Write-Host "  $($apim.gatewayUrl)" -ForegroundColor Cyan

        # Get APIs
        $apis = az apim api list `
            --resource-group $ResourceGroupName `
            --service-name $APIMName `
            --output json | ConvertFrom-Json

        if ($apis) {
            Write-Host "`nAPIs:" -ForegroundColor Yellow
            foreach ($api in $apis) {
                Write-Host "  $($api.displayName) - $($api.path)" -ForegroundColor White
            }
        }

        # Get subscription keys
        $subscriptions = az apim subscription list `
            --resource-group $ResourceGroupName `
            --service-name $APIMName `
            --output json | ConvertFrom-Json

        $masterSub = $subscriptions | Where-Object { $_.scope -like "*/apis" } | Select-Object -First 1

        if ($masterSub) {
            Write-Host "`nMaster Subscription Key:" -ForegroundColor Yellow
            Write-Host "  Primary:   $($masterSub.primaryKey)" -ForegroundColor Cyan
            Write-Host "  Secondary: $($masterSub.secondaryKey)" -ForegroundColor Gray
        }

        # Construct API endpoint
        $apiEndpoint = "$($apim.gatewayUrl)/openai/ProxyOpenAI"
        Write-Host "`nAPI Endpoint:" -ForegroundColor Yellow
        Write-Host "  $apiEndpoint" -ForegroundColor Cyan

        $apimInfo = @{
            Name = $apim.name
            ResourceGroup = $ResourceGroupName
            Location = $apim.location
            State = $apim.provisioningState
            SKU = $apim.sku.name
            GatewayUrl = $apim.gatewayUrl
            APIEndpoint = $apiEndpoint
            SubscriptionKeyPrimary = $masterSub.primaryKey
            SubscriptionKeySecondary = $masterSub.secondaryKey
        }
    } else {
        Write-Host "`n⚠️  APIM instance not found: $APIMName" -ForegroundColor Yellow
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# Export to file
# ═══════════════════════════════════════════════════════════════════════════
if ($ExportToFile) {
    $exportData = @{
        SubscriptionId = $SubscriptionId
        SubscriptionName = $account.name
        ResourceGroupName = $ResourceGroupName
        FunctionApp = $functionInfo
        APIM = $apimInfo
        RetrievedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    $exportPath = "$PSScriptRoot\deployment-details.json"
    $exportData | ConvertTo-Json -Depth 10 | Out-File $exportPath

    Write-Host "`n$('─' * 70)" -ForegroundColor Green
    Write-Host "Exported to: $exportPath" -ForegroundColor Green
    Write-Host "$('─' * 70)" -ForegroundColor Green
}

Write-Host ""

# Return object for programmatic use
return @{
    FunctionApp = $functionInfo
    APIM = $apimInfo
}
