function Invoke-PSUPromptAI {
<#
.SYNOPSIS
    Sends a text prompt to the Google Gemini 2.0 Flash AI model and returns the generated response.

.DESCRIPTION
    This function interacts with Google's Generative Language API (Gemini 2.0 Flash model) to perform fast and
    lightweight AI content generation.

    📌 How to get started:
    ----------------------
    1️⃣ Visit: https://makersuite.google.com/app/apikey  
    2️⃣ Sign in with your Google account  
    3️⃣ Click **"Create API Key"**  
    4️⃣ Copy the key and save it using:

        Set-PSUUserEnvironmentVariable -Name "GOOGLE_GEMINI_API_KEY" -Value "<your-api-key>"

    ✅ You're now ready to call `Invoke-PSUPromptAI` with your prompt!

.PARAMETER Prompt
    The text you want Gemini AI to process and respond to.

.PARAMETER ApiKey
    Optional. Overrides the environment variable GOOGLE_GEMINI_API_KEY with a manually supplied key.

.EXAMPLE
    Invoke-PSUPromptAI -Prompt "Generate a PowerShell script to get system uptime"

.EXAMPLE
    Ask-PSUAI -Prompt "Summarize cloud computing in one line"

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 2025-07-03
    Alias: Ask-Ai, Ask-PSUAi, Query-PSUAi
    Model: Gemini 2.0 Flash (Generative Language API)
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt = $Prompt,

        [Parameter()]
        [string]$ApiKey = $env:GOOGLE_GEMINI_API_KEY
    )

    if (-not $ApiKey) {
        Write-Error "Gemini API key not found. Set it using:`nSet-PSUUserEnvironmentVariable -Name 'GOOGLE_GEMINI_API_KEY' -Value '<your-api-key>'"
        return
    }

    $uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$ApiKey"
    $body = @{ contents = @(@{ parts = @(@{ text = $Prompt }) }) } | ConvertTo-Json -Depth 10

    try {
        Write-Host "🧠 Thinking..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType 'application/json'

        if ($response.candidates.Count -eq 0 -or -not $response.candidates[0].content.parts[0].text) {
            throw "No content received from Gemini API."
        }

        $rawResponse = $response.candidates[0].content.parts[0].text
        $jsonBlock = ''
        if ($rawResponse -match '(?s)```json\s*(\{.*?\})\s*```') {
            $jsonBlock = $matches[1]
            $jsonBlock = $jsonBlock -replace '```json\s*|\s*```', ''
            return $jsonBlock
        }
        elseif ($rawResponse -match '(\{.*?\})') {
            return $matches[1]
        }
        else {
            Write-Warning "❗ Could not find a JSON object in the response."
            return $rawResponse
        }
    }
    catch {
        Write-Error "Failed to get response from Gemini:`n$($_.Exception.Message)"
    }
}