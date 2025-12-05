# Azure OpenAI Proxy for OMG.PSUtilities

## 📋 Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Benefits](#benefits)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Guide](#deployment-guide)
- [Testing](#testing)
- [Integration](#integration)
- [Security](#security)
- [Cost Management](#cost-management)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This Azure Function acts as a **secure proxy** between your PowerShell module (`OMG.PSUtilities.AI`) and Azure OpenAI. It allows users to use AI features **without needing their own Azure OpenAI account or API keys**.

### How It Works

```
User's PowerShell
      ↓
Invoke-PSUPromptOnAzureOpenAi -Prompt "Hello"
      ↓
Azure Function Proxy (YOUR credentials stored securely)
      ↓
Azure OpenAI Service (GPT-4o, GPT-5, etc.)
      ↓
Response back to user
```

---

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────────┐
│  End User (PowerShell Module User)                        │
│  - No Azure OpenAI account needed                         │
│  - No API keys to manage                                  │
│  - Just calls: Invoke-PSUPromptOnAzureOpenAi -Prompt "..." │
└─────────────────────────┬──────────────────────────────────┘
                          │ HTTPS POST
                          │ { "Prompt": "...", "MaxTokens": 4096 }
                          ↓
┌────────────────────────────────────────────────────────────┐
│  Azure Function (PowerShell Runtime)                      │
│  Name: psu-openai-proxy                                   │
│                                                            │
│  Environment Variables (Set in Azure Portal):             │
│    AZURE_OPENAI_KEY = "<your-key>"                        │
│    AZURE_OPENAI_ENDPOINT = "https://..."                  │
│    AZURE_OPENAI_DEPLOYMENT = "gpt-4o"                     │
│                                                            │
│  Features:                                                 │
│    ✅ Authentication with Function Key                    │
│    ✅ Request validation                                  │
│    ✅ Error handling                                      │
│    ✅ Automatic scaling                                   │
└─────────────────────────┬──────────────────────────────────┘
                          │ Authenticated Request
                          │ Headers: { "api-key": "<your-key>" }
                          ↓
┌────────────────────────────────────────────────────────────┐
│  Azure OpenAI Service                                     │
│  - Your subscription                                      │
│  - Your deployments (GPT-4o, GPT-5, etc.)                │
│  - You pay for token usage                                │
└────────────────────────────────────────────────────────────┘
```

---

## ✨ Benefits

### For End Users
✅ **No Setup Required** - Just install the module and start using AI  
✅ **No Azure Account Needed** - No subscription or credit card required  
✅ **No API Key Management** - Nothing to configure  
✅ **Simple Usage** - One-line commands  

### For You (Module Maintainer)
✅ **Control Costs** - Monitor and limit usage  
✅ **Security** - Your credentials never exposed in code  
✅ **Scalability** - Auto-scales with demand  
✅ **Flexibility** - Easy to switch models or providers  
✅ **Analytics** - Track usage patterns  

---

## 📦 Prerequisites

### For Deployment (One-Time Setup)

1. **Azure Subscription**
   - Free tier available: https://azure.microsoft.com/free

2. **Azure CLI**
   ```powershell
   # Install Azure CLI
   winget install Microsoft.AzureCLI
   # OR download from: https://aka.ms/installazurecli
   ```

3. **Azure Functions Core Tools**
   ```powershell
   # Install Functions Core Tools
   npm install -g azure-functions-core-tools@4
   # OR download from: https://aka.ms/func-core-tools
   ```

4. **Azure OpenAI Resource**
   - Create in Azure Portal: https://portal.azure.com
   - Deploy a model (e.g., GPT-4o)
   - Copy: API Key, Endpoint, Deployment Name

---

## 🚀 Quick Start

### Step 1: Clone/Navigate to Project

```powershell
cd c:\repos\OMG.PSUtilities\AzureFunction-OpenAI-Proxy
```

### Step 2: Configure Local Settings

Edit `local.settings.json`:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AZURE_OPENAI_KEY": "YOUR_ACTUAL_API_KEY",
    "AZURE_OPENAI_ENDPOINT": "https://your-resource.openai.azure.com",
    "AZURE_OPENAI_DEPLOYMENT": "gpt-4o",
    "AZURE_OPENAI_API_VERSION": "2024-12-01-preview"
  }
}
```

### Step 3: Test Locally (Optional)

```powershell
# Start function locally
func start

# In another terminal, test it
.\Test-ProxyFunction.ps1 -ProxyUrl "http://localhost:7071/api/ProxyOpenAI"
```

### Step 4: Deploy to Azure

```powershell
.\Deploy-ToAzure.ps1 `
    -ResourceGroupName "rg-psu-openai-proxy" `
    -FunctionAppName "psu-openai-proxy" `
    -Location "eastus" `
    -AzureOpenAIKey "YOUR_API_KEY" `
    -AzureOpenAIEndpoint "https://your-resource.openai.azure.com" `
    -AzureOpenAIDeployment "gpt-4o"
```

---

## 📖 Deployment Guide (Step-by-Step)

### Option A: Automated Deployment Script

```powershell
# Run the deployment script with your credentials
.\Deploy-ToAzure.ps1 `
    -ResourceGroupName "rg-psu-openai-proxy" `
    -FunctionAppName "psu-openai-proxy-unique123" `
    -Location "eastus" `
    -AzureOpenAIKey "<your-key>" `
    -AzureOpenAIEndpoint "https://your-resource.openai.azure.com" `
    -AzureOpenAIDeployment "gpt-4o"
```

**What it does:**
1. ✅ Checks prerequisites (Azure CLI, Functions Core Tools)
2. ✅ Logs into Azure
3. ✅ Creates resource group
4. ✅ Creates storage account
5. ✅ Creates Function App
6. ✅ Configures environment variables (YOUR credentials)
7. ✅ Deploys function code
8. ✅ Shows function URL

**Output:**
```
╔════════════════════════════════════════════════════════════════════╗
║  DEPLOYMENT SUCCESSFUL!                                            ║
╚════════════════════════════════════════════════════════════════════╝

Your Function URL:
https://psu-openai-proxy.azurewebsites.net/api/ProxyOpenAI?code=abc123xyz...
```

### Option B: Manual Deployment (Azure Portal)

1. **Create Function App** in Azure Portal
   - Runtime: PowerShell 7.4
   - Plan: Consumption
   
2. **Configure Environment Variables**
   - Go to: Configuration → Application Settings
   - Add:
     - `AZURE_OPENAI_KEY` = your key
     - `AZURE_OPENAI_ENDPOINT` = your endpoint
     - `AZURE_OPENAI_DEPLOYMENT` = your deployment name

3. **Deploy Code**
   ```powershell
   func azure functionapp publish <your-function-app-name> --powershell
   ```

---

## 🧪 Testing

### Test Locally

```powershell
# Start function
func start

# Test in another terminal
.\Test-ProxyFunction.ps1 -ProxyUrl "http://localhost:7071/api/ProxyOpenAI"
```

### Test in Azure

```powershell
.\Test-ProxyFunction.ps1 -ProxyUrl "https://psu-openai-proxy.azurewebsites.net/api/ProxyOpenAI?code=YOUR_FUNCTION_KEY"
```

**Expected Output:**
```
═══════════════════════════════════════════════════
Testing OpenAI Proxy Function
═══════════════════════════════════════════════════

✅ SUCCESS! Proxy is working correctly.

Response:
Azure OpenAI is a cloud-based AI service offering powerful language models.

Token Usage:
  Prompt Tokens: 12
  Completion Tokens: 15
  Total Tokens: 27

Model: gpt-4o
```

---

## 🔗 Integration with PowerShell Module

### Update Your Module

Replace the current `Invoke-PSUPromptOnAzureOpenAi.ps1` with:
```powershell
Copy-Item `
    .\Invoke-PSUPromptOnAzureOpenAi-Proxy-Version.ps1 `
    ..\OMG.PSUtilities.AI\Public\Invoke-PSUPromptOnAzureOpenAi.ps1 `
    -Force
```

### Update Proxy URL

Edit the new function and replace:
```powershell
$ProxyUrl = "https://psu-openai-proxy.azurewebsites.net/api/ProxyOpenAI?code=YOUR_FUNCTION_KEY_HERE"
```

With your actual deployed URL.

### Usage Examples

```powershell
# Simple usage - uses proxy automatically
Invoke-PSUPromptOnAzureOpenAi -Prompt "Explain Azure"

# With JSON response
Invoke-PSUPromptOnAzureOpenAi -Prompt "Return JSON" -ReturnJsonResponse

# Users with their own Azure OpenAI can still use direct access
Invoke-PSUPromptOnAzureOpenAi `
    -Prompt "Hello" `
    -ApiKey "user-key" `
    -Endpoint "https://user-endpoint.openai.azure.com" `
    -Deployment "gpt-4o" `
    -UseDirectAccess
```

---

## 🔒 Security

### Function Key Authentication

Your Function URL includes a `code` parameter - this is your security key:
```
https://psu-openai-proxy.azurewebsites.net/api/ProxyOpenAI?code=abc123xyz...
                                                                ^^^^^^^^^^^
                                                                Function Key
```

**Best Practices:**
✅ Keep this URL private  
✅ Rotate keys periodically (Azure Portal → Function Keys)  
✅ Use Azure Key Vault for production  
✅ Monitor usage in Azure Portal  

### Credential Storage

**In Azure:**
- Environment variables are encrypted at rest
- Only accessible by your Function App
- Never exposed in logs or responses

**Never:**
❌ Commit `local.settings.json` to Git (already in `.gitignore`)  
❌ Share your Function URL publicly  
❌ Hard-code credentials in PowerShell module  

---

## 💰 Cost Management

### Azure Functions Pricing

**Consumption Plan (Pay-per-use):**
- First **1 million requests/month**: **FREE**
- After that: **$0.20 per million requests**
- Execution time: **$0.000016/GB-s**

**Example Monthly Cost:**
- 10,000 requests/month = **$0.00 (Free tier)**
- 5 million requests/month = **$0.80**

### Azure OpenAI Pricing

You pay for tokens used:
- **GPT-4o**: ~$5 per 1M input tokens, ~$15 per 1M output tokens
- **GPT-3.5**: ~$0.50 per 1M tokens

**Example Usage:**
- 1,000 prompts × 100 tokens/prompt = 100,000 tokens
- Cost: ~$0.50 - $2.00 depending on model

### Cost Control

**Monitor Usage:**
```powershell
# View metrics in Azure Portal
az monitor metrics list `
    --resource "/subscriptions/<sub-id>/resourceGroups/rg-psu-openai-proxy/providers/Microsoft.Web/sites/psu-openai-proxy" `
    --metric "FunctionExecutionCount"
```

**Set Budget Alerts:**
- Azure Portal → Cost Management → Budgets
- Create alert at $10/month

---

## 🐛 Troubleshooting

### Error: "Proxy not configured"

**Cause:** Environment variables not set in Azure Function  
**Fix:**
```powershell
az functionapp config appsettings set `
    --name psu-openai-proxy `
    --resource-group rg-psu-openai-proxy `
    --settings `
        "AZURE_OPENAI_KEY=<your-key>" `
        "AZURE_OPENAI_ENDPOINT=<your-endpoint>" `
        "AZURE_OPENAI_DEPLOYMENT=<your-deployment>"
```

### Error: "401 Unauthorized"

**Cause:** Invalid or expired Function Key  
**Fix:** Get new key from Azure Portal → Function Keys → Copy

### Error: "Timeout"

**Cause:** Large prompt or slow response  
**Fix:** Increase timeout in PowerShell call:
```powershell
Invoke-PSUPromptOnAzureOpenAi -Prompt "..." -TimeoutSeconds 600
```

### Function not responding

**Check logs:**
```powershell
# Stream logs from Azure
func azure functionapp logstream psu-openai-proxy
```

---

## 📚 Next Steps

1. ✅ Deploy the Azure Function
2. ✅ Test with `Test-ProxyFunction.ps1`
3. ✅ Update your PowerShell module
4. ✅ Test integration
5. ✅ Monitor usage and costs
6. ✅ Publish to PowerShell Gallery!

---

## 📞 Support

- **GitHub Issues**: https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/issues
- **LinkedIn**: https://www.linkedin.com/in/lakshmanachari-panuganti/

---

## 📄 License

Same as OMG.PSUtilities module.
