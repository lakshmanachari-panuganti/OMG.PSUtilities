function Invoke-PSUPromptOnAzureOpenAi {
    <#
.SYNOPSIS
    Sends a prompt to Azure OpenAI (Chat Completions API) and returns the generated response.

.DESCRIPTION
    This function interacts with Azure-hosted OpenAI (e.g., GPT-4.1) using the Chat Completions endpoint.
    It supports structured JSON response parsing and optional override of environment credentials.

    How to configure:
    -----------------
    1. Go to Azure Portal → OpenAI Resource
    2. Deploy a model (e.g., GPT-4.1)
    3. Copy your API Key and Endpoint
    4. Set credentials using:

        Set-PSUUserEnvironmentVariable -Name "API_KEY_AZURE_OPENAI" -Value "<your-api-key>"
        Set-PSUUserEnvironmentVariable -Name "AZURE_OPENAI_ENDPOINT" -Value "<your-endpoint>"
        Set-PSUUserEnvironmentVariable -Name "AZURE_OPENAI_DEPLOYMENT" -Value "<your-deployment-name>"

.PARAMETER Prompt
    (Mandatory) The message to send to Azure OpenAI for generating a response.

.PARAMETER ApiKey
    (Optional) The API key for Azure OpenAI authentication.
    Default value is $env:API_KEY_AZURE_OPENAI. Set using: Set-PSUUserEnvironmentVariable -Name "API_KEY_AZURE_OPENAI" -Value "your-api-key"

.PARAMETER Endpoint
    (Optional) The Azure OpenAI endpoint URL.
    Default value is $env:AZURE_OPENAI_ENDPOINT. Set using: Set-PSUUserEnvironmentVariable -Name "AZURE_OPENAI_ENDPOINT" -Value "your-endpoint"

.PARAMETER Deployment
    (Optional) The Azure OpenAI deployment name.
    Default value is $env:AZURE_OPENAI_DEPLOYMENT. Set using: Set-PSUUserEnvironmentVariable -Name "AZURE_OPENAI_DEPLOYMENT" -Value "your-deployment-name"

.PARAMETER ReturnJsonResponse
    (Optional) Switch parameter to extract and return raw JSON from the response.

.EXAMPLE
    API_KEY_AZURE_OPENAI -Prompt "Summarize Kubernetes in one line"

.EXAMPLE
    API_KEY_AZURE_OPENAI -Prompt "Return a JSON with name and city" -ReturnJsonResponse

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 2025-08-01
    API Version: 2025-01-01-preview

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AI
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AI
    https://learn.microsoft.com/en-us/azure/ai-services/openai/reference

#>

    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter()]
        [string]$ApiKey = $env:API_KEY_AZURE_OPENAI,

        [Parameter()]
        [string]$Endpoint = $env:AZURE_OPENAI_ENDPOINT,

        [Parameter()]
        [string]$Deployment = $env:AZURE_OPENAI_DEPLOYMENT,

        [Parameter()]
        [switch]$ReturnJsonResponse
    )

    if (-not $ApiKey -or -not $Endpoint -or -not $Deployment) {
        Write-Error "Azure OpenAI credentials are missing. Please check environment variables or pass parameters directly."
        return
    }

    $ModifiedPrompt = if ($ReturnJsonResponse.IsPresent) {
        $Prompt + "`nRespond ONLY with valid JSON. No explanations. No markdown. Just raw JSON."
    }
    else {
        $Prompt
    }

    $Endpoint = $Endpoint.TrimEnd('/')
    $Uri = "$Endpoint/openai/deployments/$Deployment/chat/completions?api-version=2025-01-01-preview"
    $Headers = @{ "api-key" = $ApiKey }

    $Body = @{
        messages    = @(
            @{ role = "system"; content = "You are a helpful assistant." },
            @{ role = "user"; content = $ModifiedPrompt }
        )
        max_tokens  = 1000
        temperature = 0.7
    } | ConvertTo-Json -Depth 10

    try {
        Write-Host "🧠 Thinking..." -ForegroundColor Cyan
        $Response = Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -Body $Body -ContentType 'application/json'
        $Text = $Response.choices[0].message.content

        if ($ReturnJsonResponse.IsPresent) {
            if ($Text -match '(?s)```json\s*(\{.*?\}|\[.*?\])\s*```') {
                return $matches[1]
            }
            elseif ($Text -match '(\{.*?\}|\[.*?\])') {
                return $matches[1]
            }
            else {
                Write-Warning "No JSON object found in response."
                return $Text
            }
        }
        else {
            return $Text
        }

    }
    catch {
        Write-Error "Failed to get response from Azure OpenAI:`n$($_.Exception.Message)"
    }
}