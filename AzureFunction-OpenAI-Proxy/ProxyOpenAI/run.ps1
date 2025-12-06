<#
══════════════════════════════════════════════════════════════════════════════
  AZURE FUNCTION: OpenAI Proxy
══════════════════════════════════════════════════════════════════════════════

PURPOSE:
  This function acts as a secure proxy between your PowerShell module and Azure OpenAI.
  It hides YOUR Azure OpenAI credentials from end users while still allowing them to use AI features.

HOW IT WORKS:
  1. User calls PowerShell function → Sends request to THIS Azure Function
  2. This function receives: Prompt, MaxTokens, Temperature
  3. This function adds: YOUR ApiKey, Endpoint, Deployment (from environment variables)
  4. Forwards request to Azure OpenAI
  5. Returns response to user

SECURITY:
  - Your Azure OpenAI credentials are stored in Azure Function App Settings (encrypted)
  - Users never see or need your credentials
  - Optional: Add rate limiting to prevent abuse

COST:
  - Azure Functions Consumption Plan: Free for first 1 million requests/month
  - You pay for Azure OpenAI usage (per token)

══════════════════════════════════════════════════════════════════════════════
#>

using namespace System.Net

param($Request, $TriggerMetadata)

# ══════════════════════════════════════════════════════════════════════════
# STEP 1: Read environment variables (YOUR credentials - set in Azure Portal)
# ══════════════════════════════════════════════════════════════════════════
$ApiKey = $env:AZURE_OPENAI_KEY
$Endpoint = $env:AZURE_OPENAI_ENDPOINT
$Deployment = $env:AZURE_OPENAI_DEPLOYMENT
$ApiVersion = $env:AZURE_OPENAI_API_VERSION ?? '2024-12-01-preview'

Write-Host "Environment Variables Loaded:"
Write-Host "  ApiKey: $(if($ApiKey){'SET'}else{'MISSING'})"
Write-Host "  Endpoint: $Endpoint"
Write-Host "  Deployment: $Deployment"
Write-Host "  ApiVersion: $ApiVersion"

# ══════════════════════════════════════════════════════════════════════════
# STEP 2: Validate that credentials are configured
# ══════════════════════════════════════════════════════════════════════════
if (-not $ApiKey -or -not $Endpoint -or -not $Deployment) {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::InternalServerError
        Body = @{
            error = "Proxy not configured. Contact administrator to set AZURE_OPENAI_KEY, AZURE_OPENAI_ENDPOINT, and AZURE_OPENAI_DEPLOYMENT in Function App Settings."
        } | ConvertTo-Json
    })
    return
}

# ══════════════════════════════════════════════════════════════════════════
# STEP 3: Parse incoming request from user
# ══════════════════════════════════════════════════════════════════════════
try {
    Write-Host "Request.Body type: $($Request.Body.GetType().FullName)"
    Write-Host "Request.Body content: $($Request.Body)"

    # Parse JSON body to PowerShell object
    $RequestBody = if ($Request.Body -is [string]) {
        Write-Host "Parsing as string..."
        $Request.Body | ConvertFrom-Json
    } else {
        Write-Host "Using as-is..."
        $Request.Body
    }

    Write-Host "Parsed RequestBody: $($RequestBody | ConvertTo-Json -Compress)"

    $Prompt = $RequestBody.Prompt
    $MaxTokens = $RequestBody.MaxTokens ?? 4096
    $Temperature = $RequestBody.Temperature ?? 0.7
    $ReturnJsonResponse = $RequestBody.ReturnJsonResponse ?? $false

    Write-Host "Extracted values - Prompt: $Prompt, MaxTokens: $MaxTokens, Temp: $Temperature"

    if (-not $Prompt) {
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body = @{
                error = "Missing 'Prompt' in request body"
                example = @{
                    Prompt = "Explain Azure in one sentence"
                    MaxTokens = 4096
                    Temperature = 0.7
                }
            } | ConvertTo-Json
        })
        return
    }
} catch {
    Write-Host "ERROR in request parsing: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.ScriptStackTrace)"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = @{
            error = "Invalid request format. Expected JSON body with 'Prompt' field."
            details = $_.Exception.Message
        } | ConvertTo-Json
    })
    return
}

# ══════════════════════════════════════════════════════════════════════════
# STEP 4: Modify prompt if JSON response is requested
# ══════════════════════════════════════════════════════════════════════════
$ModifiedPrompt = if ($ReturnJsonResponse) {
    @"
$Prompt

CRITICAL: Respond with ONLY valid JSON. No markdown, no code blocks, no explanations.
Just pure JSON that starts with { or [
"@
} else {
    $Prompt
}

# ══════════════════════════════════════════════════════════════════════════
# STEP 5: Build request to Azure OpenAI
# ══════════════════════════════════════════════════════════════════════════
$Endpoint = $Endpoint.TrimEnd('/')
$Endpoint = $Endpoint -replace '/openai.*$', ''
$OpenAIUrl = "$Endpoint/openai/deployments/$Deployment/chat/completions?api-version=$ApiVersion"

$OpenAIRequestBody = @{
    messages = @(
        @{
            role = "user"
            content = $ModifiedPrompt
        }
    )
    max_tokens = $MaxTokens
    temperature = $Temperature
} | ConvertTo-Json -Depth 10 -Compress

$Headers = @{
    "api-key" = $ApiKey
    "Content-Type" = "application/json"
}

# ══════════════════════════════════════════════════════════════════════════
# STEP 6: Forward request to Azure OpenAI
# ══════════════════════════════════════════════════════════════════════════
try {
    Write-Host "Forwarding request to Azure OpenAI: $Deployment"

    $OpenAIResponse = Invoke-RestMethod `
        -Method Post `
        -Uri $OpenAIUrl `
        -Headers $Headers `
        -Body $OpenAIRequestBody `
        -ContentType 'application/json' `
        -TimeoutSec 300 `
        -ErrorAction Stop

    # ══════════════════════════════════════════════════════════════════════
    # STEP 7: Extract response text
    # ══════════════════════════════════════════════════════════════════════
    $ResponseText = $OpenAIResponse.choices[0].message.content

    # ══════════════════════════════════════════════════════════════════════
    # STEP 8: Clean JSON response if requested
    # ══════════════════════════════════════════════════════════════════════
    if ($ReturnJsonResponse) {
        $CleanedText = $ResponseText -replace '```json\s*', '' -replace '```\s*', ''
        $CleanedText = $CleanedText.Trim()

        if ($CleanedText -match '^\s*[\{\[]') {
            $ResponseText = $CleanedText
        }
    }

    # ══════════════════════════════════════════════════════════════════════
    # STEP 9: Return success response to user
    # ══════════════════════════════════════════════════════════════════════
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = @{
            response = $ResponseText
            usage = $OpenAIResponse.usage
            model = $Deployment
        } | ConvertTo-Json -Depth 10
    })

} catch {
    # ══════════════════════════════════════════════════════════════════════
    # STEP 10: Handle errors from Azure OpenAI
    # ══════════════════════════════════════════════════════════════════════
    Write-Host "Error calling Azure OpenAI: $($_.Exception.Message)"

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::InternalServerError
        Body = @{
            error = "Failed to get response from Azure OpenAI"
            details = $_.Exception.Message
        } | ConvertTo-Json
    })
}
