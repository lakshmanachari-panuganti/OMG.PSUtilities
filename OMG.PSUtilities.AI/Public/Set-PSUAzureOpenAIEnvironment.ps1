function Set-PSUAzureOpenAIEnvironment {
    <#
    .SYNOPSIS
        Automated Azure OpenAI Service setup and environment variable configuration.

    .DESCRIPTION
        This function automates the complete setup of Azure OpenAI Service including:
        - Interactive subscription and resource group selection
        - Azure OpenAI Service resource creation
        - GPT-4, GPT-4o, GPT-4-Turbo, or GPT-35-Turbo model deployment
        - Automatic retrieval of endpoint and API keys
        - Environment variable configuration for AI-powered utilities

        PREREQUISITES:
        - Azure PowerShell modules (Az.Accounts, Az.Resources, Az.CognitiveServices)
        - Active Azure subscription with Azure OpenAI access approval
        - Must run Connect-AzAccount before executing this function
        - Contributor or Owner role on the target subscription

    .PARAMETER ResourceGroupName
        (Optional) Name of the resource group for Azure OpenAI resources.
        If not provided, interactive selection of existing or creation of new resource group is offered.

    .PARAMETER Location
        (Optional) Azure region for deployment. Default is 'eastus'.
        Available regions: eastus, eastus2, westus, westus2.

    .PARAMETER OpenAIServiceName
        (Optional) Name for the Azure OpenAI Service resource. Must be globally unique.
        If not provided, a unique name will be generated using timestamp suffix.

    .PARAMETER DeploymentName
        (Optional) Name for the model deployment within the Azure OpenAI Service.
        Default is 'gpt-4-deployment'.

    .PARAMETER ModelName
        (Optional) Model to deploy in the Azure OpenAI Service.
        Default is 'gpt-4'. Valid options: 'gpt-4', 'gpt-35-turbo', 'gpt-4-turbo', 'gpt-4o'.

    .EXAMPLE
        Set-PSUAzureOpenAIEnvironment

        Interactive mode - guides through all setup steps and automatically configures environment variables.

    .EXAMPLE
        Set-PSUAzureOpenAIEnvironment -ResourceGroupName "rg-ai-tools" -Location "eastus"

        Creates Azure OpenAI resources in specified resource group and location with default GPT-4 model.

    .EXAMPLE
        Set-PSUAzureOpenAIEnvironment -ModelName "gpt-4o" -DeploymentName "gpt4o-deployment"

        Deploys GPT-4o model with custom deployment name using interactive resource group selection.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 7th October 2025
        Requires: Azure OpenAI access approval for subscription (request at https://aka.ms/oai/access)

        Environment Variables Set by this function:
        - API_KEY_AZURE_OPENAI: Azure OpenAI Service API key
        - AZURE_OPENAI_ENDPOINT: Azure OpenAI Service endpoint URL
        - AZURE_OPENAI_DEPLOYMENT: Model deployment name

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AI
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AI
        https://learn.microsoft.com/en-us/azure/ai-services/openai/
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'Console UX: interactive setup requires formatted, colorized output for user guidance'
    )]
    param(
        [Parameter()]
        [string]$ResourceGroupName,

        [Parameter()]
        [ValidateSet('eastus', 'eastus2', 'westus', 'westus2')]
        [string]$Location = 'eastus',

        [Parameter()]
        [string]$OpenAIServiceName,

        [Parameter()]
        [string]$DeploymentName = 'gpt-4-deployment',

        [Parameter()]
        [ValidateSet('gpt-4', 'gpt-35-turbo', 'gpt-4-turbo', 'gpt-4o')]
        [string]$ModelName = 'gpt-4'
    )

    process {
        try {
            # Check if required modules are installed
            Write-Step "Checking required Azure PowerShell modules..."
            $requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.CognitiveServices')

            foreach ($module in $requiredModules) {
                if (-not (Get-Module -ListAvailable -Name $module)) {
                    Write-Info "Module '$module' not found. Installing from PowerShell Gallery..."
                    try {
                        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
                        Write-Success "$module installed successfully"
                    }
                    catch {
                        Write-ErrorMsg "Failed to install $module`: $($_.Exception.Message)"
                        throw "Unable to install required module: $module. Please install manually and try again."
                    }
                }
                else {
                    Write-Success "$module is already installed"
                }
            }

            # Check if connected to Azure
            Write-Step "Checking Azure connection..."
            $context = Get-AzContext
            if (-not $context) {
                throw "Not connected to Azure. Please run 'Connect-AzAccount' before executing this function."
            }
            Write-Success "Connected to Azure as: $($context.Account.Id)"
            Write-Info "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"

            # Select or confirm subscription
            Write-Step "Subscription Selection"
            $subscriptions = Get-AzSubscription
            if ($subscriptions.Count -gt 1) {
                Write-Host "`nAvailable Subscriptions:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $subscriptions.Count; $i++) {
                    Write-Host "  [$($i + 1)] $($subscriptions[$i].Name) ($($subscriptions[$i].Id))"
                }
                $selection = Read-Host "`nSelect subscription number [1-$($subscriptions.Count)] or press Enter to use current"
                if ($selection -ne '') {
                    Set-AzContext -SubscriptionId $subscriptions[[int]$selection - 1].Id | Out-Null
                    Write-Success "Switched to subscription: $($subscriptions[[int]$selection - 1].Name)"
                }
            }

            # Resource Group selection/creation
            Write-Step "Resource Group Configuration"
            if (-not $ResourceGroupName) {
                $existingRGs = Get-AzResourceGroup
                Write-Host "`nOptions:" -ForegroundColor Yellow
                Write-Host "  [1] Create new resource group"
                for ($i = 0; $i -lt $existingRGs.Count; $i++) {
                    Write-Host "  [$($i + 2)] Use existing: $($existingRGs[$i].ResourceGroupName) ($($existingRGs[$i].Location))"
                }

                $rgSelection = Read-Host "`nSelect option [1-$($existingRGs.Count + 1)]"

                if ($rgSelection -eq '1') {
                    $ResourceGroupName = Read-Host "Enter new resource group name"
                    $userLocation = Read-Host "Enter location (default: eastus)"
                    if (-not [string]::IsNullOrWhiteSpace($userLocation)) {
                        $Location = $userLocation
                    }

                    Write-Info "Creating resource group: $ResourceGroupName in $Location..."
                    New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
                    Write-Success "Resource group created successfully"
                }
                else {
                    $selectedRG = $existingRGs[[int]$rgSelection - 2]
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
                $randomSuffix = Get-Date -Format "yyMMddHHmm"
                $OpenAIServiceName = "omg-psutilities-$randomSuffix"
                Write-Info "Generated Azure OpenAI Service name: $OpenAIServiceName"
            }

            # Create Azure OpenAI Service
            Write-Step "Creating Azure OpenAI Service: $OpenAIServiceName"
            $getAzCognitiveServicesParams = @{
                ResourceGroupName = $ResourceGroupName
                Name              = $OpenAIServiceName
                ErrorAction       = 'SilentlyContinue'
            }
            $openAIService = Get-AzCognitiveServicesAccount @getAzCognitiveServicesParams

            if ($openAIService) {
                Write-Info "Azure OpenAI Service '$OpenAIServiceName' already exists"
            }
            else {
                Write-Info "Creating Azure OpenAI Service in $Location... (This may take 2-3 minutes)"

                $newAzCognitiveServicesParams = @{
                    ResourceGroupName   = $ResourceGroupName
                    Name                = $OpenAIServiceName
                    Type                = "OpenAI"
                    SkuName             = "S0"
                    Location            = $Location
                    CustomSubdomainName = $OpenAIServiceName
                }

                try {
                    $openAIService = New-AzCognitiveServicesAccount @newAzCognitiveServicesParams
                    Write-Success "Azure OpenAI Service created successfully"
                }
                catch {
                    Write-ErrorMsg "Failed to create Azure OpenAI Service: $($_.Exception.Message)"
                    Write-Info "Common issues:"
                    Write-Info "  - Azure OpenAI access not approved for your subscription (Request access at: https://aka.ms/oai/access)"
                    Write-Info "  - Name already taken (try a different name)"
                    Write-Info "  - Region not supporting Azure OpenAI (try: eastus, westeurope, or swedencentral)"
                    throw
                }
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

                # Model version mapping - using latest non-deprecated versions
                $modelVersion = switch ($ModelName) {
                    'gpt-4' { 'turbo-2024-04-09' }
                    'gpt-4-turbo' { 'turbo-2024-04-09' }
                    'gpt-4o' { '2024-08-06' }
                    'gpt-35-turbo' { '0125' }
                    default { 'turbo-2024-04-09' }
                }

                # Adjust model name for newer versions
                $actualModelName = switch ($ModelName) {
                    'gpt-4' { 'gpt-4' }
                    'gpt-4-turbo' { 'gpt-4' }
                    'gpt-4o' { 'gpt-4o' }
                    'gpt-35-turbo' { 'gpt-35-turbo' }
                    default { 'gpt-4' }
                }

                $deployOutput = az cognitiveservices account deployment create `
                    --resource-group $ResourceGroupName `
                    --name $OpenAIServiceName `
                    --deployment-name $DeploymentName `
                    --model-name $actualModelName `
                    --model-version $modelVersion `
                    --model-format OpenAI `
                    --sku-capacity 1 `
                    --sku-name "Standard" 2>&1

                # Check for errors in output
                if ($LASTEXITCODE -ne 0) {
                    Write-ErrorMsg "Deployment creation failed!"
                    Write-Host $deployOutput -ForegroundColor Red
                    Write-Info "`nYou need to create the deployment manually in Azure Portal:"
                    Write-Info "  1. Go to: https://portal.azure.com"
                    Write-Info "  2. Navigate to: $ResourceGroupName > $OpenAIServiceName > Model deployments"
                    Write-Info "  3. Click 'Create new deployment' or 'Manage Deployments'"
                    Write-Info "  4. Select the latest available model version"
                    Write-Info "  5. Name it: $DeploymentName"
                }
                elseif ($deployOutput -match 'ERROR:|deprecated') {
                    Write-ErrorMsg "Deployment created with warnings:"
                    Write-Host $deployOutput -ForegroundColor Yellow
                    Write-Info "`nConsider updating the model version in Azure Portal if needed"
                }
                else {
                    Write-Success "Model deployment created successfully"
                }
            }

            # Set environment variables
            Write-Step "Setting Environment Variables"

            Set-PSUUserEnvironmentVariable -Name 'API_KEY_AZURE_OPENAI' -Value $apiKey
            Set-PSUUserEnvironmentVariable -Name 'AZURE_OPENAI_ENDPOINT' -Value $endpoint
            Set-PSUUserEnvironmentVariable -Name 'AZURE_OPENAI_DEPLOYMENT' -Value $DeploymentName

            Write-Success "Environment variables set successfully (User level)"
            Write-Info "Variables are now available in this session and will persist for your user account"
            Write-Info "To use in new PowerShell sessions, restart PowerShell or open a new window"

            # Return configuration object
            [PSCustomObject]@{
                ResourceGroupName   = $ResourceGroupName
                ServiceName         = $OpenAIServiceName
                Location            = $Location
                DeploymentName      = $DeploymentName
                ModelName           = $ModelName
                Endpoint            = $endpoint
                ApiKey              = $apiKey
                SubscriptionId      = $context.Subscription.Id
                SubscriptionName    = $context.Subscription.Name
                PSTypeName          = 'PSU.AzureOpenAI.Configuration'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}