function Invoke-PSUPromptAI {
<#
.SYNOPSIS
    Sends a text prompt to the Google Gemini 2.0 Flash AI model and returns the generated response.

.DESCRIPTION
    This function sends a user-defined prompt to the Gemini 2.0 Flash model (via Google's Generative Language API)
    for fast and lightweight content generation.

    Steps to use this function:
    ---------------------------
    1. Go to the Gemini API Console: https://makersuite.google.com/app/apikey
    2. Sign in with your Google account
    3. Click "Create API Key" to generate your Gemini key
    4. Copy the API key and set it as an environment variable using:

        Set-PSUUserEnvironmentVariable -Name "GOOGLE_GEMINI_API_KEY" -Value "<your-api-key>"

    5. Then use this function to send prompts and receive AI-generated content.

.PARAMETER Prompt
    The text prompt you want to send to Gemini AI for generating content.

.PARAMETER ApiKey
    (Optional) The Gemini API key. If not supplied, the function uses the 'GOOGLE_GEMINI_API_KEY' environment variable.

.EXAMPLE
    Invoke-PSUPromptAI -Prompt "Generate a PowerShell function to list installed applications"

.EXAMPLE
    Ask-PSUAI -Prompt "Explain infrastructure as code in one line"

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 2025-07-03
    Model: Gemini 2.0 Flash via Generative Language API
#>
    [CmdletBinding()]
    [Alias("Ask-Ai", "Ask-PSUAi", "Query-PSUAi")]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter()]
        [string]$ApiKey = $env:GOOGLE_GEMINI_API_KEY
    )

    if (-not $ApiKey) {
        Write-Error "Gemini API key not found. Please set it using: Set-PSUUserEnvironmentVariable -Name 'GOOGLE_GEMINI_API_KEY' -Value '<your-api-key>'"
        return
    }

    $uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$ApiKey"
    $body = @{ contents = @(@{ parts = @(@{ text = $Prompt }) }) } | ConvertTo-Json -Depth 10

    try {
        Write-Host "Workign on it... 🧠" -ForegroundColor Cyan
        $response = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType 'application/json'
        $rawResponse = $response.candidates[0].content.parts[0].text
        $cleanedResponse = $rawResponse -replace '```json', '' -replace '```', '' -replace '^[\s\r\n]+|[\s\r\n]+$', ''
        Return $cleanedResponse
    } catch {
        $ErrMessage = $_.Exception.Message
        Write-Error "Failed to get response from Gemini: $ErrMessage"
    }
}
