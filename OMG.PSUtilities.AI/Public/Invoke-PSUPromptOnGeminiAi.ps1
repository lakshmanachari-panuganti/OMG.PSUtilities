function Invoke-PSUPromptOnGeminiAi {
    <#
.SYNOPSIS
    Sends a text prompt to the Google Gemini 3.5 Flash AI model and returns the generated response.

.DESCRIPTION
    This function interacts with Google's Generative Language API (Gemini 3.5 Flash model) to perform fast and
    lightweight AI content generation.

    How to get started:
    ----------------------
    1. Visit: https://makersuite.google.com/app/apikey
    2. Sign in with your Google account
    3. Click **"Create API Key"**
    4. Copy the key and save it using:

        Set-PSUUserEnvironmentVariable -Name "GEMINI_API_KEY" -Value "<your-api-key>"

    You're now ready to call `Invoke-PSUPromptOnGeminiAi` with your prompt!

.PARAMETER Prompt
    (Mandatory) The text you want Gemini AI to process and respond to.

.PARAMETER ApiKey
    (Optional) The API key for Google Gemini AI service.
    Default value is $env:GEMINI_API_KEY. Set using: Set-PSUUserEnvironmentVariable -Name "GEMINI_API_KEY" -Value "your-api-key"

.PARAMETER ReturnJsonResponse
    (Optional) Switch parameter to return only valid JSON object from the response.

.EXAMPLE
    Invoke-PSUPromptOnGeminiAi -Prompt "Generate a PowerShell script to get system uptime"

.EXAMPLE
    Invoke-PSUPromptOnGeminiAi -Prompt "Summarize cloud computing in one line"

.OUTPUTS
    [System.String] or [PSCustomObject]

.NOTES
    Author: Lakshmanachari Panuganti
    Date: 2025-07-03
    Model: Gemini 3.5 Flash (Generative Language API)

.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AI
    https://www.linkedin.com/in/lakshmanachari-panuganti/
    https://www.powershellgallery.com/packages/OMG.PSUtilities.AI
    https://ai.google.dev/gemini-api/docs

#>
    [CmdletBinding()]
    [alias("askgemini")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
                if ([string]::IsNullOrWhiteSpace($_)) {
                    throw "Prompt cannot be null, empty, or contain only whitespace."
                }
                return $true
            })]
        [string]$Prompt,

        [Parameter()]
        [string]$ApiKey,

        [Parameter()]
        [switch]$ReturnJsonResponse,

        [Parameter()]
        [switch]$UseProxy
    )

    #----------[Determine which API to use based on ApiKey availability]----------

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

    if ([string]::IsNullOrWhiteSpace($ApiKey) -or $UseProxy.IsPresent) {
        if (-not $ApiKey) { Write-Verbose "GEMINI_API_KEY not configured - Routing request through proxy..." }
        if ($UseProxy.IsPresent) { Write-Verbose "UseProxy parameter enforced - Routing request through proxy..." }

        try {
            $geminiresponse = Invoke-GeminiAIApi -Prompt $Prompt -ReturnJsonResponse:$ReturnJsonResponse
            return $geminiresponse.response
        } catch {
            Write-Error "Failed to get response from Gemini proxy: $($_.Exception.Message)"
            Write-Host ""
            Write-Host "    Alternatively, you can use direct Gemini API with your own key:" -ForegroundColor Yellow
            Write-Host "    ---------------------------------------------------------------" -ForegroundColor Yellow
            Write-Host @"
   1. Visit: https://makersuite.google.com/app/apikey
   2. Sign in with your Google account
   3. Click **"Create API Key"**
   4. Copy the key and save it using:

       Set-PSUUserEnvironmentVariable -Name "GEMINI_API_KEY" -Value "YOUR_API_KEY_VALUE"

"@ -ForegroundColor Cyan
            return
        }
    }

    # API key exists - use direct Gemini API
    Write-Verbose "Using direct Gemini API with provided API key..."

    if ($ReturnJsonResponse.IsPresent) {
        $Prompt += "`nReturn only a valid JSON object. Exclude any additional text, explanations, or formatting such as triple backticks. The output must be raw JSON with appropriate properties."
        $Prompt += "`nExample 1: { ""scriptName"": ""Backup-Logs.ps1"", ""author"": ""adminUser"", ""lastModified"": ""2025-07-15T10:45:00Z"", ""parameters"": [""sourcePath"", ""destinationPath""] }"
        $Prompt += "`nExample 2: { ""planet"": ""Mars"", ""distanceFromSun_km"": 227943824, ""hasAtmosphere"": true, ""moons"": 2 }"
        $Prompt += "`nExample 3: { ""fullName"": ""Asha Verma"", ""age"": 34, ""city"": ""Pune"", ""interests"": [""traveling"", ""reading"", ""music""] }"
    }

    $uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent"
    $body = @{ contents = @(@{ parts = @(@{ text = $Prompt }) }) } | ConvertTo-Json -Depth 10

    try {
        Write-Host "🧠 Thinking..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers @{ 'x-goog-api-key' = $ApiKey } -Body $body -ContentType 'application/json'

        if ($response.candidates.Count -eq 0 -or -not $response.candidates[0].content.parts[0].text) {
            throw "No content received from Gemini API."
        }

        $rawText = $response.candidates[0].content.parts[0].text

        if ($ReturnJsonResponse.IsPresent) {
            # MaxRetries 0 keeps this to local parsing - Get-ValidJson only knows how to call Perplexity
            try {
                return Get-ValidJson -Text $rawText -MaxRetries 0
            } catch {
                Write-Warning "Could not find a JSON object in the response."
                return $rawText
            }
        } else {
            return $rawText
        }

    } catch {
        Write-Error "Failed to get response from Gemini:`n$($_.Exception.Message)"
    }
}