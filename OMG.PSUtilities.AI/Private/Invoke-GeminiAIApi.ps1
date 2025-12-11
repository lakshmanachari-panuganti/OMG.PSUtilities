function Invoke-GeminiAIApi {
    <#
    .SYNOPSIS
        Calls the Gemini AI Proxy API with automatic API key management.

    .DESCRIPTION
        Invokes the Gemini AI API through the Azure Function proxy.
        Automatically generates and caches API keys using New-PSUApiKey.
        Supports automatic retry on failures and API key expiration.

    .PARAMETER Prompt
        The prompt to send to Gemini AI.

    .PARAMETER ReturnJsonResponse
        Request JSON-formatted response from Gemini.

    .PARAMETER TimeoutSeconds
        HTTP request timeout in seconds. Default is 90.

    .PARAMETER RetryCount
        Number of retry attempts on failure. Default is 3.

    .PARAMETER RetryDelaySeconds
        Delay between retries in seconds. Default is 2.

    .PARAMETER ApiUrl
        The Azure Function endpoint URL.

    .PARAMETER ForceNewApiKey
        Force generation of a new API key even if cached one exists.

    .EXAMPLE
        Invoke-GeminiAIApi -Prompt "What is PowerShell?"

        Makes a request using cached or newly generated API key

    .EXAMPLE
        Invoke-GeminiAIApi -Prompt "List 3 colors" -ReturnJsonResponse

        Requests JSON response format

    .EXAMPLE
        Invoke-GeminiAIApi -Prompt "Explain REST" -ForceNewApiKey

        Forces generation of new API key before making request

    .OUTPUTS
        System.String

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 10th December 2025
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Prompt,

        [Parameter()]
        [switch]$ReturnJsonResponse,

        [Parameter()]
        [ValidateRange(10, 300)]
        [int]$TimeoutSeconds = 90,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$RetryCount = 3,

        [Parameter()]
        [ValidateRange(1, 30)]
        [int]$RetryDelaySeconds = 2,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ApiUrl = "https://omg-geminiai-proxy-func.azurewebsites.net/api/ProxyGeminiAI",

        [Parameter()]
        [switch]$ForceNewApiKey
    )

    begin {
        Write-Verbose "=== Starting Gemini AI API Call ==="
        Write-Verbose "Prompt length: $($Prompt.Length) characters"
        Write-Verbose "JSON response: $($ReturnJsonResponse.IsPresent)"
        Write-Verbose "API URL: $ApiUrl"
    }

    process {
        # ============================================
        # 1. Ensure API Key is Available
        # ============================================
        try {
            # Check if New-PSUApiKey function exists
            if (-not (Get-Command -Name New-PSUApiKey -ErrorAction SilentlyContinue)) {
                throw "Required function 'New-PSUApiKey' not found. Please ensure it is loaded in the current session."
            }

            # Check if we need a new API key
            $needNewKey = $false

            if ($ForceNewApiKey) {
                Write-Verbose "Force new API key requested"
                $needNewKey = $true
            }
            elseif (-not $script:PSU_API_KEY) {
                Write-Verbose "No cached API key found"
                $needNewKey = $true
            }
            elseif ($script:PSU_API_KEY_EXPIRY -and ([DateTime]::UtcNow -gt $script:PSU_API_KEY_EXPIRY)) {
                Write-Verbose "Cached API key has expired"
                $needNewKey = $true
            }

            # Generate new API key if needed
            if ($needNewKey) {
                Write-Host "Generating API key..." -ForegroundColor Cyan
                try {
                    $apiKey = New-PSUApiKey -ErrorAction Stop
                    Write-Verbose "API key generated and cached successfully"
                }
                catch {
                    throw "Failed to generate API key: $($_.Exception.Message)"
                }
            }
            else {
                Write-Verbose "Using cached API key"
                $apiKey = $script:PSU_API_KEY

                # Log time remaining
                if ($script:PSU_API_KEY_EXPIRY) {
                    $timeLeft = $script:PSU_API_KEY_EXPIRY - [DateTime]::UtcNow
                    Write-Verbose "API key expires in $($timeLeft.TotalHours.ToString('F1')) hours"
                }
            }
        }
        catch {
            Write-Error "API key preparation failed: $($_.Exception.Message)"
            throw
        }

        # ============================================
        # 2. Prepare Request
        # ============================================
        $body = @{
            Prompt             = $Prompt
            ReturnJsonResponse = [bool]$ReturnJsonResponse
        } | ConvertTo-Json -Depth 20

        $headers = @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type"  = "application/json"
        }

        Write-Verbose "Request prepared with Authorization header"

        # ============================================
        # 3. Retry Logic with API Key Refresh
        # ============================================
        $maxAttempts = $RetryCount
        $attempt = 0
        $apiKeyRefreshed = $false

        while ($attempt -lt $maxAttempts) {
            $attempt++

            try {
                Write-Verbose "Attempt $attempt of $maxAttempts..."

                $invokeParams = @{
                    Method      = 'Post'
                    Uri         = $ApiUrl
                    Body        = $body
                    Headers     = $headers
                    ContentType = 'application/json'
                    TimeoutSec  = $TimeoutSeconds
                    ErrorAction = 'Stop'
                }

                Write-Host "Calling Gemini AI API (attempt $attempt)..." -ForegroundColor Cyan
                $response = Invoke-RestMethod @invokeParams

                Write-Host "✓ Request succeeded on attempt $attempt" -ForegroundColor Green
                Write-Verbose "Response received successfully"

                # ============================================
                # 4. Process Response
                # ============================================

                # Check for error in response body (string responses)
                if ($response -is [string]) {
                    if ($response -like "*token limit exceeded*") {
                        Write-Error "Rate limit exceeded: $response"
                        return $null
                    }

                    if ($response -like "*expired*" -or $response -like "*unauthorized*") {
                        Write-Warning "API key issue detected in response: $response"

                        # Try refreshing API key once
                        if (-not $apiKeyRefreshed -and $attempt -lt $maxAttempts) {
                            Write-Host "Refreshing API key and retrying..." -ForegroundColor Yellow
                            $apiKey = New-PSUApiKey -Force
                            $headers["Authorization"] = "Bearer $apiKey"
                            $apiKeyRefreshed = $true
                            continue
                        }

                        throw "Authentication failed: $response"
                    }

                    # Return string response directly
                    return $response
                }

                # Check for structured response with metadata
                if ($response.PSObject.Properties['response']) {
                    # Log metadata if available
                    if ($response.metadata) {
                        $meta = $response.metadata
                        Write-Verbose "Response metadata:"
                        Write-Verbose "  Model: $($meta.model)"
                        Write-Verbose "  Duration: $($meta.durationMs)ms"
                        Write-Verbose "  Tokens: $($meta.estimatedTokens)"

                        if ($meta.quota) {
                            Write-Verbose "  Hourly quota: $($meta.quota.hourly.used)/$($meta.quota.hourly.limit)"
                            Write-Verbose "  Monthly quota: $($meta.quota.monthly.used)/$($meta.quota.monthly.limit)"
                        }

                        if ($meta.apiKey) {
                            Write-Verbose "  API key expires in: $($meta.apiKey.hoursLeft) hours"
                        }

                        # Check quota warnings
                        if ($meta.quota.hourly.remaining -lt 1000) {
                            Write-Warning "Low hourly quota remaining: $($meta.quota.hourly.remaining) tokens"
                        }

                        if ($meta.quota.monthly.remaining -lt 10000) {
                            Write-Warning "Low monthly quota remaining: $($meta.quota.monthly.remaining) tokens"
                        }
                    }

                    return $response.response
                }

                # Fallback: return entire response
                return $response
            }
            catch {
                $statusCode = $null
                $errorBody = $null

                # Extract HTTP status code and response body
                if ($_.Exception.Response) {
                    $statusCode = [int]$_.Exception.Response.StatusCode

                    try {
                        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                        $errorBody = $reader.ReadToEnd()
                        $reader.Close()

                        # Try to parse as JSON
                        try {
                            $errorJson = $errorBody | ConvertFrom-Json
                            $errorMessage = $errorJson.message ?? $errorJson.error ?? $errorBody
                        }
                        catch {
                            $errorMessage = $errorBody
                        }
                    }
                    catch {
                        $errorMessage = $_.Exception.Message
                    }
                }
                else {
                    $errorMessage = $_.Exception.Message
                }

                Write-Warning "Attempt $attempt failed: $errorMessage"
                Write-Verbose "Error details: $($_.Exception.GetType().FullName)"

                # ============================================
                # 5. Handle Specific Error Types
                # ============================================

                # 401 Unauthorized - Try refreshing API key once
                if ($statusCode -eq 401 -and -not $apiKeyRefreshed -and $attempt -lt $maxAttempts) {
                    Write-Host "Authentication failed. Refreshing API key..." -ForegroundColor Yellow

                    try {
                        $apiKey = New-PSUApiKey -Force
                        $headers["Authorization"] = "Bearer $apiKey"
                        $apiKeyRefreshed = $true
                        Write-Host "API key refreshed. Retrying..." -ForegroundColor Cyan
                        continue
                    }
                    catch {
                        Write-Error "Failed to refresh API key: $($_.Exception.Message)"
                        throw
                    }
                }

                # 429 Rate Limit - Don't retry
                if ($statusCode -eq 429) {
                    Write-Error "Rate limit exceeded: $errorMessage"
                    throw "Rate limit exceeded. Please try again later."
                }

                # 400 Bad Request - Don't retry (client error)
                if ($statusCode -eq 400) {
                    Write-Error "Bad request: $errorMessage"
                    throw "Invalid request: $errorMessage"
                }

                # Last attempt - throw error
                if ($attempt -ge $maxAttempts) {
                    $finalError = "All $maxAttempts retry attempts failed. Last error: $errorMessage"
                    Write-Error $finalError
                    throw $finalError
                }

                # Retry with delay
                Write-Host "Retrying in $RetryDelaySeconds seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }

        # Should never reach here, but just in case
        throw "Maximum retry attempts reached without success"
    }

    end {
        Write-Verbose "=== Gemini AI API Call Complete ==="
    }
}