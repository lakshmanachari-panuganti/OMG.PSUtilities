# Azure Deployment Scripts for OMG.PSUtilities

## 📋 Overview

This folder contains automated PowerShell scripts to deploy Azure Function App and Azure API Management (APIM) for the **OMG.PSUtilities.AI** module proxy service.

### Cross-Account Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  ACCOUNT A (Original - OpenAI Credentials)                 │
│  - Azure OpenAI Service                                     │
│  - API Key, Endpoint, Deployment                           │
│  - Billing: OpenAI API usage costs                         │
└─────────────────────────────────────────────────────────────┘
                          ↓ (API calls)
┌─────────────────────────────────────────────────────────────┐
│  ACCOUNT B (Target - Infrastructure)                       │
│  - Azure Function App (deployed here)                      │
│  - Azure APIM (deployed here)                              │
│  - Uses Account A's OpenAI credentials via env vars        │
│  - Billing: Function App + APIM infrastructure costs       │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Scripts Included

| Script | Purpose | Duration |
|--------|---------|----------|
| **Deploy-AzureFunctionApp.ps1** | Deploy Function App to Account B with Account A's OpenAI credentials | ~3-4 minutes |
| **Deploy-APIM.ps1** | Create APIM instance and configure rate limiting policies | ~10-15 minutes |
| **Test-DeployedProxy.ps1** | Validate deployed endpoints (Function App and/or APIM) | ~10 seconds |
| **Get-DeploymentInfo.ps1** | Retrieve deployment details (URLs, keys, IPs, configuration) | ~5 seconds |

---

## 🚀 Quick Start (Complete Deployment)

### Prerequisites

1. **Azure CLI** installed
   ```powershell
   # Check if installed
   az --version
   
   # If not: https://aka.ms/installazurecli
   ```

2. **Azure Functions Core Tools** installed
   ```powershell
   # Check if installed
   func --version
   
   # If not: https://aka.ms/func-core-tools
   ```

3. **Azure OpenAI Credentials** from Account A:
   - API Key
   - Endpoint (e.g., `https://myopenai.openai.azure.com`)
   - Deployment name (e.g., `gpt-4o`)

4. **Access to Account B** (target Azure subscription)

---

### Step 1: Deploy Function App

```powershell
cd "C:\repos\OMG.PSUtilities\Module Developer Tools\Azure-Deployment-Scripts"

.\Deploy-AzureFunctionApp.ps1 `
    -TargetSubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -ResourceGroupName "rg-psu-openai-proxy" `
    -AzureOpenAIKey "<ACCOUNT-A-OPENAI-KEY>" `
    -AzureOpenAIEndpoint "https://<ACCOUNT-A-RESOURCE>.openai.azure.com" `
    -AzureOpenAIDeployment "gpt-4o"
```

**Output:**
- Function App URL (with key)
- Outbound IPs (for Account A's firewall)
- `deployment-info.json` file created

**Time:** ~3-4 minutes

---

### Step 2: Test Function App

```powershell
# Get Function URL from Step 1 output
.\Test-DeployedProxy.ps1 -FunctionUrl "https://psu-openai-proxy-xxxx.azurewebsites.net/api/ProxyOpenAI?code=..."
```

**Expected Output:**
```
✅ SUCCESS!
Response: Azure OpenAI is Microsoft's cloud service...
Usage:
  Prompt Tokens:     12
  Completion Tokens: 28
  Total Tokens:      40
```

---

### Step 3: Deploy APIM (Optional but Recommended)

```powershell
.\Deploy-APIM.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -ResourceGroupName "rg-psu-openai-proxy" `
    -PublisherEmail "your@email.com" `
    -PublisherName "Your Name" `
    -FunctionAppName "psu-openai-proxy-xxxx"
```

**Output:**
- APIM Gateway URL
- API Endpoint URL
- Subscription Key
- `apim-info.json` file created

**Time:** ~10-15 minutes (APIM provisioning is slow)

---

### Step 4: Test APIM Endpoint

```powershell
# Get APIM URL and Subscription Key from Step 3 output
.\Test-DeployedProxy.ps1 `
    -APIMUrl "https://psu-openai-apim.azure-api.net/openai/ProxyOpenAI" `
    -SubscriptionKey "<SUBSCRIPTION-KEY>"

# Test rate limiting (send 10 requests)
.\Test-DeployedProxy.ps1 `
    -APIMUrl "https://psu-openai-apim.azure-api.net/openai/ProxyOpenAI" `
    -SubscriptionKey "<SUBSCRIPTION-KEY>" `
    -RunMultipleTests `
    -NumberOfTests 10
```

---

### Step 5: Get Deployment Info (Anytime)

```powershell
.\Get-DeploymentInfo.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -ResourceGroupName "rg-psu-openai-proxy" `
    -FunctionAppName "psu-openai-proxy-xxxx" `
    -APIMName "psu-openai-apim" `
    -ExportToFile
```

**Output:**
- All URLs, keys, and configuration
- `deployment-details.json` file created

---

## 📊 Detailed Script Documentation

### Deploy-AzureFunctionApp.ps1

**Purpose:** Deploy Azure Function App to Account B with Account A's OpenAI credentials.

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `TargetSubscriptionId` | Yes | - | Azure subscription ID (Account B) |
| `ResourceGroupName` | Yes | - | Resource group name to create/use |
| `FunctionAppName` | No | `psu-openai-proxy-XXXX` | Globally unique function app name |
| `Location` | No | `eastus2` | Azure region |
| `SourceFunctionPath` | No | `..\..\AzureFunction-OpenAI-Proxy` | Path to function code |
| `AzureOpenAIKey` | Yes | - | Account A's OpenAI API key |
| `AzureOpenAIEndpoint` | Yes | - | Account A's OpenAI endpoint |
| `AzureOpenAIDeployment` | Yes | - | Account A's deployment name |
| `AzureOpenAIApiVersion` | No | `2024-12-01-preview` | OpenAI API version |

**What It Does:**
1. Validates prerequisites (Azure CLI, Functions Core Tools)
2. Logs into Account B (prompts if needed)
3. Creates resource group
4. Creates storage account
5. Creates Function App (PowerShell 7.4)
6. Configures environment variables with Account A's credentials
7. Deploys function code
8. Returns function URL and outbound IPs

**Example:**
```powershell
.\Deploy-AzureFunctionApp.ps1 `
    -TargetSubscriptionId "abc-123" `
    -ResourceGroupName "rg-proxy" `
    -AzureOpenAIKey "key123" `
    -AzureOpenAIEndpoint "https://myopenai.openai.azure.com" `
    -AzureOpenAIDeployment "gpt-4o"
```

---

### Deploy-APIM.ps1

**Purpose:** Create APIM instance and import Function App with rate limiting.

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `SubscriptionId` | Yes | - | Azure subscription ID (Account B) |
| `ResourceGroupName` | Yes | - | Resource group name (same as Function App) |
| `APIMName` | No | `psu-openai-apim-XXX` | Globally unique APIM name |
| `PublisherEmail` | Yes | - | Email for APIM publisher |
| `PublisherName` | Yes | - | Name of APIM publisher |
| `FunctionAppName` | Yes | - | Name of deployed Function App |
| `APISuffix` | No | `openai` | URL suffix for API |
| `RateLimitCalls` | No | `100` | Calls per hour per subscription |
| `QuotaCalls` | No | `50000` | Calls per month per subscription |

**What It Does:**
1. Verifies Function App exists
2. Creates APIM instance (Consumption tier)
3. Imports Function App as API backend
4. Configures rate limiting policy:
   - 100 calls/hour per subscription
   - 50,000 calls/month per subscription
5. Returns APIM endpoint and subscription key

**Example:**
```powershell
.\Deploy-APIM.ps1 `
    -SubscriptionId "abc-123" `
    -ResourceGroupName "rg-proxy" `
    -PublisherEmail "admin@company.com" `
    -PublisherName "Admin" `
    -FunctionAppName "psu-openai-proxy-1234"
```

---

### Test-DeployedProxy.ps1

**Purpose:** Validate deployed proxy endpoints.

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `FunctionUrl` | Yes (if not using APIM) | - | Function App URL with key |
| `APIMUrl` | Yes (if using APIM) | - | APIM API endpoint |
| `SubscriptionKey` | Yes (if using APIM) | - | APIM subscription key |
| `TestPrompt` | No | `Explain Azure OpenAI in one sentence` | Test prompt |
| `MaxTokens` | No | `100` | Maximum tokens for response |
| `RunMultipleTests` | No | `$false` | Run multiple tests for rate limit validation |
| `NumberOfTests` | No | `5` | Number of tests when RunMultipleTests is true |

**Examples:**
```powershell
# Test Function App directly
.\Test-DeployedProxy.ps1 -FunctionUrl "https://..."

# Test APIM endpoint
.\Test-DeployedProxy.ps1 -APIMUrl "https://..." -SubscriptionKey "key"

# Test rate limiting (10 requests)
.\Test-DeployedProxy.ps1 -APIMUrl "https://..." -SubscriptionKey "key" -RunMultipleTests -NumberOfTests 10
```

---

### Get-DeploymentInfo.ps1

**Purpose:** Retrieve all deployment details.

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `SubscriptionId` | Yes | - | Azure subscription ID |
| `ResourceGroupName` | Yes | - | Resource group name |
| `FunctionAppName` | Yes | - | Function App name |
| `APIMName` | No | - | APIM instance name (if deployed) |
| `ExportToFile` | No | `$false` | Export results to `deployment-details.json` |

**Example:**
```powershell
.\Get-DeploymentInfo.ps1 `
    -SubscriptionId "abc-123" `
    -ResourceGroupName "rg-proxy" `
    -FunctionAppName "psu-openai-proxy-1234" `
    -APIMName "psu-openai-apim" `
    -ExportToFile
```

---

## 🔒 Security Considerations

### Account A (OpenAI) Firewall

If Account A's Azure OpenAI has firewall rules enabled:

1. Get Function App outbound IPs:
   ```powershell
   .\Get-DeploymentInfo.ps1 -SubscriptionId "..." -ResourceGroupName "..." -FunctionAppName "..."
   ```

2. Add IPs to Account A's OpenAI firewall:
   - Azure Portal (Account A) → Azure OpenAI → Networking → Firewall
   - Add each outbound IP from Function App

### Environment Variables

Account A's credentials are stored in Function App environment variables:
- `AZURE_OPENAI_KEY` (encrypted at rest)
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_DEPLOYMENT`
- `AZURE_OPENAI_API_VERSION`

**Never commit these to Git!** They are configured via Azure CLI during deployment.

### APIM Subscription Keys

- Each user/application gets a unique subscription key
- Keys can be regenerated via Azure Portal
- Keys are validated by APIM before forwarding to Function App
- Function App never sees the subscription key (removed by APIM policy)

---

## 💰 Cost Estimate

### Account A (OpenAI Costs)

```
Azure OpenAI (GPT-4o-mini):
- 5 million calls/month
- 500 tokens avg per call
- Input: ₹1,875/month
- Output: ₹1,500/month
────────────────────────────
Total: ₹3,375/month
```

### Account B (Infrastructure Costs)

```
Azure Function (Consumption):    ₹902/month
Azure APIM (Consumption):         ₹1,169/month
Data Transfer:                    ₹73/month
────────────────────────────────────────────
Total: ₹2,144/month
```

### Combined Total: ₹5,519/month (~₹66,000/year)

**Per call cost:** ₹0.0011 (₹5,519 / 5M calls)

---

## 🐛 Troubleshooting

### Azure CLI Login Issues

```powershell
# Clear cached credentials
az logout

# Login with specific tenant
az login --tenant "tenant-id"

# List available subscriptions
az account list --output table

# Set specific subscription
az account set --subscription "subscription-id"
```

### Function Deployment Fails

```powershell
# Check Azure CLI version (needs 2.50+)
az --version

# Check Functions Core Tools version (needs 4.x)
func --version

# View deployment logs
func azure functionapp logstream <function-app-name>

# Manually publish
cd "C:\repos\OMG.PSUtilities\AzureFunction-OpenAI-Proxy"
func azure functionapp publish <function-app-name> --powershell
```

### APIM Provisioning Stuck

APIM Consumption tier can take 5-15 minutes. Check status:

```powershell
az apim show --name <apim-name> --resource-group <rg-name> --query provisioningState
```

If stuck longer than 20 minutes, cancel and retry with different name.

### Function Returns 500 Error

Check environment variables are set correctly:

```powershell
az functionapp config appsettings list `
    --name <function-app-name> `
    --resource-group <rg-name> `
    --output table
```

Verify OpenAI credentials work:

```powershell
# Test directly from PowerShell
$headers = @{ "api-key" = "<ACCOUNT-A-KEY>" }
$body = @{ messages = @(@{ role = "user"; content = "test" }) } | ConvertTo-Json
Invoke-RestMethod -Uri "https://<ACCOUNT-A-ENDPOINT>/openai/deployments/<DEPLOYMENT>/chat/completions?api-version=2024-12-01-preview" -Headers $headers -Method POST -Body $body -ContentType "application/json"
```

---

## 📝 Generated Files

Scripts create these JSON files in the same directory:

- **deployment-info.json** - Function App deployment details (from Deploy-AzureFunctionApp.ps1)
- **apim-info.json** - APIM deployment details (from Deploy-APIM.ps1)
- **deployment-details.json** - Combined details (from Get-DeploymentInfo.ps1 -ExportToFile)

**Example deployment-info.json:**
```json
{
  "FunctionAppName": "psu-openai-proxy-1234",
  "ResourceGroupName": "rg-psu-openai-proxy",
  "FunctionUrl": "https://psu-openai-proxy-1234.azurewebsites.net/api/ProxyOpenAI?code=...",
  "OutboundIPs": "40.71.11.80,40.71.11.81",
  "OpenAIEndpoint": "https://myopenai.openai.azure.com",
  "DeploymentDate": "2025-12-05 14:30:00"
}
```

---

## 🎯 Next Steps After Deployment

1. **Update PowerShell Module**
   - Encode new Function Key or APIM Subscription Key
   - Update `OMG.PSUtilities.AI.psm1` with new proxy URL
   - Test locally before publishing

2. **Generate User Subscription Keys** (if using APIM)
   - Azure Portal → APIM → Subscriptions → Add
   - Provide keys to users/applications

3. **Monitor Usage**
   - Azure Portal → Function App → Monitor → Metrics
   - Azure Portal → APIM → Analytics

4. **Set Up Alerts** (optional)
   - Alert on high token usage
   - Alert on rate limit violations
   - Alert on 5xx errors

---

## 📚 Related Documentation

- **Azure Function Code:** `..\..\AzureFunction-OpenAI-Proxy\`
- **Module Integration:** `..\..\OMG.PSUtilities.AI\`
- **Deployment Guide:** `..\..\AzureFunction-OpenAI-Proxy\README.md`
- **Quick Start:** `..\..\AzureFunction-OpenAI-Proxy\QUICK-START.md`

---

## 👤 Author

**Lakshmanachari Panuganti**  
Created: 2025-12-05  
Version: 1.0

---

## 📞 Support

For issues or questions:
1. Check troubleshooting section above
2. Review Azure Function logs: `func azure functionapp logstream <app-name>`
3. Check APIM diagnostics in Azure Portal
4. Verify Account A's OpenAI endpoint is accessible from Account B's outbound IPs
