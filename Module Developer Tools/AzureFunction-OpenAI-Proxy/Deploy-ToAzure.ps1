<#
═══════════════════════════════════════════════════════════════════════════════
  DEPLOYMENT SCRIPT: Deploy Azure Function to Azure
═══════════════════════════════════════════════════════════════════════════════

This script automates the deployment of your OpenAI Proxy to Azure.

PREREQUISITES:
  1. Azure CLI installed: https://aka.ms/installazurecli
  2. Azure Functions Core Tools: https://aka.ms/func-core-tools
  3. An active Azure subscription

WHAT THIS SCRIPT DOES:
  Step 1: Checks prerequisites (Azure CLI, Functions Core Tools)
  Step 2: Logs into Azure
  Step 3: Creates resource group (if it doesn't exist)
  Step 4: Creates storage account
  Step 5: Creates Function App
  Step 6: Configures environment variables (YOUR credentials)
  Step 7: Deploys function code
  Step 8: Shows function URL

═══════════════════════════════════════════════════════════════════════════════
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName = "rg-psu-openai-proxy", # Resource Group in lakshmanachari@hotmail.com azure account.

    [Parameter(Mandatory)]
    [string]$FunctionAppName = "psu-openai-proxy",

    [Parameter(Mandatory)]
    [string]$Location = "eastus",

    [Parameter(Mandatory)]
    [string]$AzureOpenAIKey,

    [Parameter(Mandatory)]
    [string]$AzureOpenAIEndpoint,

    [Parameter(Mandatory)]
    [string]$AzureOpenAIDeployment,

    [Parameter()]
    [string]$AzureOpenAIApiVersion = "2024-12-01-preview"
)

# ═══════════════════════════════════════════════════════════════════════════
# STEP 1: Check prerequisites
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 1: Checking prerequisites..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Check Azure CLI
try {
    $azVersion = az --version 2>&1 | Select-Object -First 1
    Write-Host "Azure CLI installed: $azVersion" -ForegroundColor Green
} catch {
    Write-Host "Azure CLI not found. Install from: https://aka.ms/installazurecli" -ForegroundColor Red
    return
}

# Check Azure Functions Core Tools
try {
    $funcVersion = func --version 2>&1
    Write-Host "Azure Functions Core Tools installed: $funcVersion" -ForegroundColor Green
} catch {
    Write-Host "Azure Functions Core Tools not found. Install from: https://aka.ms/func-core-tools" -ForegroundColor Red
    return
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 2: Login to Azure
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 2: Logging into Azure..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

$account = az account show 2>&1 | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in. Opening browser for authentication..." -ForegroundColor Yellow
    az login
} else {
    Write-Host "Already logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "   Subscription: $($account.name)" -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 3: Create resource group
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 3: Creating resource group..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

az group create --name $ResourceGroupName --location $Location --output none
Write-Host "Resource group created: $ResourceGroupName" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
# STEP 4: Create storage account
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 4: Creating storage account..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

$storageAccountName = ($FunctionAppName -replace '[^a-z0-9]', '') + "storage"
$storageAccountName = $storageAccountName.Substring(0, [Math]::Min(24, $storageAccountName.Length))

az storage account create `
    --name $storageAccountName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --sku Standard_LRS `
    --output none

Write-Host "Storage account created: $storageAccountName" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
# STEP 5: Create Function App
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 5: Creating Function App..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

az functionapp create `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --storage-account $storageAccountName `
    --consumption-plan-location $Location `
    --runtime powershell `
    --runtime-version 7.4 `
    --functions-version 4 `
    --output none

Write-Host "Function App created: $FunctionAppName" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
# STEP 6: Configure environment variables
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 6: Configuring Azure OpenAI credentials..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

az functionapp config appsettings set `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --settings `
        "AZURE_OPENAI_KEY=$AzureOpenAIKey" `
        "AZURE_OPENAI_ENDPOINT=$AzureOpenAIEndpoint" `
        "AZURE_OPENAI_DEPLOYMENT=$AzureOpenAIDeployment" `
        "AZURE_OPENAI_API_VERSION=$AzureOpenAIApiVersion" `
    --output none

Write-Host "Environment variables configured" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
# STEP 7: Deploy function code
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 7: Deploying function code..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

$currentLocation = Get-Location
Set-Location "$PSScriptRoot"

try {
    func azure functionapp publish $FunctionAppName --powershell
} finally {
    Set-Location $currentLocation
}

Write-Host "`nDeployment complete!" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
# STEP 8: Get function URL and key
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 8: Getting function URL and key..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

$functionKeys = az functionapp function keys list `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --function-name ProxyOpenAI `
    --output json | ConvertFrom-Json

$functionUrl = "https://$FunctionAppName.azurewebsites.net/api/ProxyOpenAI?code=$($functionKeys.default)"

Write-Host "`n╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  DEPLOYMENT SUCCESSFUL!                                            ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "Your Function URL:" -ForegroundColor Yellow
Write-Host $functionUrl -ForegroundColor Cyan

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Save this URL securely" -ForegroundColor White
Write-Host "2. Update your PowerShell module to use this proxy URL" -ForegroundColor White
Write-Host "3. Test the proxy with: Test-ProxyFunction.ps1`n" -ForegroundColor White
