# 🎯 QUICK REFERENCE CARD
## Azure OpenAI Proxy - Deployment Cheat Sheet

---

## ⚡ 5-Minute Deployment

```powershell
# 1. Navigate to project
cd c:\repos\OMG.PSUtilities\AzureFunction-OpenAI-Proxy

# 2. Deploy to Azure (one command!)
.\Deploy-ToAzure.ps1 `
    -ResourceGroupName "rg-psu-openai" `
    -FunctionAppName "psu-proxy-$(Get-Random -Max 9999)" `
    -Location "eastus" `
    -AzureOpenAIKey "YOUR_KEY" `
    -AzureOpenAIEndpoint "https://your-resource.openai.azure.com" `
    -AzureOpenAIDeployment "gpt-4o"

# 3. Test it
.\Test-ProxyFunction.ps1 -ProxyUrl "<URL from step 2>"

# 4. Update PowerShell module
# Copy the proxy URL and update line 87 in:
# Invoke-PSUPromptOnAzureOpenAi-Proxy-Version.ps1

# 5. Done! 🎉
```

---

## 📁 Project Structure

```
AzureFunction-OpenAI-Proxy/
├── ProxyOpenAI/
│   ├── run.ps1              ← Main proxy logic
│   └── function.json         ← HTTP trigger config
├── host.json                 ← Azure Functions runtime config
├── local.settings.json       ← Local development credentials
├── profile.ps1               ← PowerShell version config
├── Deploy-ToAzure.ps1        ← Deployment automation
├── Test-ProxyFunction.ps1    ← Testing script
├── README.md                 ← Full documentation
└── QUICK-START.md            ← This file!
```

---

## 🔑 Important URLs/Commands

### Get Function URL
```powershell
az functionapp function show `
    --name <function-app-name> `
    --resource-group <rg-name> `
    --function-name ProxyOpenAI `
    --query invokeUrlTemplate -o tsv
```

### Get Function Key
```powershell
az functionapp keys list `
    --name <function-app-name> `
    --resource-group <rg-name> `
    --query functionKeys.default -o tsv
```

### Stream Logs
```powershell
func azure functionapp logstream <function-app-name>
```

### Update Environment Variables
```powershell
az functionapp config appsettings set `
    --name <function-app-name> `
    --resource-group <rg-name> `
    --settings `
        "AZURE_OPENAI_KEY=<new-key>" `
        "AZURE_OPENAI_ENDPOINT=<new-endpoint>"
```

---

## 🧪 Testing

### Local Test
```powershell
# Terminal 1: Start function
func start

# Terminal 2: Test
.\Test-ProxyFunction.ps1 -ProxyUrl "http://localhost:7071/api/ProxyOpenAI"
```

### Azure Test
```powershell
.\Test-ProxyFunction.ps1 -ProxyUrl "https://<app-name>.azurewebsites.net/api/ProxyOpenAI?code=<key>"
```

### Quick Manual Test
```powershell
$body = @{ Prompt = "Say hello"; MaxTokens = 50 } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "<proxy-url>" -Body $body -ContentType "application/json"
```

---

## 🔒 Security Checklist

- [ ] Function Key is private (never commit to Git)
- [ ] `local.settings.json` is in `.gitignore`
- [ ] Environment variables are set in Azure Portal (encrypted)
- [ ] Budget alert configured (Cost Management)
- [ ] Usage monitoring enabled (Application Insights)

---

## 💰 Cost Estimate

| Component | Free Tier | After Free Tier |
|-----------|-----------|-----------------|
| Azure Functions | 1M requests/month | $0.20/M requests |
| Azure OpenAI (GPT-4o) | N/A | ~$5-15/M tokens |
| **Typical Monthly Cost** | **$0** (under 1M req) | **$1-10** (moderate use) |

---

## 🐛 Common Issues

| Error | Fix |
|-------|-----|
| "Proxy not configured" | Set environment variables in Azure Portal |
| "401 Unauthorized" | Check Function Key in URL |
| "Timeout" | Increase `-TimeoutSeconds` parameter |
| "Function not found" | Ensure deployment succeeded: `func azure functionapp publish <app-name>` |

---

## 📝 Notes

**Function App Naming Rules:**
- Must be globally unique
- Only lowercase letters, numbers, and hyphens
- 2-60 characters
- Can't start/end with hyphen

**Recommended Naming:**
- `psu-openai-proxy-<random-number>`
- Example: `psu-openai-proxy-1234`

**Azure Regions:**
- `eastus` - East US (cheapest, most reliable)
- `westus2` - West US 2
- `westeurope` - West Europe
- Full list: `az account list-locations -o table`

---

## 🚀 Next Steps After Deployment

1. **Save Function URL** securely (password manager)
2. **Test thoroughly** before publishing module
3. **Monitor costs** for first week
4. **Update module** with proxy URL
5. **Publish to PowerShell Gallery**
6. **Celebrate!** 🎉

---

## 📞 Quick Help

**Check if function is running:**
```powershell
Invoke-WebRequest -Uri "https://<app-name>.azurewebsites.net" -UseBasicParsing
# Should return HTTP 200
```

**View recent executions:**
- Azure Portal → Function App → Functions → ProxyOpenAI → Monitor

**Delete everything (cleanup):**
```powershell
az group delete --name <resource-group-name> --yes --no-wait
```

---

**💡 Pro Tip:** Bookmark this file for quick reference during deployment!
