# Complete Manual Azure Function Deployment Guide
## Learn Azure Step-by-Step

This guide walks you through every step manually to help you understand how Azure Function Apps work with OpenAI integration.

---

## 🎯 PROJECT GOAL

**Deploy a serverless PowerShell Function App that acts as a secure proxy for Azure OpenAI API calls.**

### Why This Architecture?
- **Hide OpenAI credentials** from public PowerShell module users
- **Control access** through Azure Function authentication
- **Monitor usage** via Application Insights
- **Scale automatically** with Azure Consumption Plan
- **Future-ready** for rate limiting with APIM

### Architecture Diagram
```
PowerShell Module Users
         ↓
Azure Function App (Central India)
    - PowerShell 7.4 Runtime
    - HTTP Trigger: ProxyOpenAI
    - Environment Variables (OpenAI credentials)
         ↓
Azure OpenAI Service (Different Account)
    - Endpoint: https://omg-openai-2511210412.openai.azure.com
    - Deployment: model-router
    - API Version: 2024-12-01-preview
         ↓
    Returns AI Response
```

---

## ✅ CURRENT DEPLOYMENT STATUS

### Resources Already Created:

| Resource | Name | Status | Location |
|----------|------|--------|----------|
| Resource Group | omg-psu-openai-rg | ✅ Created | Central India |
| Storage Account | omgpsuopenaist | ✅ Created | Central India |
| Function App | omg-psu-openai-funcapp | ✅ Created | Central India |
| App Service Plan | ASP-omgpsuopenairg-b90b | ✅ Created | Central India (Consumption) |
| Application Insights | omg-psu-openai-funcapp | ✅ Created | Central India |

### Configuration Already Done:

| Setting | Value | Status |
|---------|-------|--------|
| AZURE_OPENAI_KEY | 3bLIU...*** | ✅ Configured |
| AZURE_OPENAI_ENDPOINT | https://omg-openai-2511210412.openai.azure.com | ✅ Configured |
| AZURE_OPENAI_DEPLOYMENT | model-router | ✅ Configured |
| AZURE_OPENAI_API_VERSION | 2024-12-01-preview | ✅ Configured |

### What's Remaining:

1. ⏳ Deploy function code to Azure
2. ⏳ Test the function endpoint
3. ⏳ Get function authentication key
4. ⏳ Test with real OpenAI request
5. ⏳ (Optional) Deploy APIM for rate limiting
6. ⏳ Update PowerShell module with new proxy URL

---

## 📋 STEP-BY-STEP MANUAL DEPLOYMENT

### STEP 1: Deploy Function Code via Azure Portal

**Goal**: Upload your PowerShell function code to Azure Function App

#### 1.1 Locate the ZIP File
- **Path**: `C:\Users\E092721\Downloads\function-app.zip`
- **Size**: ~4 KB
- **Contents**: 
  - `ProxyOpenAI/run.ps1` (main function code)
  - `ProxyOpenAI/function.json` (trigger configuration)
  - `host.json` (runtime settings)
  - `profile.ps1` (startup script)
  - `requirements.psd1` (dependencies)

#### 1.2 Open Azure Portal
1. Go to: https://portal.azure.com
2. Sign in with: Lakshmanachari@hotmail.com
3. Click on "Resource groups" in left menu (or search for it)
4. Click on: **omg-psu-openai-rg**
5. You'll see 5 resources listed

#### 1.3 Navigate to Function App
1. Click on: **omg-psu-openai-funcapp** (Function App icon)
2. Wait for the Function App overview page to load
3. You should see:
   - Status: Running
   - URL: https://omg-psu-openai-funcapp.azurewebsites.net
   - Location: Central India
   - Runtime: PowerShell Core 7.4

#### 1.4 Deploy Code (Method A: Deployment Center)
1. **In left sidebar**, scroll down to find **"Deployment"** section
2. Click: **"Deployment Center"**
3. You'll see deployment methods:
   - GitHub
   - Local Git
   - Bitbucket
   - **ZIP Deploy** ← Select this
4. Click on **"ZIP Deploy"** or **"Manual Deployment"** tab
5. You'll see an upload area
6. Click **"Browse"** button
7. Navigate to: `C:\Users\E092721\Downloads\function-app.zip`
8. Select the file
9. Click **"Upload"** or **"Deploy"** button
10. **Wait 1-2 minutes** - You'll see progress indicator
11. ✅ Success message appears: "Deployment successful"

#### 1.5 Deploy Code (Method B: Advanced Tools - If Method A Not Available)
1. **In left sidebar**, scroll to **"Development Tools"** section
2. Click: **"Advanced Tools"**
3. Click: **"Go →"** button (opens Kudu console in new tab)
4. **In Kudu console**, click top menu: **"Tools"**
5. Select: **"Zip Push Deploy"**
6. You'll see a drag-and-drop area
7. **Drag** `function-app.zip` from Downloads folder and **drop** onto the page
8. **Wait 1-2 minutes** - Progress bar shows upload
9. ✅ Page shows "Deployment successful"

#### 1.6 Verify Deployment
1. **Go back** to Function App overview page
2. **In left sidebar**, click: **"Functions"**
3. You should now see: **ProxyOpenAI** function listed
4. Click on **"ProxyOpenAI"**
5. You'll see:
   - Function name: ProxyOpenAI
   - Status: Enabled
   - Trigger: HTTP POST
   - URL: https://omg-psu-openai-funcapp.azurewebsites.net/api/ProxyOpenAI

---

### STEP 2: Get Function Authentication Key

**Goal**: Retrieve the secret key needed to call your function

#### 2.1 Navigate to Function Keys
1. **Still in ProxyOpenAI function page**
2. **In left sidebar**, click: **"Function Keys"**
3. You'll see a table with keys:
   - Name: `default`
   - Value: (hidden by default)
   - Created: (timestamp)

#### 2.2 Copy the Key
1. Click the **"eye" icon** or **"Show value"** next to `default` key
2. The key will be revealed (looks like: `xYzAbC123...` - ~60 characters)
3. Click the **"Copy" icon** to copy to clipboard
4. **SAVE THIS KEY** - Paste it somewhere safe:
   - Notepad
   - Or create a file: `C:\temp\function-key.txt`

#### 2.3 Construct Full Function URL
Your complete function URL with key is:
```
https://omg-psu-openai-funcapp.azurewebsites.net/api/ProxyOpenAI?code=<YOUR_KEY_HERE>
```

**Example** (replace with your actual key):
```
https://omg-psu-openai-funcapp.azurewebsites.net/api/ProxyOpenAI?code=xYzAbC123def456ghi789...
```

---

### STEP 3: Test the Function with PowerShell

**Goal**: Verify the function works and can call OpenAI

#### 3.1 Test Using Test Script (Automated)

Open PowerShell and run:

```powershell
# Navigate to test scripts folder
cd "C:\repos\OMG.PSUtilities\Module Developer Tools\Azure-Deployment-Scripts"

# Run test script (replace <YOUR_KEY> with the key you copied)
.\Test-DeployedProxy.ps1 -FunctionUrl "https://omg-psu-openai-funcapp.azurewebsites.net/api/ProxyOpenAI" -FunctionKey "<YOUR_KEY>"
```

**Expected Output:**
```
========================================
Test 1: Basic Proxy Functionality
========================================
[SUCCESS] Function returned valid response
Completion: [AI-generated text explaining what a PowerShell function is]
Total Tokens: 150
Execution Time: 2.5 seconds
```

#### 3.2 Test Manually with Invoke-RestMethod

```powershell
# Set your function URL with key
$functionUrl = "https://omg-psu-openai-funcapp.azurewebsites.net/api/ProxyOpenAI?code=<YOUR_KEY>"

# Create test request body
$body = @{
    messages = @(
        @{
            role = "system"
            content = "You are a helpful assistant."
        },
        @{
            role = "user"
            content = "Explain Azure Functions in one sentence."
        }
    )
    max_tokens = 100
} | ConvertTo-Json -Depth 5

# Call the function
$response = Invoke-RestMethod -Uri $functionUrl -Method Post -Body $body -ContentType "application/json"

# Display result
Write-Host "Response: $($response.choices[0].message.content)"
Write-Host "Tokens Used: $($response.usage.total_tokens)"
```

**Expected Output:**
```
Response: Azure Functions is a serverless compute service that lets you run event-triggered code without managing infrastructure.
Tokens Used: 45
```

#### 3.3 Understanding What's Happening

When you call the function:

1. **Your PowerShell script** sends JSON request to Azure Function
2. **Azure Function** (your `run.ps1` code):
   - Validates authentication key
   - Loads OpenAI credentials from environment variables
   - Modifies the request (adds system prompt if needed)
   - Forwards request to Azure OpenAI endpoint
   - Receives OpenAI response
   - Cleans up response (removes unnecessary fields)
   - Returns response to your script
3. **Your script** receives the AI response

---

### STEP 4: Verify Environment Variables (Optional Check)

**Goal**: Confirm OpenAI credentials are correctly configured

#### 4.1 View Configuration in Portal
1. **In Function App page**, left sidebar
2. Click: **"Configuration"** (under "Settings" section)
3. Click: **"Application settings"** tab
4. You should see these 4 settings:

| Name | Value (partially shown) |
|------|-------------------------|
| AZURE_OPENAI_KEY | 3bLIU...*** (click eye to reveal) |
| AZURE_OPENAI_ENDPOINT | https://omg-openai-2511210412.openai.azure.com |
| AZURE_OPENAI_DEPLOYMENT | model-router |
| AZURE_OPENAI_API_VERSION | 2024-12-01-preview |

5. Click **eye icon** to verify values match your OpenAI account

#### 4.2 Test via PowerShell (Already Done Earlier)
These were configured via PowerShell command:
```powershell
Update-AzFunctionAppSetting -ResourceGroupName "omg-psu-openai-rg" -Name "omg-psu-openai-funcapp" -AppSetting @{
    "AZURE_OPENAI_KEY" = $env:API_KEY_AZURE_OPENAI
    "AZURE_OPENAI_ENDPOINT" = $env:AZURE_OPENAI_ENDPOINT
    "AZURE_OPENAI_DEPLOYMENT" = $env:AZURE_OPENAI_DEPLOYMENT
    "AZURE_OPENAI_API_VERSION" = $env:AZURE_OPENAI_API_VERSION
}
```

---

### STEP 5: Monitor Function Execution (Learn Azure Insights)

**Goal**: See real-time function invocations, errors, and performance

#### 5.1 View Live Logs
1. **In Function App page**, go to **ProxyOpenAI** function
2. **In left sidebar**, click: **"Monitor"**
3. You'll see:
   - **Invocations** tab: List of all function calls
   - **Logs** tab: Real-time log stream
   - **Metrics** tab: Performance graphs

#### 5.2 Analyze Invocations
1. Click on any invocation row
2. You'll see details:
   - **Timestamp**: When function was called
   - **Status**: Success (200) or Error (400/500)
   - **Duration**: Execution time in milliseconds
   - **Request Body**: Input you sent
   - **Logs**: Console output from `Write-Host` commands

#### 5.3 Use Application Insights (Advanced)
1. **In Function App page**, left sidebar
2. Click: **"Application Insights"**
3. Click: **"View Application Insights data"**
4. You'll see detailed analytics:
   - **Live Metrics**: Real-time requests, failures, performance
   - **Failures**: Error details with stack traces
   - **Performance**: Response time distribution
   - **Dependencies**: Calls to OpenAI API
   - **Logs**: Search through all logs with KQL queries

**Example Query** (in Logs section):
```kql
traces
| where timestamp > ago(1h)
| where message contains "ProxyOpenAI"
| order by timestamp desc
| take 20
```

---

### STEP 6: Understand Function Code (Learn PowerShell Functions)

**Goal**: Understand what your function code does

#### 6.1 View Code in Portal
1. **In ProxyOpenAI function page**
2. **Left sidebar**, click: **"Code + Test"**
3. You'll see your `run.ps1` file
4. **Read through the code** - it has 10 numbered steps with comments

#### 6.2 Code Flow Explanation

**File**: `C:\repos\OMG.PSUtilities\AzureFunction-OpenAI-Proxy\ProxyOpenAI\run.ps1`

```powershell
# STEP 1: Load Environment Variables
$openaiKey = $env:AZURE_OPENAI_KEY
$openaiEndpoint = $env:AZURE_OPENAI_ENDPOINT
# ... etc
```
- Retrieves OpenAI credentials from Function App settings
- These are secure and never exposed to users

```powershell
# STEP 2-3: Validate Credentials
if ([string]::IsNullOrWhiteSpace($openaiKey)) {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = 500
        Body = "OpenAI credentials not configured"
    })
    return
}
```
- Ensures all required settings exist
- Returns error if missing

```powershell
# STEP 4-5: Parse Request Body
$requestBody = $Request.Body
if ($Request.Body -is [string]) {
    $requestBody = $Request.Body | ConvertFrom-Json -Depth 10
}
```
- Handles JSON parsing from HTTP POST
- Supports both string and object inputs

```powershell
# STEP 6-7: Modify Request
if (-not $requestBody.messages) {
    $requestBody | Add-Member -MemberType NoteProperty -Name "messages" -Value @(
        @{ role = "user"; content = $requestBody.prompt }
    )
}
```
- Converts old-style prompts to chat format
- Adds system messages if needed

```powershell
# STEP 8: Call OpenAI API
$uri = "$openaiEndpoint/openai/deployments/$openaiDeployment/chat/completions?api-version=$openaiApiVersion"
$headers = @{
    "api-key" = $openaiKey
    "Content-Type" = "application/json"
}
$openaiResponse = Invoke-RestMethod -Uri $uri -Method Post -Body $bodyJson -Headers $headers
```
- Constructs OpenAI API URL
- Adds authentication header
- Forwards request to OpenAI

```powershell
# STEP 9-10: Return Response
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = 200
    Body = $cleanedResponse
    ContentType = "application/json"
})
```
- Cleans up OpenAI response
- Returns to caller with proper HTTP status

---

### STEP 7: (OPTIONAL) Deploy API Management for Rate Limiting

**Goal**: Add rate limiting (100 calls/hour, 50K calls/month) and subscription key management

#### 7.1 Why Add APIM?
- **Rate Limiting**: Prevent abuse (100 calls/hour per user)
- **Quota Management**: Monthly limits (50K calls/month)
- **Subscription Keys**: Manage multiple API consumers
- **Analytics**: Better usage tracking
- **Caching**: Reduce OpenAI costs (optional)

#### 7.2 Cost
- **Consumption Tier**: $0 for first 1 million calls, then $3.50 per million
- **Your usage**: 5 million calls/month = ~$14/month
- **Total cost** (Function + APIM + Storage): ~$16/month

#### 7.3 Deploy APIM (PowerShell Method)

```powershell
cd "C:\repos\OMG.PSUtilities\Module Developer Tools\Azure-Deployment-Scripts"

.\Deploy-APIM.ps1 `
    -SubscriptionId "88355f02-7508-401e-a6c0-24993fad9e77" `
    -ResourceGroupName "omg-psu-openai-rg" `
    -ApimName "omg-psu-openai-apim" `
    -Location "centralindia" `
    -PublisherEmail "lakshmanachari@hotmail.com" `
    -PublisherName "Lakshmanachari Panuganti" `
    -FunctionAppName "omg-psu-openai-funcapp"
```

**Deployment time**: 15-20 minutes (APIM provisioning is slow)

#### 7.4 Deploy APIM (Manual Portal Method)

1. **Azure Portal** → Search "API Management"
2. Click **"+ Create"**
3. Fill in:
   - Resource Group: omg-psu-openai-rg
   - Region: Central India
   - Resource name: omg-psu-openai-apim
   - Organization name: Your Name
   - Admin email: your-email@example.com
   - Pricing tier: **Consumption**
4. Click **"Review + create"** → **"Create"**
5. **Wait 15-20 minutes** for provisioning

6. After creation:
   - Go to APIM resource
   - Click **"APIs"** → **"+ Add API"**
   - Select **"Function App"**
   - Click **"Browse"** → Select **omg-psu-openai-funcapp**
   - Select **ProxyOpenAI** function
   - Click **"Create"**

7. Add Rate Limiting Policy:
   - Click on **ProxyOpenAI** API
   - Click **"All operations"**
   - Click **"</> Code view"** in Inbound processing
   - Add this policy:

```xml
<policies>
    <inbound>
        <rate-limit calls="100" renewal-period="3600" />
        <quota calls="50000" renewal-period="2592000" />
        <base />
    </inbound>
</policies>
```

8. Save and test with APIM URL instead of Function URL

---

### STEP 8: Update PowerShell Module with New Proxy URL

**Goal**: Update your PowerShell module to use the new Azure Function proxy

#### 8.1 Locate Module File
**File**: `C:\repos\OMG.PSUtilities\OMG.PSUtilities.AI\OMG.PSUtilities.AI.psm1`

#### 8.2 Find Current Proxy Configuration
Look for this section (around line 20-30):

```powershell
# Proxy configuration
$script:var_c = "aHR0cHM6Ly9vbWctb3BlbmFpLXByb3h5LmF6dXJld2Vic2l0ZXMubmV0L2FwaS9Qcm94eU9wZW5BST9jb2RlPXh5ekFiQzEyMy4uLg=="
```

#### 8.3 Encode New Function URL with Key

```powershell
# Your new function URL with key
$functionUrl = "https://omg-psu-openai-funcapp.azurewebsites.net/api/ProxyOpenAI?code=<YOUR_KEY_HERE>"

# Encode to Base64
$bytes = [System.Text.Encoding]::UTF8.GetBytes($functionUrl)
$encodedUrl = [Convert]::ToBase64String($bytes)

# Display encoded URL
Write-Host "Encoded URL (copy this):"
Write-Host $encodedUrl
```

#### 8.4 Update Module File

Replace the old `$script:var_c` value with your new encoded URL:

```powershell
# Old (example):
$script:var_c = "aHR0cHM6Ly9vbGQtdXJs..."

# New (your encoded URL):
$script:var_c = "aHR0cHM6Ly9vbWctcHN1LW9wZW5haS1mdW5jYXBwLmF6dXJld2Vic2l0ZXMubmV0L2FwaS9Qcm94eU9wZW5BST9jb2RlPXhZekFiQzEyMy4uLg=="
```

#### 8.5 Test Updated Module

```powershell
# Import updated module
Import-Module "C:\repos\OMG.PSUtilities\OMG.PSUtilities.AI\OMG.PSUtilities.AI.psd1" -Force

# Test AI function (example - use your actual function name)
Get-AICompletion -Prompt "Test the new Azure Function proxy"
```

#### 8.6 Commit Changes to Git

```powershell
cd "C:\repos\OMG.PSUtilities"

git add OMG.PSUtilities.AI/OMG.PSUtilities.AI.psm1
git commit -m "Updated AI module to use new Azure Function proxy in Central India"
git push origin feature/dev
```

---

## 🎓 LEARNING OUTCOMES

After completing this guide, you now understand:

### Azure Functions Concepts
- ✅ **Serverless computing**: No server management, pay per execution
- ✅ **Consumption Plan**: Auto-scaling, only charged when running
- ✅ **HTTP Triggers**: How functions respond to web requests
- ✅ **Environment Variables**: Secure credential storage
- ✅ **Application Insights**: Monitoring and diagnostics

### Deployment Methods
- ✅ **ZIP Deploy**: Package and upload code
- ✅ **Kudu Console**: Advanced deployment tools
- ✅ **ARM Templates**: Infrastructure as Code (used by scripts)
- ✅ **PowerShell Az Module**: Automate Azure operations

### Security Best Practices
- ✅ **Function Keys**: Authentication for HTTP triggers
- ✅ **Managed Identities**: Passwordless authentication (App Insights)
- ✅ **Environment Variables**: Never hardcode credentials
- ✅ **Base64 Encoding**: Obfuscate URLs in public code

### Integration Patterns
- ✅ **Proxy Pattern**: Hide backend APIs behind serverless layer
- ✅ **Cross-Account Access**: Use resources from different Azure subscriptions
- ✅ **REST API Forwarding**: Modify and forward requests
- ✅ **Error Handling**: Graceful failures with proper HTTP status codes

---

## 📊 COST BREAKDOWN (Monthly Estimate)

Based on 5 million OpenAI API calls/month:

| Resource | Tier/SKU | Estimated Cost (INR) |
|----------|----------|---------------------|
| **Function App** | Consumption | ₹0 (within free tier) |
| **Storage Account** | Standard LRS | ₹144 (~$1.72) |
| **Application Insights** | Pay-as-you-go | ₹0 (within 5 GB free tier) |
| **APIM** (optional) | Consumption | ₹1,180 (~$14) |
| **Azure OpenAI** | gpt-4 | ₹1,56,563 (~$1,870) |
| **Total without APIM** | | **₹1,56,707** |
| **Total with APIM** | | **₹1,57,887** |

**Free tier limits:**
- Function App: First 1 million executions/month free
- Storage: First 5 GB free
- App Insights: First 5 GB logs/month free

---

## 🔧 TROUBLESHOOTING GUIDE

### Issue 1: Function Returns 500 Error

**Symptoms**: HTTP 500 Internal Server Error when calling function

**Causes & Solutions:**

1. **Environment variables not set**
   - Portal → Function App → Configuration
   - Verify all 4 AZURE_OPENAI_* settings exist
   - Click "Save" after any changes

2. **OpenAI key expired or invalid**
   - Test key directly with OpenAI API:
   ```powershell
   $headers = @{ "api-key" = $env:API_KEY_AZURE_OPENAI }
   Invoke-RestMethod -Uri "$env:AZURE_OPENAI_ENDPOINT/openai/deployments/model-router/chat/completions?api-version=2024-12-01-preview" -Headers $headers -Method Post -Body '{"messages":[{"role":"user","content":"test"}]}' -ContentType "application/json"
   ```

3. **Function code not deployed**
   - Portal → Functions → Check if ProxyOpenAI exists
   - Redeploy ZIP file

### Issue 2: Function Returns 401 Unauthorized

**Symptoms**: HTTP 401 when calling function URL

**Cause**: Missing or incorrect function key

**Solution:**
- Portal → Function App → ProxyOpenAI → Function Keys
- Copy the `default` key
- Append to URL: `?code=<key>`

### Issue 3: Deployment Fails with "NotFound" Error

**Symptoms**: `func azure functionapp publish` fails

**Cause**: Function App not fully provisioned

**Solution:**
- Wait 5 minutes after Function App creation
- Use manual ZIP deploy via Portal instead
- Check Function App status is "Running"

### Issue 4: OpenAI Returns 404 Error

**Symptoms**: Function works but OpenAI returns 404

**Cause**: Incorrect deployment name or endpoint

**Solution:**
- Verify deployment name: `model-router`
- Verify endpoint: `https://omg-openai-2511210412.openai.azure.com`
- Check in original OpenAI account (not Function App account)

### Issue 5: High Latency (Slow Responses)

**Symptoms**: Function takes > 10 seconds to respond

**Causes & Solutions:**

1. **Cold Start** (first request after idle period)
   - Normal behavior for Consumption Plan
   - First request ~5-10 seconds, subsequent ~1-2 seconds
   - Upgrade to Premium Plan for always-on ($140/month)

2. **Region Mismatch**
   - Function in Central India, OpenAI in US → High latency
   - Solution: Move OpenAI to Central India (if possible)
   - Or keep as-is (200-300ms extra latency acceptable)

3. **Large Prompts**
   - Reduce token count in requests
   - Use streaming responses (advanced)

---

## 📚 ADDITIONAL RESOURCES

### Official Microsoft Documentation
- **Azure Functions Overview**: https://learn.microsoft.com/azure/azure-functions/
- **PowerShell Developer Guide**: https://learn.microsoft.com/azure/azure-functions/functions-reference-powershell
- **Application Insights**: https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview
- **API Management**: https://learn.microsoft.com/azure/api-management/

### Your Project Files
- **Function Code**: `C:\repos\OMG.PSUtilities\AzureFunction-OpenAI-Proxy\`
- **Deployment Scripts**: `C:\repos\OMG.PSUtilities\Module Developer Tools\Azure-Deployment-Scripts\`
- **Test Scripts**: `Test-DeployedProxy.ps1`, `Get-DeploymentInfo.ps1`
- **Documentation**: `README.md`, `MANUAL-DEPLOYMENT-GUIDE.md`

### PowerShell Commands Reference

```powershell
# Connect to Azure
Connect-AzAccount
Set-AzContext -SubscriptionId "88355f02-7508-401e-a6c0-24993fad9e77"

# List all resources
Get-AzResource -ResourceGroupName "omg-psu-openai-rg"

# View Function App settings
Get-AzWebApp -ResourceGroupName "omg-psu-openai-rg" -Name "omg-psu-openai-funcapp"

# Update environment variables
Update-AzFunctionAppSetting -ResourceGroupName "omg-psu-openai-rg" -Name "omg-psu-openai-funcapp" -AppSetting @{ "KEY" = "value" }

# View logs
Get-AzLog -ResourceGroupName "omg-psu-openai-rg" -StartTime (Get-Date).AddHours(-1)

# Delete everything (cleanup)
Remove-AzResourceGroup -Name "omg-psu-openai-rg" -Force
```

---

## ✅ FINAL CHECKLIST

Before considering deployment complete:

- [ ] Function App created and running
- [ ] Storage account connected
- [ ] Application Insights enabled
- [ ] Environment variables configured (4 settings)
- [ ] Function code deployed (ZIP upload successful)
- [ ] ProxyOpenAI function visible in portal
- [ ] Function key retrieved and saved
- [ ] Test request returns 200 OK with AI response
- [ ] Application Insights showing invocations
- [ ] PowerShell module updated with new URL
- [ ] Module tested end-to-end
- [ ] Documentation reviewed and understood
- [ ] (Optional) APIM deployed with rate limiting

---

## 🎯 NEXT STEPS & ADVANCED TOPICS

### Immediate Next Steps
1. **Test in Production**: Update your PowerShell module and publish
2. **Monitor Usage**: Set up Application Insights alerts
3. **Document for Team**: Share this guide with team members

### Advanced Enhancements
1. **Custom Domain**: Add custom domain like `api.omg-psu.com`
2. **CORS Configuration**: Allow browser-based calls
3. **Response Caching**: Cache frequent requests to reduce costs
4. **Throttling by User**: Per-user rate limits with APIM
5. **Streaming Responses**: Real-time token streaming
6. **Multi-Region Deployment**: Traffic Manager for global access
7. **CI/CD Pipeline**: GitHub Actions automated deployment

### Learning Path
1. **Azure Functions Deep Dive**: Durable Functions, Event Grid triggers
2. **Application Insights**: Custom metrics, KQL queries
3. **API Management**: Policies, transformations, developer portal
4. **Azure DevOps**: Build pipelines, release management
5. **Infrastructure as Code**: Bicep, Terraform

---

## 📞 SUPPORT & HELP

### If You Get Stuck

1. **Check Application Insights Logs**
   - Portal → Function App → Application Insights → Logs
   - Search for error messages

2. **Review Function Logs**
   - Portal → ProxyOpenAI → Monitor → Invocations
   - Click on failed invocation for details

3. **Test Components Individually**
   - Test OpenAI directly (bypass function)
   - Test function with simple request
   - Verify environment variables

4. **Use Test Scripts**
   ```powershell
   .\Test-DeployedProxy.ps1 -FunctionUrl "<url>" -FunctionKey "<key>" -Verbose
   ```

### Common Error Messages & Solutions

| Error | Meaning | Solution |
|-------|---------|----------|
| `500 Internal Server Error` | Function code error | Check logs, verify env vars |
| `401 Unauthorized` | Missing/wrong function key | Copy key from Portal |
| `404 Not Found` | Wrong URL or function not deployed | Verify URL, redeploy code |
| `429 Too Many Requests` | Rate limit hit | Wait or increase APIM limits |
| `503 Service Unavailable` | Function App not ready | Wait 5 minutes, retry |

---

## 🎉 CONGRATULATIONS!

You've successfully learned:
- ✅ Azure Function App architecture and deployment
- ✅ Serverless computing concepts
- ✅ Secure credential management
- ✅ API integration patterns
- ✅ Monitoring and diagnostics
- ✅ Cost optimization strategies

**Your OpenAI proxy is now live in Azure Central India!**

**Next**: Share this with your PowerShell module users and monitor usage in Application Insights.

---

**Document Version**: 1.0  
**Last Updated**: December 5, 2025  
**Author**: Lakshmanachari Panuganti  
**Repository**: https://github.com/lakshmanachari-panuganti/OMG.PSUtilities
