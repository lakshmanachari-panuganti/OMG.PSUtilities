function Invoke-PSUPromptOnAzureOpenAi {
    <#
    .SYNOPSIS
        Sends a prompt to Azure OpenAI (Chat Completions API) and returns the generated response.

    .DESCRIPTION
        This function interacts with Azure-hosted OpenAI (e.g., GPT-4, GPT-4o, GPT-5) using the Chat Completions endpoint.
        It supports structured JSON response parsing, handles large prompts, and automatically calculates optimal
        MaxTokens and TimeoutSeconds based on prompt size if not specified.

        AUTOMATIC MODE SELECTION:
        ------------------------
        The function automatically determines whether to use:
        - PROXY MODE: If any Azure OpenAI environment variables are missing (recommended for most users)
        - DIRECT API MODE: If all three environment variables are present (API_KEY_AZURE_OPENAI, AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_DEPLOYMENT)

        For direct API access, configure:

            Set-PSUUserEnvironmentVariable -Name "API_KEY_AZURE_OPENAI" -Value "<your-api-key>"
            Set-PSUUserEnvironmentVariable -Name "AZURE_OPENAI_ENDPOINT" -Value "<your-endpoint>"
            Set-PSUUserEnvironmentVariable -Name "AZURE_OPENAI_DEPLOYMENT" -Value "<your-deployment-name>"


    .PARAMETER Prompt
        (Mandatory) The message to send to Azure OpenAI for generating a response.    .PARAMETER ApiKey
        (Optional) The API key for Azure OpenAI authentication.
        Default value is $env:API_KEY_AZURE_OPENAI.

    .PARAMETER Endpoint
        (Optional) The Azure OpenAI endpoint URL.
        Default value is $env:AZURE_OPENAI_ENDPOINT.

    .PARAMETER Deployment
        (Optional) The Azure OpenAI deployment name.
        Default value is $env:AZURE_OPENAI_DEPLOYMENT.

    .PARAMETER MaxTokens
        (Optional) Maximum tokens for the response. Default is 4096.

    .PARAMETER Temperature
        (Optional) Controls randomness (0-2). Default is 0.7.

    .PARAMETER TimeoutSeconds
        (Optional) Request timeout in seconds. Default is 300 (5 minutes).

    .PARAMETER ReturnJsonResponse
        (Optional) Switch parameter to extract and return raw JSON from the response.

    .PARAMETER ApiVersion
        (Optional) Azure OpenAI API version. Default is "2024-12-01-preview".

    .EXAMPLE
        # Automatic mode - uses proxy if credentials not set
        Invoke-PSUPromptOnAzureOpenAi -Prompt "Explain Azure in one sentence"

    .EXAMPLE
        # With JSON response parsing
        Invoke-PSUPromptOnAzureOpenAi -Prompt "Return JSON with name and age fields" -ReturnJsonResponse

    .EXAMPLE
        # Override with explicit credentials for direct API
        Invoke-PSUPromptOnAzureOpenAi -Prompt "Hello" -ApiKey $key -Endpoint $endpoint -Deployment $deployment

    .OUTPUTS
    [String]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2025-08-01

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AI
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AI
        https://learn.microsoft.com/en-us/azure/ai-services/openai/reference

    #>

    [CmdletBinding()]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if ([string]::IsNullOrWhiteSpace($_)) {
            throw "Prompt cannot be null, empty, or contain only whitespace."
            }
            return $true
        })]
        [string]$Prompt,

        [Parameter()]
        [string]$ApiKey = $env:API_KEY_AZURE_OPENAI,

        [Parameter()]
        [string]$Endpoint = $env:AZURE_OPENAI_ENDPOINT,

        [Parameter()]
        [string]$Deployment = $env:AZURE_OPENAI_DEPLOYMENT,

        [Parameter()]
        [ValidateRange(1, 128000)]
        [int]$MaxTokens,

        [Parameter()]
        [ValidateRange(0, 2)]
        [double]$Temperature = 0.7,

        [Parameter()]
        [ValidateRange(30, 1800)]
        [int]$TimeoutSeconds,

        [Parameter()]
        [switch]$ReturnJsonResponse,

        [Parameter()]
        [string]$ApiVersion = '2024-12-01-preview'
    )

    process {
        # Calculate optimal MaxTokens if not provided
        if (-not $MaxTokens) {
            $MaxTokens = Get-OptimalMaxTokens -Prompt $Prompt -ResponseSize "Medium"
        }

        # Calculate optimal timeout if not provided
        if (-not $TimeoutSeconds) {
            $TimeoutSeconds = Get-OptimalTimeout -Prompt $Prompt -MaxTokens $MaxTokens
        }

        # Check if all three environment variables are present for direct API access
        $useDirectApi = ($ApiKey -and $Endpoint -and $Deployment)

        if (-not $useDirectApi) {
            # Use Proxy (one or more credentials missing)
            Write-Verbose "One or more Azure OpenAI credentials missing. Using proxy mode."

            $ProxyBody = @{
                Prompt = $Prompt
                MaxTokens = $MaxTokens
                Temperature = $Temperature
                ReturnJsonResponse = $ReturnJsonResponse.IsPresent
            } | ConvertTo-Json

            try {
                $response = Invoke-RestMethod -Uri "https://omg-psu-proxy.azurewebsites.net/api/ProxyOpenAI?code=$($script:var_c)" -Method Post -Body $ProxyBody -ContentType "application/json" -TimeoutSec $TimeoutSeconds
                return $response.response
            } catch {
                Write-Error "Proxy request failed and no direct API credentials available. Error: $($_.Exception.Message)"
                return
            }
        }

        # Direct API mode (all credentials present)
        Write-Verbose "All Azure OpenAI credentials present. Using direct API mode."

        # Normalize endpoint (remove trailing slash and any path)
        $Endpoint = $Endpoint.TrimEnd('/')

        # Remove common incorrect suffixes
        $Endpoint = $Endpoint -replace '/openai.*$', ''

        # Construct proper URL
        $fullUrl = "$Endpoint/openai/deployments/$Deployment/chat/completions?api-version=$ApiVersion"

        # Modify prompt for JSON if needed
        $ModifiedPrompt = if ($ReturnJsonResponse.IsPresent) {
            @"
$Prompt

CRITICAL: Respond with ONLY valid JSON. No markdown, no code blocks, no explanations.
Just pure JSON that starts with { or [
"@
        }
        else {
            $Prompt
        }

        $Headers = @{
            "api-key"      = $ApiKey
            "Content-Type" = "application/json"
        }

        $requestBody = @{
            messages = @(
                @{
                    role    = "user"
                    content = $ModifiedPrompt
                }
            )
            max_tokens  = $MaxTokens
            temperature = $Temperature
        }

        try {
            $Body = $requestBody | ConvertTo-Json -Depth 10 -Compress
            Write-Verbose "Request body size: $($Body.Length) bytes"
        } catch {
            Write-Error "Failed to serialize request: $($_.Exception.Message)"
            return
        }

        Write-Host "🧠 Thinking..." -ForegroundColor Cyan

        try {
            $Response = Invoke-RestMethod `
                -Method Post `
                -Uri $fullUrl `
                -Headers $Headers `
                -Body $Body `
                -ContentType 'application/json' `
                -TimeoutSec $TimeoutSeconds `
                -ErrorAction Stop

            $responseText = $Response.choices[0].message.content

            if ($ReturnJsonResponse.IsPresent) {
                # Remove markdown code blocks
                $cleanedText = $responseText -replace '```json\s*', '' -replace '```\s*', ''
                $cleanedText = $cleanedText.Trim()

                # Try to extract JSON
                if ($cleanedText -match '^\s*[\{\[]') {
                    try {
                        $null = $cleanedText | ConvertFrom-Json -ErrorAction Stop
                        return $cleanedText
                    } catch {
                        Write-Warning "Response contains invalid JSON"
                        return $responseText
                    }
                } else {
                    Write-Warning "Response doesn't appear to be JSON"
                    return $responseText
                }
            } else {
                return $responseText
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}