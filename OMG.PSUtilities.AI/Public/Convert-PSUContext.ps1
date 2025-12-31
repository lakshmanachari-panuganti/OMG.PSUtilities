function Convert-PSUContext {
    <#
    .SYNOPSIS
        Rephrases text into a specified length and tone.

    .DESCRIPTION
        Converts the provided text into a rephrased version based on
        the selected length and tone using the AI API

    .PARAMETER Text
        The input text to be rephrased.

    .PARAMETER Length
        Controls the verbosity of the output.
        Supported values: Concise, Brief, Detailed.

    .PARAMETER Tone
        Controls the tone of the output.
        Supported values: Professional, Casual, Formal.

    .EXAMPLE
        Convert-PSUContext -Text "Please check this issue" -Length Brief -Tone Professional

    .EXAMPLE
        Rephrase-Context -Text "Can you help?" -Tone Formal

    .OUTPUTS
        System.String

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 29th December 2025
    #>

    [CmdletBinding()]
    [OutputType([string])]
    [alias('rephrase')]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Text,

        [Parameter(Position = 1)]
        [ValidateSet('Concise','Brief','Detailed')]
        [string]$Length = 'Concise',

        [Parameter(Position = 2)]
        [ValidateSet('Professional','Casual','Formal', 'AiPrompt')]
        [string]$Tone = 'Professional'
    )

    begin {
        Write-Verbose "Preparing prompt for context conversion"
    }

    process {
        try {
            # Build AI instruction prompt
            $prompt = @"
Rephrase the following text.

Requirements:
- Length: $Length
- Tone: $Tone
- Do not change the original meaning
- Correct grammar and clarity
- Return only the rephrased text

Text:
"$Text"
"@

            Write-Verbose "Invoking Gemini AI API"
            $response = Invoke-GeminiAIApi -Prompt $prompt

            if (-not $response) {
                throw "Empty response received from Gemini AI API."
            }

            # Normalize output (handles string or object responses)
            if ($response -is [string]) {
                return $response.Trim()
            }

            if ($response.text) {
                return $response.text.Trim()
            }

            # Fallback – stringify safely
            return ($response.response | Out-String).Trim()
        }
        catch {
            Write-Error "Failed to convert context: $($_.Exception.Message)"
            throw
        }
    }
}
