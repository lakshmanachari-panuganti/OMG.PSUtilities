function Start-PSUGeminiChat {
    <#
.SYNOPSIS
    Interactive Gemini 3.5 Flash chatbot using Google's Generative Language API.

.DESCRIPTION
    Opens a PowerShell-based chat session with Gemini AI.

    This function interacts with Google's Generative Language API (Gemini 3.5 Flash model) to perform fast and
    lightweight AI content generation.

    Requires an environment variable named 'GEMINI_API_KEY'.

    How to get started:
    ----------------------
    1. Visit: https://makersuite.google.com/app/apikey
    2. Sign in with your Google account
    3. Click **"Create API Key"**
    4. Copy the key and save it using:

.PARAMETER ApiKey
    (Optional) The API key for Google Gemini AI service.
    Default value is $env:GEMINI_API_KEY. Set using: Set-PSUUserEnvironmentVariable -Name "GEMINI_API_KEY" -Value "your-api-key"

.NOTES
    Author: Lakshmanachari Panuganti
    Date: 4th July 2025
    History: Initial development of Start-PSUGeminiChat Chatbot.

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AI
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AI
    https://ai.google.dev/gemini-api/docs

.EXAMPLE
    Start-PSUGeminiChat

.OUTPUTS
    None. This function provides an interactive console session.
#>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'Function is interactive chat interface that requires real-time console feedback'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseBOMForUnicodeEncodedFile", "", Justification = "UTF-8 BOM will be added in build process")]
    param (
        [string]$ApiKey
    )

    # Resolve the key from secure storage when the caller did not supply one. Get-PSUSecret
    # prefers Windows Credential Manager and falls back to the GEMINI_API_KEY environment
    # variable, so existing exported configuration keeps working. A missing secret leaves
    # $ApiKey empty, preserving this command's existing behaviour for that case. An
    # explicitly supplied -ApiKey, even an empty one, is always respected as-is.
    if (-not $PSBoundParameters.ContainsKey('ApiKey') -and [string]::IsNullOrWhiteSpace($ApiKey)) {
        try {
            $ApiKey = Get-PSUSecret -Name 'GEMINI_API_KEY' -AsPlainText
        }
        catch {
            Write-Verbose "No stored secret found for GEMINI_API_KEY."
        }
    }

    if (-not $ApiKey) {
        Write-Error "Gemini API key not found. Please set it using:`nSet-PSUUserEnvironmentVariable -Name 'GEMINI_API_KEY' -Value '<your-api-key>'"
        return
    }

    # ShouldProcess check
    if (-not $PSCmdlet.ShouldProcess("Gemini Chat Session", "Start interactive chat with Gemini AI")) {
        return
    }

    $uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent"
    $chatHistory = [System.Collections.Generic.List[hashtable]]::new()

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

        $chatHistory.Add(@{ role = "user"; parts = @(@{ text = $prompt }) })

        $body = @{ contents = $chatHistory } | ConvertTo-Json -Depth 10

        try {
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers @{ 'x-goog-api-key' = $ApiKey } -Body $body -ContentType 'application/json'

            $text = $response.candidates[0].content.parts[0].text
            #$text = $text -replace '```json', '' -replace '```', '' -replace '^[\s\r\n]+|[\s\r\n]+$', ''

            Write-Host "`n🤖 PSU-Ai: " -NoNewline
            Write-Host $text -ForegroundColor Yellow

            $chatHistory.Add(@{ role = "model"; parts = @(@{ text = $text }) })
        }
        catch {
            Write-Error "Error communicating with Gemini: $($_.Exception.Message)"
        }
    }
}