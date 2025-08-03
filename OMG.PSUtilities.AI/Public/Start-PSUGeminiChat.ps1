function Start-PSUGeminiChat {
    <#
.SYNOPSIS
    Interactive Gemini 2.0 Flash chatbot using Google's Generative Language API.

.DESCRIPTION
    Opens a PowerShell-based chat session with Gemini AI.

    This function interacts with Google's Generative Language API (Gemini 2.0 Flash model) to perform fast and
    lightweight AI content generation.

    Requires an environment variable named 'API_KEY_GEMINI'.

    How to get started:
    ----------------------
    1. Visit: https://makersuite.google.com/app/apikey
    2. Sign in with your Google account
    3. Click **"Create API Key"**
    4. Copy the key and save it using:

    Set-PSUUserEnvironmentVariable -Name "API_KEY_GEMINI" -Value "<your-api-key>"

.NOTES
    Author: Lakshmanachari Panuganti
    Date: 4th July 2025
    History: Initial development of Start-PSUGeminiChat Chatbot.

.EXAMPLE
    Start-PSUGeminiChat
#>

    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseBOMForUnicodeEncodedFile", "", Justification = "This script is intentionally saved without BOM.")]
    [Alias("Ask-Ai")]
    param (
        [string]$ApiKey = $env:API_KEY_GEMINI
    )

    if (-not $ApiKey) {
        Write-Error "Gemini API key not found. Please set it using:`nSet-PSUUserEnvironmentVariable -Name 'API_KEY_GEMINI' -Value '<your-api-key>'"
        return
    }

    $uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$ApiKey"
    $chatHistory = @()

    Write-Host "💬 Welcome to PSU Ai Chatbot!!" -ForegroundColor Green
    Write-Host "Type your message. Type 'exit' or 'q' to quit." -ForegroundColor Yellow

    while ($true) {
        Write-Host ""
        $prompt = Read-Host -Prompt "👤 You"

        if ($prompt -in @('clear', 'cls')) {
            Clear-Host
            continue
        }

        if ($prompt -in @('exit', 'q', 'bye')) {
            Write-Host "`n👋 Exiting chat. Goodbye!" -ForegroundColor Cyan
            break
        }

        $chatHistory += @{ role = "user"; parts = @(@{ text = $prompt }) }

        $body = @{ contents = $chatHistory } | ConvertTo-Json -Depth 10

        try {
            $response = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType 'application/json'

            $text = $response.candidates[0].content.parts[0].text
            #$text = $text -replace '```json', '' -replace '```', '' -replace '^[\s\r\n]+|[\s\r\n]+$', ''

            Write-Host "`n🤖 PSU-Ai: " -NoNewline
            Write-Host $text -ForegroundColor Yellow

            $chatHistory += @{ role = "model"; parts = @(@{ text = $text }) }
        }
        catch {
            Write-Error "Error communicating with Gemini: $($_.Exception.Message)"
        }
    }
}
