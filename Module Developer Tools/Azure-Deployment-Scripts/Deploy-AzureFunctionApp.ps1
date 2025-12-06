<#
.SYNOPSIS
    Deploys Azure Function App to a different Azure account using existing OpenAI credentials.

.DESCRIPTION
    This script automates the deployment of an Azure Function App proxy to Account B,
    while using Azure OpenAI credentials from Account A. It handles:
    - Azure login and subscription selection
    - Resource group creation
    - Storage account creation
    - Function App creation (PowerShell 7.4)
    - Environment variable configuration
    - Function code deployment

.PARAMETER TargetSubscriptionId
    The Azure subscription ID where the Function App will be deployed (Account B).

.PARAMETER ResourceGroupName
    Name of the resource group to create or use.

.PARAMETER FunctionAppName
    Globally unique name for the Function App. If not provided, generates random name.

.PARAMETER Location
    Azure region for deployment. Default: eastus2

.PARAMETER SourceFunctionPath
    Path to the Azure Function source code. Default: AzureFunction-OpenAI-Proxy folder.

.PARAMETER AzureOpenAIKey
    API key from Account A's Azure OpenAI service.

.PARAMETER AzureOpenAIEndpoint
    Endpoint URL from Account A's Azure OpenAI service.

.PARAMETER AzureOpenAIDeployment
    Deployment name (model) from Account A's Azure OpenAI service.

.PARAMETER AzureOpenAIApiVersion
    Azure OpenAI API version. Default: 2024-12-01-preview

.EXAMPLE
    .\Deploy-AzureFunctionApp.ps1 `
        -TargetSubscriptionId "12345678-1234-1234-1234-123456789abc" `
        -ResourceGroupName "rg-psu-openai-proxy" `
        -AzureOpenAIKey "abc123..." `
        -AzureOpenAIEndpoint "https://myopenai.openai.azure.com" `
        -AzureOpenAIDeployment "gpt-4o"

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 2025-12-05
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TargetSubscriptionId,

    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter()]
    [string]$FunctionAppName = "psu-openai-proxy-$(Get-Random -Minimum 1000 -Maximum 9999)",

    [Parameter()]
    [string]$Location = "eastus2",

    [Parameter()]
    [string]$SourceFunctionPath = "$PSScriptRoot\..\..\AzureFunction-OpenAI-Proxy",

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
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

function Write-StepHeader {
    param([string]$Message)
    Write-Host "`n$('═' * 70)" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "$('═' * 70)`n" -ForegroundColor Cyan
}

function Test-AzureCliInstalled {
    try {
        $null = az --version 2>&1
        return $true
    } catch {
        return $false
    }
}

function Test-FuncCoreToolsInstalled {
    try {
        $null = func --version 2>&1
        return $true
    } catch {
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 1: Validate prerequisites
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 1: Validating prerequisites"

if (-not (Test-AzureCliInstalled)) {
    Write-Host "❌ Azure CLI not found!" -ForegroundColor Red
    Write-Host "   Install from: https://aka.ms/installazurecli" -ForegroundColor Yellow
    return
}
Write-Host "✅ Azure CLI installed" -ForegroundColor Green

if (-not (Test-FuncCoreToolsInstalled)) {
    Write-Host "❌ Azure Functions Core Tools not found!" -ForegroundColor Red
    Write-Host "   Install from: https://aka.ms/func-core-tools" -ForegroundColor Yellow
    return
}
Write-Host "✅ Azure Functions Core Tools installed" -ForegroundColor Green

if (-not (Test-Path $SourceFunctionPath)) {
    Write-Host "❌ Source function path not found: $SourceFunctionPath" -ForegroundColor Red
    return
}
Write-Host "✅ Source function code found: $SourceFunctionPath" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
# STEP 2: Login to Azure (Account B)
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 2: Logging into Azure (Target Account)"

$currentAccount = az account show 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0 -or $currentAccount.id -ne $TargetSubscriptionId) {
    Write-Host "⚠️  Not logged in or wrong subscription" -ForegroundColor Yellow
    Write-Host "   Opening browser for authentication..." -ForegroundColor Yellow
    
    az login --output none
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Login failed" -ForegroundColor Red
        return
    }
}

# Set target subscription
Write-Host "Setting subscription to: $TargetSubscriptionId" -ForegroundColor Yellow
az account set --subscription $TargetSubscriptionId

$account = az account show | ConvertFrom-Json
Write-Host "✅ Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host "   Subscription: $($account.name) ($($account.id))" -ForegroundColor Gray

if ($account.id -ne $TargetSubscriptionId) {
    Write-Host "❌ Failed to set target subscription" -ForegroundColor Red
    return
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 3: Create resource group
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 3: Creating resource group"

az group create --name $ResourceGroupName --location $Location --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Resource group created: $ResourceGroupName" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create resource group" -ForegroundColor Red
    return
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 4: Create storage account
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 4: Creating storage account"

$storageAccountName = ($FunctionAppName -replace '[^a-z0-9]', '') + "storage"
$storageAccountName = $storageAccountName.Substring(0, [Math]::Min(24, $storageAccountName.Length))

az storage account create `
    --name $storageAccountName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --sku Standard_LRS `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Storage account created: $storageAccountName" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create storage account" -ForegroundColor Red
    return
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 5: Create Function App
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 5: Creating Function App"

az functionapp create `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --storage-account $storageAccountName `
    --consumption-plan-location $Location `
    --runtime powershell `
    --runtime-version 7.4 `
    --functions-version 4 `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Function App created: $FunctionAppName" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create Function App" -ForegroundColor Red
    return
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 6: Configure environment variables (Account A's OpenAI credentials)
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 6: Configuring Azure OpenAI credentials (Account A)"

Write-Host "Setting environment variables:" -ForegroundColor Yellow
Write-Host "  AZURE_OPENAI_KEY: ****" -ForegroundColor Gray
Write-Host "  AZURE_OPENAI_ENDPOINT: $AzureOpenAIEndpoint" -ForegroundColor Gray
Write-Host "  AZURE_OPENAI_DEPLOYMENT: $AzureOpenAIDeployment" -ForegroundColor Gray
Write-Host "  AZURE_OPENAI_API_VERSION: $AzureOpenAIApiVersion" -ForegroundColor Gray

az functionapp config appsettings set `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --settings `
        "AZURE_OPENAI_KEY=$AzureOpenAIKey" `
        "AZURE_OPENAI_ENDPOINT=$AzureOpenAIEndpoint" `
        "AZURE_OPENAI_DEPLOYMENT=$AzureOpenAIDeployment" `
        "AZURE_OPENAI_API_VERSION=$AzureOpenAIApiVersion" `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Environment variables configured" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to configure environment variables" -ForegroundColor Red
    return
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 7: Deploy function code
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 7: Deploying function code"

$currentLocation = Get-Location
Set-Location $SourceFunctionPath

try {
    Write-Host "Publishing from: $SourceFunctionPath" -ForegroundColor Yellow
    func azure functionapp publish $FunctionAppName --powershell
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Function code deployed successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Deployment failed" -ForegroundColor Red
        return
    }
} finally {
    Set-Location $currentLocation
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 8: Get function URL and key
# ═══════════════════════════════════════════════════════════════════════════
Write-StepHeader "STEP 8: Retrieving function details"

Start-Sleep -Seconds 5  # Wait for deployment to complete

$functionKeys = az functionapp function keys list `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --function-name ProxyOpenAI `
    --output json | ConvertFrom-Json

$functionUrl = "https://$FunctionAppName.azurewebsites.net/api/ProxyOpenAI?code=$($functionKeys.default)"

$outboundIps = az functionapp show `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --query outboundIpAddresses -o tsv

# ═══════════════════════════════════════════════════════════════════════════
# STEP 9: Display summary
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`n"
Write-Host "$('═' * 70)" -ForegroundColor Green
Write-Host "DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
Write-Host "$('═' * 70)" -ForegroundColor Green
Write-Host ""
Write-Host "Function App Details:" -ForegroundColor Yellow
Write-Host "  Name:              $FunctionAppName" -ForegroundColor White
Write-Host "  Resource Group:    $ResourceGroupName" -ForegroundColor White
Write-Host "  Location:          $Location" -ForegroundColor White
Write-Host "  Subscription:      $($account.name)" -ForegroundColor White
Write-Host ""
Write-Host "Function URL (save this):" -ForegroundColor Yellow
Write-Host "  $functionUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Outbound IPs (for Account A's OpenAI firewall):" -ForegroundColor Yellow
Write-Host "  $outboundIps" -ForegroundColor Cyan
Write-Host ""
Write-Host "OpenAI Configuration (Account A):" -ForegroundColor Yellow
Write-Host "  Endpoint:    $AzureOpenAIEndpoint" -ForegroundColor White
Write-Host "  Deployment:  $AzureOpenAIDeployment" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Test the function: .\Test-DeployedProxy.ps1 -FunctionUrl '<url>'" -ForegroundColor White
Write-Host "  2. (Optional) Deploy APIM: .\Deploy-APIM.ps1" -ForegroundColor White
Write-Host "  3. Update PowerShell module with new proxy URL" -ForegroundColor White
Write-Host ""

# Export deployment info to file
$deploymentInfo = @{
    FunctionAppName = $FunctionAppName
    ResourceGroupName = $ResourceGroupName
    Location = $Location
    SubscriptionId = $account.id
    SubscriptionName = $account.name
    FunctionUrl = $functionUrl
    OutboundIPs = $outboundIps
    OpenAIEndpoint = $AzureOpenAIEndpoint
    OpenAIDeployment = $AzureOpenAIDeployment
    DeploymentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$deploymentInfo | ConvertTo-Json | Out-File "$PSScriptRoot\deployment-info.json"
Write-Host "Deployment info saved to: $PSScriptRoot\deployment-info.json" -ForegroundColor Gray
Write-Host ""
