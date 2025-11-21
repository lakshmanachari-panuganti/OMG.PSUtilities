function Get-OptimalTimeout {
    <#
    .SYNOPSIS
        Calculates optimal timeout based on expected token processing time.

    .DESCRIPTION
        Calculates timeout with safety margin based on:
        - Estimated input tokens
        - Expected output tokens (MaxTokens)
        - Processing speed estimates
        - Safety margin multiplier

    .PARAMETER Prompt
        The prompt text to analyze

    .PARAMETER MaxTokens
        Maximum tokens expected in response

    .PARAMETER SafetyMultiplier
        Multiply base timeout by this factor. Default is 2 (100% safety margin).

    .PARAMETER MinimumTimeout
        Minimum timeout in seconds. Default is 60.

    .PARAMETER MaximumTimeout
        Maximum timeout in seconds. Default is 1800 (30 minutes).

    .EXAMPLE
        Get-OptimalTimeout -Prompt "Quick question" -MaxTokens 500
        Returns: 60 (minimum timeout for small requests)

    .EXAMPLE
        Get-OptimalTimeout -Prompt $largePrompt -MaxTokens 8000
        Returns: 600 (calculated based on token count)

    .EXAMPLE
        $timeout = Get-OptimalTimeout -Prompt $prompt -MaxTokens 4096 -SafetyMultiplier 3
        Use more conservative timeout (3x safety margin)
    #>

    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [int]$MaxTokens,

        [Parameter()]
        [ValidateRange(1, 5)]
        [double]$SafetyMultiplier = 2,

        [Parameter()]
        [int]$MinimumTimeout = 60,

        [Parameter()]
        [int]$MaximumTimeout = 1800
    )

    # Estimate input tokens
    $estimatedInputTokens = [Math]::Ceiling($Prompt.Length / 4)

    # Calculate total tokens to process
    $totalTokens = $estimatedInputTokens + $MaxTokens

    # Base calculation: ~1 second per 80 tokens + 30 second overhead
    # This is based on observed GPT-4o/Turbo processing speeds
    $baseTimeout = [Math]::Ceiling($totalTokens / 80) + 30

    # Apply safety multiplier
    $calculatedTimeout = [Math]::Ceiling($baseTimeout * $SafetyMultiplier)

    # Enforce minimum and maximum bounds
    $optimalTimeout = [Math]::Max($MinimumTimeout, [Math]::Min($MaximumTimeout, $calculatedTimeout))

    Write-Verbose "Input tokens (estimated): $estimatedInputTokens"
    Write-Verbose "Max output tokens: $MaxTokens"
    Write-Verbose "Total tokens: $totalTokens"
    Write-Verbose "Base timeout: $baseTimeout seconds"
    Write-Verbose "Safety multiplier: ${SafetyMultiplier}x"
    Write-Verbose "Calculated timeout: $calculatedTimeout seconds"
    Write-Verbose "Optimal timeout: $optimalTimeout seconds"

    return $optimalTimeout
}