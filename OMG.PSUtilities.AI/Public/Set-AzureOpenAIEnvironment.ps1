<#
.SYNOPSIS
    Automated Azure OpenAI Service setup and environment variable configuration.

.DESCRIPTION
    This script automates the complete setup of Azure OpenAI Service including:
    - Interactive subscription and resource group selection
    - Azure OpenAI Service resource creation
    - GPT-4 or GPT-35-Turbo model deployment
    - Automatic retrieval of endpoint and API keys
    - Environment variable configuration for the AI Writing Assistant
    
    PREREQUISITES:
    - Azure PowerShell module (Az.Accounts, Az.Resources, Az.CognitiveServices)
    - Active Azure subscription with Azure OpenAI access
    - Must run Connect-AzAccount before executing this script
    - Contributor or Owner role on the subscription

.PARAMETER ResourceGroupName
    Optional. Name of the resource group. If not provided, you can select existing or create new.

.PARAMETER Location
    Optional. Azure region for deployment. Default is 'eastus'. 
    Available regions: eastus, eastus2, westus, westeurope, swedencentral, etc.

.PARAMETER OpenAIServiceName
    Optional. Name for the Azure OpenAI Service resource. Must be globally unique.
    If not provided, a unique name will be generated.

.PARAMETER DeploymentName
    Optional. Name for the model deployment. Default is 'gpt-4'.

.PARAMETER ModelName
    Optional. Model to deploy. Options: 'gpt-4', 'gpt-35-turbo', 'gpt-4-turbo'. Default is 'gpt-4'.

.PARAMETER SetEnvironmentVariables
    Switch. If specified, automatically sets user-level environment variables.
    If not specified, displays values for manual configuration.

.EXAMPLE
    .\Setup-AzureOpenAIEnvironment.ps1
    
    Interactive mode - guides through all steps and displays configuration values.

.EXAMPLE
    .\Setup-AzureOpenAIEnvironment.ps1 -ResourceGroupName "rg-ai-tools" -Location "eastus" -SetEnvironmentVariables
    
    Creates resources in specified resource group and location, sets environment variables automatically.

.NOTES
    Author: Lakshmanachari Panuganti
    Date: October 7, 2025
    
    Required Azure Modules:
    Install-Module -Name Az.Accounts -Force -AllowClobber
    Install-Module -Name Az.Resources -Force -AllowClobber
    Install-Module -Name Az.CognitiveServices -Force -AllowClobber

.LINK
    https://learn.microsoft.com/en-us/azure/ai-services/openai/
#>
    [Parameter()]
    [string]$ResourceGroupName,
    
    [Parameter()]
    [ValidateSet('eastus', 'eastus2', 'westus', 'westus2', 'westeurope', 'northeurope', 'swedencentral', 'switzerlandnorth', 'francecentral', 'uksouth', 'australiaeast', 'japaneast', 'canadaeast')]
    [string]$Location = 'eastus',
    
    [Parameter()]
    [string]$OpenAIServiceName,
    
    [Parameter()]
    [string]$DeploymentName = 'gpt-4-deployment',
    
    [Parameter()]
    [ValidateSet('gpt-4', 'gpt-35-turbo', 'gpt-4-turbo', 'gpt-4o')]
    [string]$ModelName = 'gpt-4',
)

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n==> $Message" -Color Cyan
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "$Message" -Color Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-ColorOutput "$Message" -Color Red
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "$Message" -Color Yellow
}

# Check if required modules are installed
Write-Step "Checking required Azure PowerShell modules..."
$requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.CognitiveServices')
$missingModules = @()

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        $missingModules += $module
    }
    else {
        Write-Success "$module is installed"
    }
}

if ($missingModules.Count -gt 0) {
    Write-Error-Custom "Missing required modules: $($missingModules -join ', ')"
    Write-Info "Install them with:"
    foreach ($module in $missingModules) {
        Write-Host "  Install-Module -Name $module -Force -AllowClobber" -ForegroundColor White
    }
    exit 1
}

# Check if connected to Azure
Write-Step "Checking Azure connection..."
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Error-Custom "Not connected to Azure. Please run: Connect-AzAccount"
        exit 1
    }
    Write-Success "Connected to Azure as: $($context.Account.Id)"
    Write-Info "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
}
catch {
    Write-Error-Custom "Not connected to Azure. Please run: Connect-AzAccount"
    exit 1
}

# Select or confirm subscription
Write-Step "Subscription Selection"
$subscriptions = Get-AzSubscription
if ($subscriptions.Count -gt 1) {
    Write-Host "`nAvailable Subscriptions:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $subscriptions.Count; $i++) {
        Write-Host "  [$i] $($subscriptions[$i].Name) ($($subscriptions[$i].Id))"
    }
    $selection = Read-Host "`nSelect subscription number [0-$($subscriptions.Count - 1)] or press Enter to use current"
    if ($selection -ne '') {
        Set-AzContext -SubscriptionId $subscriptions[[int]$selection].Id | Out-Null
        Write-Success "Switched to subscription: $($subscriptions[[int]$selection].Name)"
    }
}

# Resource Group selection/creation
Write-Step "Resource Group Configuration"
if (-not $ResourceGroupName) {
    $existingRGs = Get-AzResourceGroup
    Write-Host "`nOptions:" -ForegroundColor Yellow
    Write-Host "  [0] Create new resource group"
    for ($i = 0; $i -lt $existingRGs.Count; $i++) {
        Write-Host "  [$($i + 1)] Use existing: $($existingRGs[$i].ResourceGroupName) ($($existingRGs[$i].Location))"
    }
    
    $rgSelection = Read-Host "`nSelect option [0-$($existingRGs.Count)]"
    
    if ($rgSelection -eq '0') {
        $ResourceGroupName = Read-Host "Enter new resource group name"
        $Location = Read-Host "Enter location (default: eastus)"
        if ([string]::IsNullOrWhiteSpace($Location)) { $Location = 'eastus' }
        
        Write-Info "Creating resource group: $ResourceGroupName in $Location..."
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
        Write-Success "Resource group created successfully"
    }
    else {
        $selectedRG = $existingRGs[[int]$rgSelection - 1]
        $ResourceGroupName = $selectedRG.ResourceGroupName
        $Location = $selectedRG.Location
        Write-Success "Using existing resource group: $ResourceGroupName"
    }
}
else {
    # Check if provided resource group exists
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Info "Resource group '$ResourceGroupName' does not exist. Creating..."
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
        Write-Success "Resource group created successfully"
    }
    else {
        Write-Success "Using existing resource group: $ResourceGroupName"
        $Location = $rg.Location
    }
}

# Generate unique OpenAI Service name if not provided
if (-not $OpenAIServiceName) {
    $randomSuffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
    $OpenAIServiceName = "omg-psutilities-$randomSuffix"
    Write-Info "Generated Azure OpenAI Service name: $OpenAIServiceName"
}

# Create Azure OpenAI Service
Write-Step "Creating Azure OpenAI Service: $OpenAIServiceName"
try {
    $openAIService = Get-AzCognitiveServicesAccount -ResourceGroupName $ResourceGroupName -Name $OpenAIServiceName -ErrorAction SilentlyContinue
    
    if ($openAIService) {
        Write-Info "Azure OpenAI Service '$OpenAIServiceName' already exists"
    }
    else {
        Write-Info "Creating Azure OpenAI Service in $Location... (This may take 2-3 minutes)"
        
        $openAIService = New-AzCognitiveServicesAccount `
            -ResourceGroupName $ResourceGroupName `
            -Name $OpenAIServiceName `
            -Type "OpenAI" `
            -SkuName "S0" `
            -Location $Location `
            -CustomSubdomainName $OpenAIServiceName
        
        Write-Success "Azure OpenAI Service created successfully"
    }
}
catch {
    Write-Error-Custom "Failed to create Azure OpenAI Service: $($_.Exception.Message)"
    Write-Info "Common issues:"
    Write-Info "  - Azure OpenAI access not approved for your subscription (Request access at: https://aka.ms/oai/access)"
    Write-Info "  - Name already taken (try a different name)"
    Write-Info "  - Region not supporting Azure OpenAI (try: eastus, westeurope, or swedencentral)"
    exit 1
}

# Get endpoint and keys
Write-Step "Retrieving Azure OpenAI configuration..."
$endpoint = $openAIService.Endpoint
$keys = Get-AzCognitiveServicesAccountKey -ResourceGroupName $ResourceGroupName -Name $OpenAIServiceName
$apiKey = $keys.Key1

Write-Success "Endpoint: $endpoint"
Write-Success "API Key retrieved successfully"

# Create model deployment
Write-Step "Creating model deployment: $DeploymentName ($ModelName)"
try {
    # Check if deployment already exists
    $deployments = az cognitiveservices account deployment list `
        --resource-group $ResourceGroupName `
        --name $OpenAIServiceName `
        --query "[?name=='$DeploymentName'].name" `
        --output tsv 2>$null
    
    if ($deployments -contains $DeploymentName) {
        Write-Info "Deployment '$DeploymentName' already exists"
    }
    else {
        Write-Info "Creating deployment... (This may take 1-2 minutes)"
        
        # Model version mapping
        $modelVersion = switch ($ModelName) {
            'gpt-4' { '0613' }
            'gpt-4-turbo' { '2024-04-09' }
            'gpt-4o' { '2024-05-13' }
            'gpt-35-turbo' { '0613' }
            default { '0613' }
        }
        
        az cognitiveservices account deployment create `
            --resource-group $ResourceGroupName `
            --name $OpenAIServiceName `
            --deployment-name $DeploymentName `
            --model-name $ModelName `
            --model-version $modelVersion `
            --model-format OpenAI `
            --sku-capacity 1 `
            --sku-name "Standard" | Out-Null
        
        Write-Success "Model deployment created successfully"
    }
}
catch {
    Write-Error-Custom "Failed to create deployment using Azure CLI. Trying alternative method..."
    Write-Info "Note: You may need to create the deployment manually in Azure Portal"
    Write-Info "  1. Go to: https://portal.azure.com"
    Write-Info "  2. Navigate to: $ResourceGroupName > $OpenAIServiceName > Model deployments"
    Write-Info "  3. Click 'Create new deployment'"
    Write-Info "  4. Select model: $ModelName, Name: $DeploymentName"
}

# Display configuration summary
Write-Step "Configuration Summary"
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Azure OpenAI Service Configuration" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "Resource Group:      " -NoNewline; Write-Host $ResourceGroupName -ForegroundColor Green
Write-Host "Service Name:        " -NoNewline; Write-Host $OpenAIServiceName -ForegroundColor Green
Write-Host "Location:            " -NoNewline; Write-Host $Location -ForegroundColor Green
Write-Host "Deployment Name:     " -NoNewline; Write-Host $DeploymentName -ForegroundColor Green
Write-Host "Model:               " -NoNewline; Write-Host $ModelName -ForegroundColor Green
Write-Host ""
Write-Host "Endpoint:            " -NoNewline; Write-Host $endpoint -ForegroundColor Yellow
Write-Host "API Key:             " -NoNewline; Write-Host "$($apiKey.Substring(0, 8))..." -ForegroundColor Yellow
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# Set environment variables

Write-Step "Setting Environment Variables"
    
try {        
    Set-PSUUserEnvironmentVariable -Name 'API_KEY_AZURE_OPENAI' -Value $apiKey
    Set-PSUUserEnvironmentVariable -Name 'AZURE_OPENAI_ENDPOINT' -Value $endpoint
    Set-PSUUserEnvironmentVariable -Name 'AZURE_OPENAI_DEPLOYMENT' -Value $DeploymentName
                
    Write-Success "Environment variables set successfully (User level)"
    Write-Info "Variables are now available in this session and will persist for your user account"
    Write-Info "To use in new PowerShell sessions, restart PowerShell or open a new window"
}
catch {
    Write-Error-Custom "Failed to set environment variables: $($_.Exception.Message)"
}
