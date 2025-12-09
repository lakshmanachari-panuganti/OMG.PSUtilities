function Invoke-PSUAiPrompt {
    <#
    .SYNOPSIS
        Routes a prompt to the selected AI engine (AzureOpenAI, GeminiAI, PerplexityAI) and returns the response.

    .DESCRIPTION
        This function dispatches a prompt to the configured AI engine, supporting JSON response mode.
        It enforces strict parameter validation and logs parameters for diagnostics.

    .PARAMETER Prompt
        The message to send to the AI engine for generating a response.

    .PARAMETER DefaultAiEngine
        (Optional) The AI engine to use. Default is $env:DEFAULT_AI_ENGINE.

    .PARAMETER ReturnJsonResponse
        (Optional) Switch to request raw JSON response from the AI engine.

    .EXAMPLE
        Invoke-PSUAiPrompt -Prompt "Summarize Kubernetes in one line"

    .OUTPUTS
        [String]

    .NOTES
        Author: Lakshmanachari Panuganti
        Created: 2025-07-27
        Last Modified: 2025-10-19
    #>
    [CmdletBinding()]
    [alias("askai")]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [Parameter()]
        [ValidateSet("AzureOpenAi", "GeminiAi", "PerplexityAi")]
        [string]$DefaultAiEngine = $env:DEFAULT_AI_ENGINE,

        [Parameter()]
        [switch]$ReturnJsonResponse
    )

    begin {
        Write-Verbose "[Invoke-PSUAiPrompt] Parameters:"
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            Write-Verbose "  $($param.Key) = $($param.Value)"
        }
        if ([string]::IsNullOrWhiteSpace($Prompt)) {
            throw "Prompt parameter is required."
        }
        if ([string]::IsNullOrWhiteSpace($DefaultAiEngine)) {
            throw "DefaultAiEngine parameter is required. Set via: Set-PSUUserEnvironmentVariable -Name 'DEFAULT_AI_ENGINE' -Value '<engine>'"
        }
    }

    process {
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
                throw "Unsupported AI provider: $DefaultAiEngine. Please set `$env:DEFAULT_AI_ENGINE to one of: AzureOpenAi, GeminiAi, PerplexityAi."
            }
        }
    }
}
