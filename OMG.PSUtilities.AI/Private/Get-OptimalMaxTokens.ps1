function Get-OptimalMaxTokens {
    <#
    .SYNOPSIS
        Calculates optimal MaxTokens based on prompt size and desired response size.

    .DESCRIPTION
        Analyzes the prompt and returns recommended MaxTokens value based on:
        - Estimated input token count
        - Desired response size (Tiny/Small/Medium/Large/Huge/Maximum)
        - Model context window limits

    .PARAMETER Prompt
        The prompt text to analyze

    .PARAMETER ResponseSize
        Desired response size. Default is 'Medium'.
        - Tiny: 300 tokens (~225 words, ~1 paragraph)
        - Small: 1000 tokens (~750 words, ~1 page)
        - Medium: 2000 tokens (~1,500 words, ~3 pages)
        - Large: 4096 tokens (~3,000 words, ~6 pages)
        - Huge: 8000 tokens (~6,000 words, ~12 pages)
        - Maximum: 16000 tokens (~12,000 words, ~24 pages)

    .PARAMETER ModelContextWindow
        Total context window of the model. Default is 128000 (for GPT-4o/Turbo).

    .EXAMPLE
        Get-OptimalMaxTokens -Prompt "What is Docker?"
        Returns: 2000 (Medium default)

    .EXAMPLE
        Get-OptimalMaxTokens -Prompt $largePrompt -ResponseSize "Huge"
        Returns: 8000

    .EXAMPLE
        $maxTokens = Get-OptimalMaxTokens -Prompt $prompt -ResponseSize "Large"
        Use calculated value in API call
    #>

    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter()]
        [ValidateSet('Tiny', 'Small', 'Medium', 'Large', 'Huge', 'Maximum')]
        [string]$ResponseSize = 'Medium',

        [Parameter()]
        [int]$ModelContextWindow = 128000
    )

    # Estimate input tokens (1 token ≈ 4 characters for English)
    $estimatedInputTokens = [Math]::Ceiling($Prompt.Length / 4)

    # Response size presets
    $responseSizeMap = @{
        'Tiny'    = 300
        'Small'   = 1000
        'Medium'  = 2000
        'Large'   = 4096
        'Huge'    = 8000
        'Maximum' = 16000
    }

    $desiredMaxTokens = $responseSizeMap[$ResponseSize]

    # Ensure we don't exceed model context window
    # Reserve 500 tokens as safety buffer
    $availableTokens = $ModelContextWindow - $estimatedInputTokens - 500

    if ($availableTokens -le 0) {
        Write-Warning "Prompt is too large! Estimated $estimatedInputTokens tokens exceeds model limit."
        return 1000  # Return minimum viable value
    }

    # Use the smaller of desired tokens or available tokens
    $optimalMaxTokens = [Math]::Min($desiredMaxTokens, $availableTokens)

    Write-Verbose "Input tokens (estimated): $estimatedInputTokens"
    Write-Verbose "Desired MaxTokens: $desiredMaxTokens"
    Write-Verbose "Available tokens: $availableTokens"
    Write-Verbose "Optimal MaxTokens: $optimalMaxTokens"

    return $optimalMaxTokens
}

$script:headers = @{
    "Content-Type" = "application/json"
    "X-Username" = "$($env:username)-$($env:userdnsdomain)"
    "X-Machine"  = "$($env:computername)-$($env:userdnsdomain)"
}
