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
        Default value is "sonar-pro". Other options: "sonar", "sonar-reasoning", "sonar-reasoning-pro", "sonar-deep-research"

    .PARAMETER MaxTokens
        (Optional) The maximum number of tokens the AI should generate in its response.
        Default value is 512.

    .PARAMETER Temperature
        (Optional) Controls the randomness and creativity of the generated response.
        Default value is 0.7. Values closer to 0 are more focused, values closer to 1.0 are more creative.

    .PARAMETER ReturnJsonResponse
        (Optional) Switch parameter to return valid JSON response. If the response is not valid JSON,
        the function will automatically attempt to extract or fix it using AI-powered correction.

    .PARAMETER MaxJsonRetries
        (Optional) Maximum number of retry attempts for JSON correction using AI.
        Default value is 2.

    .EXAMPLE
        Invoke-PSUPromptOnPerplexityAi -Prompt "Write a short poem about the future of AI."

    .EXAMPLE
        Invoke-PSUPromptOnPerplexityAi -Prompt "Explain quantum computing in simple terms" -Model "sonar-reasoning" -MaxTokens 200

    .EXAMPLE
        $result = Invoke-PSUPromptOnPerplexityAi -Prompt "List top 5 programming languages" -ReturnJsonResponse
        $data = $result | ConvertFrom-Json

    .EXAMPLE
        # With custom retry attempts for JSON fixing
        Invoke-PSUPromptOnPerplexityAi -Prompt "Get weather data" -ReturnJsonResponse -MaxJsonRetries 3

    .NOTES
        Author: Lakshmanachari Panuganti
        Modified: October 2025
        Version: 2.0 - Added AI-powered JSON validation and correction

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AI
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AI
        https://docs.perplexity.ai/docs/getting-started

    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    [alias("askperplexity")]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Prompt,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ApiKey = $env:API_KEY_PERPLEXITY,

        [Parameter()]
        [ValidateSet('sonar', 'sonar-pro', 'sonar-reasoning', 'sonar-reasoning-pro', 'sonar-deep-research')]
        [string]$Model = "sonar-pro",

        [Parameter()]
        [ValidateRange(1, 4096)]
        [int]$MaxTokens = 512,

        [Parameter()]
        [ValidateRange(0.0, 1.0)]
        [double]$Temperature = 0.7,

        [Parameter()]
        [switch]$ReturnJsonResponse,

        [Parameter()]
        [ValidateRange(0, 5)]
        [int]$MaxJsonRetries = 2
    )

    # Main function logic
    if (-not $ApiKey) {
        Write-Error "Perplexity API key not found. Set it using:`nSet-PSUUserEnvironmentVariable -Name 'API_KEY_PERPLEXITY' -Value '<your-api-key>'"
        return
    }

    # Modify prompt for JSON responses
    if ($ReturnJsonResponse.IsPresent) {
        $Prompt += "`n`nIMPORTANT: You MUST respond with ONLY valid JSON. Follow these rules strictly:"
        $Prompt += "`n- Return ONLY a JSON object or array"
        $Prompt += "`n- Start immediately with '{' or '['"
        $Prompt += "`n- End with '}' or ']'"
        $Prompt += "`n- NO explanatory text before or after"
        $Prompt += "`n- NO markdown formatting (no ``````json)"
        $Prompt += "`n- NO phrases like 'Here is', 'Response:', etc."
        $Prompt += "`n- The entire response must be parseable by a JSON parser"
    }

    $uri = "https://api.perplexity.ai/chat/completions"
    $headers = @{ "Authorization" = "Bearer $ApiKey" }

    try {
        # Make the API call
        $content = Invoke-PerplexityApiCall -PromptText $Prompt `
            -ModelName $Model `
            -Temp $Temperature `
            -Tokens $MaxTokens `
            -Headers $headers `
            -Uri $uri

        if ($ReturnJsonResponse.IsPresent) {
            # Extract and validate JSON with AI-powered correction if needed
            try {
                $validJson = Get-ValidJson -Text $content `
                    -MaxRetries $MaxJsonRetries `
                    -ModelName $Model `
                    -Tokens $MaxTokens `
                    -Headers $headers `
                    -Uri $uri
                return $validJson
            }
            catch {
                Write-Error "Failed to extract or correct JSON response: $($_.Exception.Message)"
                Write-Warning "Raw response was: $content"
                throw
            }
        }
        else {
            return $content
        }
    }
    catch {
        Write-Error "Failed to get response from Perplexity:`n$($_.Exception.Message)"
    }
}

