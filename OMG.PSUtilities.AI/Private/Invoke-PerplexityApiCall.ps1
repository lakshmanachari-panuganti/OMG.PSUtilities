# Helper function to make API call (to avoid code duplication)
function Invoke-PerplexityApiCall {
    param(
        [string]$PromptText,
        [string]$ModelName,
        [double]$Temp,
        [int]$Tokens,
        [hashtable]$Headers,
        [string]$Uri,
        [switch]$Silent
    )

    $body = @{
        model       = $ModelName
        temperature = $Temp
        max_tokens  = $Tokens
        messages    = @(
            @{
                role    = "user"
                content = $PromptText
            }
        )
    }

    if (-not $Silent) {
        Write-Host "🧠 Thinking..." -ForegroundColor Cyan
    }

    $invokeParams = @{
        Method      = 'Post'
        Uri         = $Uri
        Headers     = $Headers
        Body        = ($body | ConvertTo-Json -Depth 100)
        ContentType = 'application/json'
    }
        
    $response = Invoke-RestMethod @invokeParams

    if ($response.choices.Count -gt 0 -and $response.choices[0].message.content) {
        return $response.choices[0].message.content.Trim()
    } else {
        throw "No content received from Perplexity API."
    }
}