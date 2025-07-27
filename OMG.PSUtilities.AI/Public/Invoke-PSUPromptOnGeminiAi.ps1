function Invoke-PSUPromptOnGeminiAi {
<#
.SYNOPSIS
    Sends a text prompt to the Google Gemini 2.0 Flash AI model and returns the generated response.

.DESCRIPTION
    This function interacts with Google's Generative Language API (Gemini 2.0 Flash model) to perform fast and
    lightweight AI content generation.

    How to get started:
    ----------------------
    1. Visit: https://makersuite.google.com/app/apikey  
    2. Sign in with your Google account  
    3. Click **"Create API Key"**  
    4. Copy the key and save it using:

        Set-PSUUserEnvironmentVariable -Name "API_KEY_GEMINI" -Value "<your-api-key>"

    You're now ready to call `Invoke-PSUPromptOnGeminiAi` with your prompt!

.PARAMETER Prompt
    The text you want Gemini AI to process and respond to.

.PARAMETER ApiKey
    Optional. Overrides the environment variable API_KEY_GEMINI with a manually supplied key.

.EXAMPLE
    Invoke-PSUPromptOnGeminiAi -Prompt "Generate a PowerShell script to get system uptime"

.EXAMPLE
    Invoke-PSUPromptOnGeminiAi -Prompt "Summarize cloud computing in one line"

.NOTES
    Author: Lakshmanachari Panuganti
    Created: 2025-07-03
    Model: Gemini 2.0 Flash (Generative Language API)
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter()]
        [string]$ApiKey = $env:API_KEY_GEMINI,

        [Parameter()]
        [switch]$ReturnJsonResponse
    )

    if (-not $ApiKey) {
        Write-Error "Gemini API key not found. Set it using:`nSet-PSUUserEnvironmentVariable -Name 'API_KEY_GEMINI' -Value '<your-api-key>'"
        return
    }
    if ($ReturnJsonResponse.IsPresent) {
        $Prompt += "`nRespond ONLY with a valid JSON object. Do NOT include any explanations, text. DO NOT include any Markdown Fencing formatting like triple backticks. Return raw JSON only with suitable properties."
    }

    $uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$ApiKey"
    $body = @{ contents = @(@{ parts = @(@{ text = $Prompt }) }) } | ConvertTo-Json -Depth 10

    try {
        Write-Host "🧠 Thinking..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType 'application/json'

        if ($response.candidates.Count -eq 0 -or -not $response.candidates[0].content.parts[0].text) {
            throw "No content received from Gemini API."
        }

        $rawText = $response.candidates[0].content.parts[0].text
        
        if ($ReturnJsonResponse.IsPresent) {
            $jsonBlock = ''
            if ($rawText -match '(?s)```json\s*(\{.*?\})\s*```') {
                $jsonBlock = $matches[1]
                $jsonBlock = $jsonBlock -replace '```json\s*|\s*```', ''
                return $jsonBlock
            }
            elseif ($rawText -match '(\{.*?\})') {
                return $matches[1]
            }
            else {
                Write-Warning "Could not find a JSON object in the response."
                return $rawText
            }
        } else {
            return $rawText
        }
        
    }
    catch {
        Write-Error "Failed to get response from Gemini:`n$($_.Exception.Message)"
    }
}