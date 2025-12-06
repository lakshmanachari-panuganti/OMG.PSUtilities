<#
.SYNOPSIS
    Deploy Azure Function App for OpenAI Proxy using PowerShell Az modules.

.DESCRIPTION
    Complete automation script using PowerShell Az cmdlets to:
    - Create Resource Group
    - Create Storage Account
    - Create Function App (PowerShell 7.4 runtime)
    - Configure environment variables for OpenAI proxy
    - Deploy function code
    - Retrieve deployment URLs and keys

.PARAMETER TargetSubscriptionId
    Azure subscription ID where resources will be created.

.PARAMETER ResourceGroupName
    Name of the resource group (default: rg-psu-openai-proxy)

.PARAMETER Location
    Azure region (default: eastus2)

.PARAMETER FunctionAppName
    Name for the Function App (must be globally unique)

.PARAMETER StorageAccountName
    Name for the storage account (must be globally unique, 3-24 chars, lowercase/numbers only)

.PARAMETER OpenAIKey
    Azure OpenAI API key (defaults to $env:API_KEY_AZURE_OPENAI)

.PARAMETER OpenAIEndpoint
    Azure OpenAI endpoint URL (defaults to $env:AZURE_OPENAI_ENDPOINT)

.PARAMETER OpenAIDeployment
    Azure OpenAI deployment name (defaults to $env:AZURE_OPENAI_DEPLOYMENT)

.PARAMETER OpenAIApiVersion
    Azure OpenAI API version (defaults to $env:AZURE_OPENAI_API_VERSION)

.PARAMETER FunctionCodePath
    Path to the Azure Function code (default: C:\repos\OMG.PSUtilities\AzureFunction-OpenAI-Proxy)

.PARAMETER SkipCodeDeployment
    Skip code deployment step (useful for infrastructure-only deployments)

.EXAMPLE
    .\Deploy-AzureFunctionApp-PowerShell.ps1 -TargetSubscriptionId "88355f02-7508-401e-a6c0-24993fad9e77" -FunctionAppName "psu-openai-proxy-12345" -StorageAccountName "psuproxy12345"

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 2025-01-05
    Requires: Az.Accounts, Az.Resources, Az.Storage, Az.Websites, Az.Functions modules
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetSubscriptionId,

    [Parameter()]
    [string]$ResourceGroupName = "rg-psu-openai-proxy",

    [Parameter()]
    [string]$Location = "eastus2",

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9-]{2,60}$')]
    [string]$FunctionAppName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]{3,24}$')]
    [string]$StorageAccountName,

    [Parameter()]
    [string]$OpenAIKey = $env:API_KEY_AZURE_OPENAI,

    [Parameter()]
    [string]$OpenAIEndpoint = $env:AZURE_OPENAI_ENDPOINT,

    [Parameter()]
    [string]$OpenAIDeployment = $env:AZURE_OPENAI_DEPLOYMENT,

    [Parameter()]
    [string]$OpenAIApiVersion = $env:AZURE_OPENAI_API_VERSION,

    [Parameter()]
    [string]$FunctionCodePath = "C:\repos\OMG.PSUtilities\AzureFunction-OpenAI-Proxy",

    [Parameter()]
    [switch]$SkipCodeDeployment
)

#region Helper Functions

function Write-Step {
    param([string]$Message, [int]$Step, [int]$Total)
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "Step $Step of ${Total}: $Message" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

#endregion

#region Main Deployment

$ErrorActionPreference = 'Stop'
$totalSteps = 8

try {
    # Step 1: Validate Prerequisites
    Write-Step -Message "Validating Prerequisites" -Step 1 -Total $totalSteps
    
    # Check required modules
    $requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.Storage', 'Az.Websites')
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            throw "Required module '$module' is not installed. Install with: Install-Module -Name $module"
        }
        Write-Success "Module $module is installed"
    }

    # Check Azure Functions Core Tools
    try {
        $funcVersion = func --version
        Write-Success "Azure Functions Core Tools installed: v$funcVersion"
    } catch {
        throw "Azure Functions Core Tools not found. Install from: https://aka.ms/func-tools"
    }

    # Validate OpenAI credentials
    if ([string]::IsNullOrWhiteSpace($OpenAIKey)) {
        throw "OpenAI Key is required. Set via: `$env:API_KEY_AZURE_OPENAI = '<your-key>'"
    }
    if ([string]::IsNullOrWhiteSpace($OpenAIEndpoint)) {
        throw "OpenAI Endpoint is required. Set via: `$env:AZURE_OPENAI_ENDPOINT = '<your-endpoint>'"
    }
    if ([string]::IsNullOrWhiteSpace($OpenAIDeployment)) {
        throw "OpenAI Deployment is required. Set via: `$env:AZURE_OPENAI_DEPLOYMENT = '<your-deployment>'"
    }
    if ([string]::IsNullOrWhiteSpace($OpenAIApiVersion)) {
        throw "OpenAI API Version is required. Set via: `$env:AZURE_OPENAI_API_VERSION = '<your-version>'"
    }

    $maskedKey = if ($OpenAIKey.Length -ge 5) { $OpenAIKey.Substring(0, 5) + "..." } else { "***" }
    Write-Success "OpenAI credentials validated (Key: $maskedKey)"

    # Step 2: Connect to Azure
    Write-Step -Message "Connecting to Azure Subscription" -Step 2 -Total $totalSteps
    
    # Check if already connected
    $currentContext = Get-AzContext -ErrorAction SilentlyContinue
    if ($currentContext -and $currentContext.Subscription.Id -eq $TargetSubscriptionId) {
        Write-Success "Already connected to subscription: $($currentContext.Subscription.Name) ($TargetSubscriptionId)"
    } else {
        Write-Info "Connecting to subscription: $TargetSubscriptionId"
        $null = Set-AzContext -SubscriptionId $TargetSubscriptionId -ErrorAction Stop
        Write-Success "Connected to Azure subscription"
    }

    # Verify context
    $context = Get-AzContext
    Write-Info "Account: $($context.Account.Id)"
    Write-Info "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
    Write-Info "Tenant: $($context.Tenant.Id)"

    # Step 3: Create or Verify Resource Group
    Write-Step -Message "Creating/Verifying Resource Group" -Step 3 -Total $totalSteps
    
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue
    if ($rg) {
        Write-Success "Resource group '$ResourceGroupName' already exists in $Location"
    } else {
        Write-Info "Creating resource group: $ResourceGroupName"
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction Stop
        Write-Success "Resource group created successfully"
    }

    # Step 4: Create Storage Account
    Write-Step -Message "Creating Storage Account" -Step 4 -Total $totalSteps
    
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
    if ($storageAccount) {
        Write-Success "Storage account '$StorageAccountName' already exists"
    } else {
        Write-Info "Creating storage account: $StorageAccountName"
        $storageAccount = New-AzStorageAccount `
            -ResourceGroupName $ResourceGroupName `
            -Name $StorageAccountName `
            -Location $Location `
            -SkuName Standard_LRS `
            -Kind StorageV2 `
            -ErrorAction Stop
        
        Write-Success "Storage account created successfully"
    }

    # Get storage account key
    $storageKeys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    $storageKey = $storageKeys[0].Value
    Write-Info "Retrieved storage account key"

    # Step 5: Create Function App
    Write-Step -Message "Creating Function App" -Step 5 -Total $totalSteps
    
    $functionApp = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $FunctionAppName -ErrorAction SilentlyContinue
    if ($functionApp) {
        Write-Success "Function App '$FunctionAppName' already exists"
    } else {
        Write-Info "Creating Function App: $FunctionAppName"
        Write-Info "Runtime: PowerShell 7.4"
        Write-Info "Plan: Consumption (Y1)"
        
        # Create Function App using New-AzFunctionApp
        $functionApp = New-AzFunctionApp `
            -ResourceGroupName $ResourceGroupName `
            -Name $FunctionAppName `
            -Location $Location `
            -StorageAccountName $StorageAccountName `
            -Runtime PowerShell `
            -RuntimeVersion 7.4 `
            -OSType Windows `
            -ErrorAction Stop
        
        Write-Success "Function App created successfully"
        Start-Sleep -Seconds 10  # Wait for Function App to stabilize
    }

    # Step 6: Configure Environment Variables
    Write-Step -Message "Configuring Environment Variables" -Step 6 -Total $totalSteps
    
    Write-Info "Setting OpenAI environment variables..."
    
    # Get current app settings
    $currentSettings = (Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $FunctionAppName).SiteConfig.AppSettings
    $settingsHash = @{}
    foreach ($setting in $currentSettings) {
        $settingsHash[$setting.Name] = $setting.Value
    }

    # Add/update OpenAI settings
    $settingsHash['AZURE_OPENAI_KEY'] = $OpenAIKey
    $settingsHash['AZURE_OPENAI_ENDPOINT'] = $OpenAIEndpoint
    $settingsHash['AZURE_OPENAI_DEPLOYMENT'] = $OpenAIDeployment
    $settingsHash['AZURE_OPENAI_API_VERSION'] = $OpenAIApiVersion
    $settingsHash['FUNCTIONS_WORKER_RUNTIME'] = 'powershell'
    $settingsHash['FUNCTIONS_EXTENSION_VERSION'] = '~4'

    # Update app settings
    $null = Set-AzWebApp `
        -ResourceGroupName $ResourceGroupName `
        -Name $FunctionAppName `
        -AppSettings $settingsHash `
        -ErrorAction Stop
    
    Write-Success "Environment variables configured successfully"
    Write-Info "  - AZURE_OPENAI_KEY: $maskedKey"
    Write-Info "  - AZURE_OPENAI_ENDPOINT: $OpenAIEndpoint"
    Write-Info "  - AZURE_OPENAI_DEPLOYMENT: $OpenAIDeployment"
    Write-Info "  - AZURE_OPENAI_API_VERSION: $OpenAIApiVersion"

    # Step 7: Deploy Function Code
    Write-Step -Message "Deploying Function Code" -Step 7 -Total $totalSteps
    
    if ($SkipCodeDeployment) {
        Write-Info "Code deployment skipped (use -SkipCodeDeployment switch)"
    } else {
        if (-not (Test-Path $FunctionCodePath)) {
            Write-Error-Custom "Function code path not found: $FunctionCodePath"
            throw "Function code path does not exist"
        }

        Write-Info "Function code path: $FunctionCodePath"
        Write-Info "Deploying to: $FunctionAppName"
        
        Push-Location $FunctionCodePath
        try {
            $deployOutput = func azure functionapp publish $FunctionAppName --powershell 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Function code deployed successfully"
                Write-Host $deployOutput -ForegroundColor Gray
            } else {
                Write-Error-Custom "Function deployment failed with exit code: $LASTEXITCODE"
                Write-Host $deployOutput -ForegroundColor Red
                throw "Function code deployment failed"
            }
        } finally {
            Pop-Location
        }
    }

    # Step 8: Retrieve Deployment Information
    Write-Step -Message "Retrieving Deployment Information" -Step 8 -Total $totalSteps
    
    # Get Function App details
    $functionApp = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $FunctionAppName
    $functionUrl = "https://$($functionApp.DefaultHostName)/api/ProxyOpenAI"
    
    # Get Function Keys
    Write-Info "Retrieving function keys..."
    $publishProfile = [xml](Get-AzWebAppPublishingProfile -ResourceGroupName $ResourceGroupName -Name $FunctionAppName)
    $username = $publishProfile.publishData.publishProfile[0].userName
    $password = $publishProfile.publishData.publishProfile[0].userPWD
    $base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($username):$($password)"))
    
    $keysUri = "https://$FunctionAppName.scm.azurewebsites.net/api/functions/ProxyOpenAI/keys"
    $headers = @{
        "Authorization" = "Basic $base64Auth"
        "Content-Type" = "application/json"
    }
    
    try {
        $keysResponse = Invoke-RestMethod -Uri $keysUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
        $functionKey = $keysResponse.default
    } catch {
        $functionKey = "Unable to retrieve (get manually from Portal)"
    }

    # Create deployment summary
    $deploymentInfo = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        SubscriptionId = $TargetSubscriptionId
        ResourceGroup = $ResourceGroupName
        Location = $Location
        StorageAccountName = $StorageAccountName
        FunctionAppName = $FunctionAppName
        FunctionUrl = $functionUrl
        FunctionKey = $functionKey
        FunctionUrlWithKey = if ($functionKey -and $functionKey -ne "Unable to retrieve (get manually from Portal)") {
            "$functionUrl`?code=$functionKey"
        } else {
            "$functionUrl`?code=<GET_FROM_PORTAL>"
        }
        OpenAIEndpoint = $OpenAIEndpoint
        OpenAIDeployment = $OpenAIDeployment
        OpenAIApiVersion = $OpenAIApiVersion
        CodeDeployed = -not $SkipCodeDeployment
    }

    # Display summary
    Write-Host "`n===============================================" -ForegroundColor Green
    Write-Host "DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Resource Details:" -ForegroundColor Cyan
    Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host "   Storage Account: $StorageAccountName" -ForegroundColor White
    Write-Host "   Function App: $FunctionAppName" -ForegroundColor White
    Write-Host "   Location: $Location" -ForegroundColor White
    Write-Host ""
    Write-Host "Function Endpoint:" -ForegroundColor Cyan
    Write-Host "   URL: $functionUrl" -ForegroundColor White
    Write-Host "   Key: $functionKey" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Test Command:" -ForegroundColor Cyan
    Write-Host "   .\Test-DeployedProxy.ps1 -FunctionUrl '$functionUrl' -FunctionKey '$functionKey'" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Test the function endpoint with Test-DeployedProxy.ps1" -ForegroundColor White
    Write-Host "   2. (Optional) Deploy APIM with Deploy-APIM.ps1 for rate limiting" -ForegroundColor White
    Write-Host "   3. Update your PowerShell module with the new proxy URL" -ForegroundColor White
    Write-Host ""

    # Export to JSON
    $jsonPath = Join-Path $PSScriptRoot "deployment-info-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $deploymentInfo | ConvertTo-Json -Depth 5 | Out-File $jsonPath -Encoding UTF8
    Write-Success "Deployment info saved to: $jsonPath"

    return $deploymentInfo

} catch {
    Write-Host "`n===============================================" -ForegroundColor Red
    Write-Host "DEPLOYMENT FAILED" -ForegroundColor Red
    Write-Host "===============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    Write-Host ""
    
    throw
}

#endregion
