function Invoke-PSUPromptOnAzureOpenAi {
    <#
    .SYNOPSIS
        Sends a prompt to Azure OpenAI (Chat Completions API) and returns the generated response.

    .DESCRIPTION
        This function interacts with Azure-hosted OpenAI (e.g., GPT-4, GPT-4o, GPT-5) using the Chat Completions endpoint.
        It supports structured JSON response parsing, handles large prompts, and automatically calculates optimal
        MaxTokens and TimeoutSeconds based on prompt size if not specified.

        How to configure:
        -----------------
        1. Go to Azure Portal → OpenAI Resource
        2. Deploy a model (e.g., GPT-4o, GPT-5)
        3. Copy your API Key and Endpoint
        4. Set credentials using:

            Set-PSUUserEnvironmentVariable -Name "API_KEY_AZURE_OPENAI" -Value "<your-api-key>"
            Set-PSUUserEnvironmentVariable -Name "AZURE_OPENAI_ENDPOINT" -Value "<your-endpoint>"
            Set-PSUUserEnvironmentVariable -Name "AZURE_OPENAI_DEPLOYMENT" -Value "<your-deployment-name>"


    .PARAMETER Prompt
        (Mandatory) The message to send to Azure OpenAI for generating a response.

    .PARAMETER ApiKey
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
        (Optional) Azure OpenAI API version. Default is "2024-08-01-preview".

    .EXAMPLE
        Invoke-PSUPromptOnAzureOpenAi -Prompt "Explain Azure in one sentence"

    .EXAMPLE
        Invoke-PSUPromptOnAzureOpenAi -Prompt "Return JSON with name and age" -ReturnJsonResponse

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
        [string]$ApiVersion = '2024-12-01-preview' #"2024-08-01-preview"
    )

    process {
        # Validate credentials
        if (-not $ApiKey -or -not $Endpoint -or -not $Deployment) {
            Write-Error "Azure OpenAI credentials are missing. Please check environment variables or pass parameters directly."
            Write-Host "`nTo set environment variables, use:" -ForegroundColor Yellow
            Write-Host '  Set-PSUUserEnvironmentVariable -Name "API_KEY_AZURE_OPENAI" -Value "<your-api-key>"' -ForegroundColor Cyan
            Write-Host '  Set-PSUUserEnvironmentVariable -Name "AZURE_OPENAI_ENDPOINT" -Value "<your-endpoint>"' -ForegroundColor Cyan
            Write-Host '  Set-PSUUserEnvironmentVariable -Name "AZURE_OPENAI_DEPLOYMENT" -Value "<your-deployment-name>"' -ForegroundColor Cyan
            return
        }

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
        if( -not $MaxTokens ) { $MaxTokens = Get-OptimalMaxTokens -Prompt $ModifiedPrompt -ResponseSize "Medium" }
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
            if( -not $TimeoutSeconds ) { $TimeoutSeconds = Get-OptimalTimeout -Prompt $ModifiedPrompt -MaxTokens $MaxTokens }
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
            # Enhanced error handling
            $statusCode = $null
            $errorBody = $null
            $errorMessage = $_.Exception.Message

            # Try to extract more details
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode

                try {
                    $stream = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $errorBody = $reader.ReadToEnd()
                    $reader.Close()
                    $stream.Close()
                }
                catch {
                    $errorBody = "Could not read error response"
                }
            }

            Write-Host ""
            Write-Host "Request Failed" -ForegroundColor Red

            if ($statusCode) {
                Write-Host "Status Code: $statusCode" -ForegroundColor Yellow
                $ModifiedPrompt | Out-File -FilePath "$env:TEMP\LastAzureOpenAIPrompt.txt" -Encoding UTF8 #TODO: saving for debugging purposes

                switch ($statusCode) {
                    400 {
                        Write-Host "`nError: Bad Request" -ForegroundColor Red
                        Write-Host "This usually means:" -ForegroundColor Yellow
                        Write-Host "  • Wrong API version" -ForegroundColor Cyan
                        Write-Host "  • Invalid deployment name" -ForegroundColor Cyan
                        Write-Host "  • Malformed request body" -ForegroundColor Cyan
                        Write-Host "  • Token limit exceeded" -ForegroundColor Cyan

                        if ($errorBody) {
                            Write-Host "`nDetailed Error:" -ForegroundColor Yellow
                            try {
                                $errorJson = $errorBody | ConvertFrom-Json
                                Write-Host ($errorJson | ConvertTo-Json -Depth 5) -ForegroundColor Gray
                            }
                            catch {
                                Write-Host $errorBody -ForegroundColor Gray
                            }
                        }

                        Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
                        Write-Host "  1. Verify deployment name: $Deployment" -ForegroundColor Cyan
                        Write-Host "  2. Check endpoint: $Endpoint" -ForegroundColor Cyan
                        Write-Host "  3. Try different API version: -ApiVersion '2024-06-01'" -ForegroundColor Cyan
                        Write-Host "  4. Run: Test-AzureOpenAIConnection (diagnostic function)" -ForegroundColor Cyan
                    }
                    401 {
                        Write-Host "`nError: Unauthorized" -ForegroundColor Red
                        Write-Host "  • Check your API key is correct" -ForegroundColor Cyan
                        Write-Host "  • Current key starts with: $($ApiKey.Substring(0, [Math]::Min(10, $ApiKey.Length)))..." -ForegroundColor Gray
                    }
                    404 {
                        Write-Host "`nError: Not Found" -ForegroundColor Red
                        Write-Host "  • Deployment '$Deployment' doesn't exist" -ForegroundColor Cyan
                        Write-Host "  • Check deployment name in Azure Portal" -ForegroundColor Cyan
                    }
                    429 {
                        Write-Host "`nError: Too Many Requests" -ForegroundColor Red
                        Write-Host "  • Rate limit exceeded" -ForegroundColor Cyan
                        Write-Host "  • Wait a few seconds and retry" -ForegroundColor Cyan
                    }
                    default {
                        Write-Host "`nHTTP Error: $statusCode" -ForegroundColor Red
                        if ($errorBody) {
                            Write-Host "Details: $errorBody" -ForegroundColor Gray
                        }
                    }
                }
            } else {
                Write-Host "Error Message: $errorMessage" -ForegroundColor Yellow
            }

            Write-Host "`nRequest Details:" -ForegroundColor Yellow
            Write-Host "  Endpoint: $Endpoint" -ForegroundColor Gray
            Write-Host "  Deployment: $Deployment" -ForegroundColor Gray
            Write-Host "  API Version: $ApiVersion" -ForegroundColor Gray
            Write-Host "  Full URL: $fullUrl" -ForegroundColor Gray
            Write-Host ""

            Write-Error "Azure OpenAI request failed. See details above."
            return
        }
    }
}