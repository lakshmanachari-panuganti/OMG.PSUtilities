# Helper function to extract and validate JSON with AI-powered correction
function Get-ValidJson {
    param(
        [string]$Text,
        [int]$RetryCount = 0,
        [int]$MaxRetries,
        [string]$ModelName,
        [int]$Tokens,
        [hashtable]$Headers,
        [string]$Uri
    )

    # Try to parse as-is first
    try {
        $null = ConvertFrom-Json $Text -ErrorAction Stop
        return $Text
    } catch {
        # Not valid JSON, try to extract it
    }

    # Remove markdown code fences
    $cleaned = $Text -replace '(?s)^```json\s*', '' -replace '(?s)\s*```$', ''
    $cleaned = $cleaned -replace '(?s)^```\s*', '' -replace '(?s)\s*```$', ''
        
    # Try after removing code fences
    try {
        $null = ConvertFrom-Json $cleaned -ErrorAction Stop
        return $cleaned
    } catch {
        # Still not valid, try to find JSON object
    }

    # Try to find JSON object or array in the text
    # Match outermost {} or []
    if ($cleaned -match '(?s)(\{.*\}|\[.*\])') {
        $extracted = $matches[1]
        try {
            $null = ConvertFrom-Json $extracted -ErrorAction Stop
            return $extracted
        } catch {
            # Last attempt: find first { to last }
            $firstBrace = $cleaned.IndexOf('{')
            $lastBrace = $cleaned.LastIndexOf('}')
                
            if ($firstBrace -ge 0 -and $lastBrace -gt $firstBrace) {
                $extracted = $cleaned.Substring($firstBrace, $lastBrace - $firstBrace + 1)
                try {
                    $null = ConvertFrom-Json $extracted -ErrorAction Stop
                    return $extracted
                } catch {
                    # Give up on extraction
                }
            }
        }
    }

    # If we have exhausted extraction attempts and haven't exceeded retry limit, asking AI to fix it!
    if ($RetryCount -lt $MaxRetries) {
        Write-Warning "Invalid JSON detected. Attempting AI-powered correction (Attempt $($RetryCount + 1)/$MaxRetries)..."
            
        $fixPrompt = @"
The following text is supposed to be valid JSON but is malformed or contains extra content.
Your task: Extract or fix it to return ONLY valid, parseable JSON.

Rules:
- Return ONLY the JSON object or array
- Remove any explanatory text, markdown, or extra content
- Fix any JSON syntax errors (missing commas, quotes, brackets, etc.)
- Ensure all strings are properly quoted
- Ensure all keys are quoted
- NO text before or after the JSON
- Start with { or [ and end with } or ]

Original text:
$Text

Return the corrected JSON:
"@

        try {
            $invokeParams = @{
                PromptText = $fixPrompt
                ModelName  = $ModelName
                Temp       = 0.1
                Tokens     = $Tokens
                Headers    = $Headers
                Uri        = $Uri
                Silent     = $true
            }
            $fixedJson = Invoke-PerplexityApiCall @invokeParams
                
            # Recursively validate the fixed JSON using parameter splatting
            $nextParams = @{
                Text       = $fixedJson
                RetryCount = $RetryCount + 1
                MaxRetries = $MaxRetries
                ModelName  = $ModelName
                Tokens     = $Tokens
                Headers    = $Headers
                Uri        = $Uri
            }
            return Get-ValidJson @nextParams
        } catch {
            Write-Warning "AI correction attempt $($RetryCount + 1) failed: $($_.Exception.Message)"
            if ($RetryCount + 1 -ge $MaxRetries) {
                throw "Could not extract or fix JSON after $MaxRetries attempts. Raw response: $Text"
            }
        }
    }

    # Could not extract valid JSON even after retries
    throw "Could not extract valid JSON from response after $MaxRetries attempts. Raw response: $Text"
}