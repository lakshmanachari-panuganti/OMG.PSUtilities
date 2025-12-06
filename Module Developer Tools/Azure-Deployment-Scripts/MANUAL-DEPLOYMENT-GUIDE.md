# Manual Deployment Guide - OpenAI Proxy Function App

Due to Azure API authentication issues with both Azure CLI and PowerShell Az modules (SubscriptionNotFound error), follow this manual deployment guide.

## Resource Naming Convention

All resources use the `omg-psu-openai-*` prefix for consistency:

- **Resource Group**: `omg-psu-openai-rg`
- **Storage Account**: `omgpsuopenaist` (lowercase/numbers only, max 24 chars)
- **Function App**: `omg-psu-openai-funcapp`
- **APIM** (optional): `omg-psu-openai-apim`

## Prerequisites Checklist

- [x] Azure subscription: payasyougo (88355f02-7508-401e-a6c0-24993fad9e77)
- [x] Resource group created: omg-psu-openai-rg (Location: East US 2)
- [x] OpenAI credentials available:
  - API Key: $env:API_KEY_AZURE_OPENAI
  - Endpoint: $env:AZURE_OPENAI_ENDPOINT
  - Deployment: $env:AZURE_OPENAI_DEPLOYMENT
  - API Version: $env:AZURE_OPENAI_API_VERSION

## Step-by-Step Manual Deployment

### Step 1: Create Storage Account (Portal)

1. Navigate to: https://portal.azure.com/#create/Microsoft.StorageAccount-ARM
2. Fill in the following:
   - **Subscription**: payasyougo
   - **Resource Group**: omg-psu-openai-rg
   - **Storage Account Name**: `omgpsuopenaist`
   - **Region**: East US 2
   - **Performance**: Standard
   - **Redundancy**: Locally-redundant storage (LRS)
3. Click **Review + Create** → **Create**
4. Wait ~2 minutes for deployment

### Step 2: Create Function App (Portal)

1. Navigate to: https://portal.azure.com/#create/Microsoft.FunctionApp
2. **Basics Tab**:
   - **Subscription**: payasyougo
   - **Resource Group**: omg-psu-openai-rg
   - **Function App Name**: `omg-psu-openai-funcapp`
   - **Publish**: Code
   - **Runtime Stack**: PowerShell Core
   - **Version**: 7.4
   - **Region**: East US 2
3. **Hosting Tab**:
   - **Storage Account**: omgpsuopenaist (select existing)
   - **Operating System**: Windows
   - **Plan Type**: Consumption (Serverless)
4. **Networking Tab**: (Leave defaults)
5. **Monitoring Tab**: 
   - **Enable Application Insights**: Yes (optional but recommended)
6. Click **Review + Create** → **Create**
7. Wait ~5 minutes for deployment

### Step 3: Configure Environment Variables (Portal)

1. Go to: https://portal.azure.com/#browse/Microsoft.Web%2Fsites
2. Click on `omg-psu-openai-funcapp`
3. Left menu → **Configuration** → **Application settings**
4. Click **+ New application setting** and add these 4 settings:

   | Name | Value |
   |------|-------|
   | `AZURE_OPENAI_KEY` | (Copy from `$env:API_KEY_AZURE_OPENAI`) |
   | `AZURE_OPENAI_ENDPOINT` | (Copy from `$env:AZURE_OPENAI_ENDPOINT`) |
   | `AZURE_OPENAI_DEPLOYMENT` | (Copy from `$env:AZURE_OPENAI_DEPLOYMENT`) |
   | `AZURE_OPENAI_API_VERSION` | (Copy from `$env:AZURE_OPENAI_API_VERSION`) |

5. Click **Save** (top of page)
6. Click **Continue** to confirm restart

**PowerShell Commands to Get Values:**
```powershell
# Run these to display your environment variables
Write-Host "AZURE_OPENAI_KEY: $env:API_KEY_AZURE_OPENAI"
Write-Host "AZURE_OPENAI_ENDPOINT: $env:AZURE_OPENAI_ENDPOINT"
Write-Host "AZURE_OPENAI_DEPLOYMENT: $env:AZURE_OPENAI_DEPLOYMENT"
Write-Host "AZURE_OPENAI_API_VERSION: $env:AZURE_OPENAI_API_VERSION"
```

### Step 4: Deploy Function Code (PowerShell)

1. Open PowerShell terminal
2. Navigate to function code directory:
   ```powershell
   cd "C:\repos\OMG.PSUtilities\AzureFunction-OpenAI-Proxy"
   ```
3. Deploy code to Function App:
   ```powershell
   func azure functionapp publish omg-psu-openai-funcapp
   ```
4. Wait for deployment to complete (~2-3 minutes)
5. Note the Function URL from output (e.g., `https://omg-psu-openai-funcapp.azurewebsites.net/api/ProxyOpenAI`)

### Step 5: Get Function Key (Portal)

1. Go to: https://portal.azure.com/#browse/Microsoft.Web%2Fsites
2. Click on `omg-psu-openai-funcapp`
3. Left menu → **Functions** → Click `ProxyOpenAI`
4. Left menu → **Function Keys**
5. Copy the `default` key value
6. Save this key securely (you'll need it for testing)

### Step 6: Test Function Endpoint (PowerShell)

```powershell
# Navigate to test scripts
cd "C:\repos\OMG.PSUtilities\Module Developer Tools\Azure-Deployment-Scripts"

# Run test script
.\Test-DeployedProxy.ps1 -FunctionUrl "https://omg-psu-openai-funcapp.azurewebsites.net/api/ProxyOpenAI" -FunctionKey "<YOUR_FUNCTION_KEY>"
```

**Expected Output:**
```
Test 1: Basic Proxy Functionality
[SUCCESS] Function returned valid response
Completion: <AI-generated text>
Total Tokens: <token count>
```

### Step 7 (Optional): Deploy API Management

If you want rate limiting (100 calls/hour, 50K calls/month):

```powershell
cd "C:\repos\OMG.PSUtilities\Module Developer Tools\Azure-Deployment-Scripts"

.\Deploy-APIM.ps1 `
    -SubscriptionId "88355f02-7508-401e-a6c0-24993fad9e77" `
    -ResourceGroupName "omg-psu-openai-rg" `
    -ApimName "omg-psu-openai-apim" `
    -Location "eastus2" `
    -PublisherEmail "your-email@example.com" `
    -PublisherName "Your Name" `
    -FunctionAppName "omg-psu-openai-funcapp"
```

**Note**: APIM provisioning takes ~15-20 minutes.

## Deployment Summary Checklist

- [ ] Storage Account created: `omgpsuopenaist`
- [ ] Function App created: `omg-psu-openai-funcapp`
- [ ] Environment variables configured (4 settings)
- [ ] Function code deployed via `func azure functionapp publish`
- [ ] Function key retrieved from Portal
- [ ] Endpoint tested successfully
- [ ] (Optional) APIM deployed with rate limiting

## Quick Reference

### Resource URLs

| Resource | URL |
|----------|-----|
| Resource Group | https://portal.azure.com/#@/resource/subscriptions/88355f02-7508-401e-a6c0-24993fad9e77/resourceGroups/omg-psu-openai-rg/overview |
| Function App | https://portal.azure.com/#@/resource/subscriptions/88355f02-7508-401e-a6c0-24993fad9e77/resourceGroups/omg-psu-openai-rg/providers/Microsoft.Web/sites/omg-psu-openai-funcapp/appServices |
| Storage Account | https://portal.azure.com/#@/resource/subscriptions/88355f02-7508-401e-a6c0-24993fad9e77/resourceGroups/omg-psu-openai-rg/providers/Microsoft.Storage/storageAccounts/omgpsuopenaist/overview |

### PowerShell Helper Commands

```powershell
# Display environment variables
Write-Host "AZURE_OPENAI_KEY: $env:API_KEY_AZURE_OPENAI"
Write-Host "AZURE_OPENAI_ENDPOINT: $env:AZURE_OPENAI_ENDPOINT"
Write-Host "AZURE_OPENAI_DEPLOYMENT: $env:AZURE_OPENAI_DEPLOYMENT"
Write-Host "AZURE_OPENAI_API_VERSION: $env:AZURE_OPENAI_API_VERSION"

# Deploy function code
cd "C:\repos\OMG.PSUtilities\AzureFunction-OpenAI-Proxy"
func azure functionapp publish omg-psu-openai-funcapp

# Test deployed function
cd "C:\repos\OMG.PSUtilities\Module Developer Tools\Azure-Deployment-Scripts"
.\Test-DeployedProxy.ps1 -FunctionUrl "https://omg-psu-openai-funcapp.azurewebsites.net/api/ProxyOpenAI" -FunctionKey "<YOUR_KEY>"

# Get deployment info
.\Get-DeploymentInfo.ps1 -FunctionAppName "omg-psu-openai-funcapp" -ResourceGroupName "omg-psu-openai-rg"
```

## Troubleshooting

### Issue: Function deployment fails with "Publish operation failed"

**Solution**: Ensure Function App is fully provisioned (check Portal status). Wait 5 minutes after creation before deploying code.

### Issue: Function returns 500 error

**Solution**: Check environment variables are set correctly:
1. Portal → Function App → Configuration
2. Verify all 4 AZURE_OPENAI_* settings exist
3. Click **Save** and wait for restart

### Issue: Function returns 401 Unauthorized from OpenAI

**Solution**: 
1. Verify `AZURE_OPENAI_KEY` matches your actual OpenAI key
2. Check key hasn't expired in Azure OpenAI service
3. Ensure endpoint URL is correct (no trailing slashes)

### Issue: Cannot retrieve function key from Portal

**Solution**: Use Azure PowerShell:
```powershell
$keys = Invoke-AzResourceAction `
    -ResourceGroupName "omg-psu-openai-rg" `
    -ResourceType "Microsoft.Web/sites/functions" `
    -ResourceName "omg-psu-openai-funcapp/ProxyOpenAI" `
    -Action "listkeys" `
    -ApiVersion "2022-03-01" `
    -Force

$keys.default
```

## Next Steps After Deployment

1. **Update PowerShell Module**: 
   - Encode Function Key to Base64
   - Update `OMG.PSUtilities.AI.psm1` with new proxy URL

2. **Monitor Usage**:
   - Portal → Function App → Monitor (view invocations, errors)
   - Application Insights (if enabled) for detailed telemetry

3. **Consider APIM** (Optional):
   - Adds rate limiting: 100 calls/hour per user
   - Quota: 50K calls/month
   - Subscription key management
   - Cost: ~$0.50/month (Consumption tier)

## Support

If you encounter issues not covered in troubleshooting:
1. Check Azure Service Health: https://status.azure.com/
2. Review Function App logs in Portal → Monitor → Log Stream
3. Test OpenAI endpoint directly to isolate function vs. OpenAI issues
