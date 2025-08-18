function Invoke-PSUPromptOnPerplexityAi {
    <#
    .SYNOPSIS
        Sends a text prompt to the Perplexity AI API and returns the generated response.

    .DESCRIPTION
        This function interacts with the Perplexity AI chat completions API to perform
        AI content generation based on the provided prompt and configurable parameters.

        How to get started:
        ----------------------
        1. Visit: https://labs.perplexity.ai/
        2. Sign up or log in.
        3. Navigate to your API keys or developer settings.
        4. Create an API key.
        5. Copy the key and save it using:

            Set-PSUUserEnvironmentVariable -Name "API_KEY_PERPLEXITY" -Value "<your-api-key>"

        You're now ready to call `Invoke-PSUPromptOnPerplexityAi` with your prompt!

    .PARAMETER Prompt
        (Mandatory) The text you want Perplexity AI to process and respond to.

    .PARAMETER ApiKey
        (Optional) The API key for Perplexity AI authentication.
        Default value is $env:API_KEY_PERPLEXITY. Set using: Set-PSUUserEnvironmentVariable -Name "API_KEY_PERPLEXITY" -Value "your-api-key"

    .PARAMETER Model
        (Optional) The Perplexity AI model to use for generation.
        Default value is "sonar". Common models include "sonar-small-online", "sonar-medium-online", etc.

    .PARAMETER MaxTokens
        (Optional) The maximum number of tokens the AI should generate in its response.
        Default value is 512.

    .PARAMETER Temperature
        (Optional) Controls the randomness and creativity of the generated response.
        Default value is 0.7. Values closer to 0 are more focused, values closer to 1.0 are more creative.

    .PARAMETER ReturnJsonResponse
        (Optional) Switch parameter to return the raw JSON response from the Perplexity AI API.

    .EXAMPLE
        Invoke-PSUPromptOnPerplexityAi -Prompt "Write a short poem about the future of AI."

    .EXAMPLE
        Invoke-PSUPromptOnPerplexityAi -Prompt "Explain quantum computing in simple terms" -Model "sonar-small-online" -MaxTokens 200

    .EXAMPLE
        Invoke-PSUPromptOnPerplexityAi -Prompt "List the main components of a computer" -ReturnJsonResponse | ConvertFrom-Json | Select-Object -ExpandProperty choices

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 22 July 2025
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
        [string]$ApiKey = $env:API_KEY_PERPLEXITY,

        [Parameter()]
        [string]$Model = "sonar",

        [Parameter()]
        [int]$MaxTokens = 512,

        [Parameter()]
        [double]$Temperature = 0.7,

        [Parameter()]
        [switch]$ReturnJsonResponse
    )

    if (-not $ApiKey) {
        Write-Error "Perplexity API key not found. Set it using:`nSet-PSUUserEnvironmentVariable -Name 'API_KEY_PERPLEXITY' -Value '<your-api-key>'"
        return
    }

    # Build request body
    $body = @{
        model       = $Model
        temperature = $Temperature
        max_tokens  = $MaxTokens
        messages    = @(
            @{
                role    = "user"
                content = $Prompt
            }
        )
    }

    $uri = "https://api.perplexity.ai/chat/completions"
    $headers = @{ "Authorization" = "Bearer $ApiKey" }

    try {
        Write-Host "🧠 Thinking..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers `
            -Body ($body | ConvertTo-Json -Depth 100) -ContentType 'application/json'

        if ($ReturnJsonResponse.IsPresent) {
            return ($response | ConvertTo-Json -Depth 10)
        }

        if ($response.choices.Count -gt 0 -and $response.choices[0].message.content) {
            return $response.choices[0].message.content.Trim()
        }
        else {
            throw "No content received from Perplexity API."
        }
    }
    catch {
        Write-Error "Failed to get response from Perplexity:`n$($_.Exception.Message)"
    }
}
