function Invoke-PSUAiPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DefaultAiEngine = $env:DEFAULT_AI_ENGINE,

        [Parameter()]
        [switch]$ReturnJsonResponse
    )

    switch ($DefaultAiEngine.ToLower()) {
        "azureopenai" {
            Write-Verbose "Using Azure OpenAI as the default AI engine"
            if ($ReturnJsonResponse) {
                return Invoke-PSUPromptOnAzureOpenAi -Prompt $Prompt -ReturnJsonResponse
            } else {
                return Invoke-PSUPromptOnAzureOpenAi -Prompt $Prompt
            }
        }
        "geminiai" {
            Write-Verbose "Using Gemini as the default AI engine"
            if ($ReturnJsonResponse) {
                return Invoke-PSUPromptOnGeminiAi -Prompt $Prompt -ReturnJsonResponse
            } else {
                return Invoke-PSUPromptOnGeminiAi -Prompt $Prompt
            }
        }
        "perplexityai" {
            Write-Verbose "Using Perplexity as the default AI engine"
            if ($ReturnJsonResponse) {
                return Invoke-PSUPromptOnPerplexityAi -Prompt $Prompt -ReturnJsonResponse
            } else {
                return Invoke-PSUPromptOnPerplexityAi -Prompt $Prompt
            }
        }
        default {
            throw "Unsupported AI provider: $DefaultAiEngine. Please set `$env:DEFAULT_AI_ENGINE to one of: OpenAi, GeminiAi, PerplexityAi."
        }
    }
}
