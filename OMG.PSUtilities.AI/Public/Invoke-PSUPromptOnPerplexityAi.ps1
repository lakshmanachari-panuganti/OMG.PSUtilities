function Invoke-PSUPromptOnPerplexityAi {
    <#
    .SYNOPSIS
        Calls the Perplexity API to generate AI-powered answers with web search and citations.
    .DESCRIPTION
        This function sends chat-style prompts to the Perplexity API and returns AI-generated responses 
        with sources, using the selected Sonar model. Specify your API key via -ApiKey or the environment variable API_KEY_PERPLEXITY.
        How to Get Perplexity API key: https://www.youtube.com/watch?v=Xwcc-DQIOCs
    .PARAMETER ApiKey
        Your Perplexity API key (set via environment variable API_KEY_PERPLEXITY by default).
        How to Get Perplexity API key: https://www.youtube.com/watch?v=Xwcc-DQIOCs
    .PARAMETER Model
        The Perplexity model to use. Options:
        - "sonar" (default, fast and economical)
        - "sonar-pro" (for complex or longer queries)
        - "sonar-reasoning" (for multi-step logic)
        - "sonar-deep-research" (for comprehensive research)
    .PARAMETER Prompt
        Array of hashtables: each object must include 'role' ('system', 'user', or 'assistant') 
        and 'content'.
    .PARAMETER MaxTokens
        Maximum response tokens (default is 1000).
    .PARAMETER Temperature
        0.0 (more deterministic) to 2.0 (more random); default is 0.7.
    .PARAMETER Stream
        Enable streaming responses (default: $false).
    .PARAMETER SearchMode
        "web" (default) or "academic" for scholarly sources.
    .PARAMETER ReturnCitations
        $true (default): include sources in the response.
    .PARAMETER SearchDomainFilter
        Array of website domains to restrict web search (e.g. "learn.microsoft.com").
    .PARAMETER SearchRecencyFilter
        Filter for recency: "", "hour", "day", "week", "month", or "year"; default is empty.
    .EXAMPLE
        # Basic usage with message prompt and environment variable for API key
        $Prompt = @(
            @{ role = "system"; content = "You are a concise technical assistant." },
            @{ role = "user"; content = "Explain what an Azure Resource Group is." }
        )

        $result = Invoke-PSUPromptOnPerplexityAi -Prompt $Prompt
        $result.Content

    .EXAMPLE
        # With explicit API key, return only results from microsoft.com
        $Prompt = @(
        @{ role = "user"; content = "List top Azure VM series." }
        )

        $result = Invoke-PSUPromptOnPerplexityAi -ApiKey 'your-key-here' `
            -Prompt $Prompt `
            -SearchDomainFilter @("learn.microsoft.com") `
            -ReturnCitations $true
        $result.Content

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 22 July 2025
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable[]]$Prompt,

        [Parameter()]
        [string]$ApiKey = $env:API_KEY_PERPLEXITY,

        [Parameter()]
        [ValidateSet("sonar", "sonar-pro", "sonar-reasoning", "sonar-deep-research")]
        [string]$Model = "sonar-pro",

        [Parameter()]
        [int]$MaxTokens = 1000,

        [Parameter()]
        [ValidateRange(0.0, 2.0)]
        [double]$Temperature = 0.7,

        [Parameter()]
        [bool]$Stream = $false,

        [Parameter()]
        [ValidateSet("web", "academic")]
        [string]$SearchMode = "web",

        [Parameter()]
        [bool]$ReturnCitations = $true,

        [Parameter()]
        [string[]]$SearchDomainFilter = @(),

        [Parameter()]
        [ValidateSet("", "hour", "day", "week", "month", "year")]
        [string]$SearchRecencyFilter = ""
    )

    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        throw '$env:API_KEY_PERPLEXITY not found. Set it using:`nSet-PSUUserEnvironmentVariable -Name 'API_KEY_PERPLEXITY' -Value '<your-api-key>''
    }

    $headers = @{
        'Authorization' = "Bearer $ApiKey"
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json'
    }

    $requestBody = @{
        model            = $Model
        Prompt           = $Prompt
        max_tokens       = $MaxTokens
        temperature      = $Temperature
        stream           = $Stream
        search_mode      = $SearchMode
        return_citations = $ReturnCitations
    }

    if ($SearchDomainFilter.Count -gt 0) {
        $requestBody.search_domain_filter = $SearchDomainFilter
    }
    if (-not [string]::IsNullOrEmpty($SearchRecencyFilter)) {
        $requestBody.search_recency_filter = $SearchRecencyFilter
    }

    $jsonBody = $requestBody | ConvertTo-Json -Depth 10

    try {
        Write-Verbose "Sending request to Perplexity API with model: $Model"
        $response = Invoke-RestMethod -Uri "https://api.perplexity.ai/chat/completions" `
            -Method POST `
            -Headers $headers `
            -Body $jsonBody `
            -ErrorAction Stop
        return @{
            Content       = $response.choices[0].message.content
            Model         = $response.model
            Usage         = $response.usage
            Citations     = $response.citations
            SearchResults = $response.search_results
            FinishReason  = $response.choices[0].finish_reason
            RawResponse   = $response
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.ErrorDetails.Message
        Write-Error "Perplexity API Error (HTTP $statusCode): $errorMessage"
        throw "Failed to call Perplexity API: $($_.Exception.Message)"
    }
}
