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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Function is interactive and provides real-time user feedback')]
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
        [string]$ApiUrl = "https://omg-gemini.azurewebsites.net/api/proxy",

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
                    $script:PSU_API_KEY = New-PSUApiKey -ErrorAction Stop
                    Write-Verbose "API key generated and cached successfully"
                }
                catch {
                    throw "Failed to generate API key: $($_.Exception.Message)"
                }
            }
            else {
                Write-Verbose "Using cached API key"

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

        # Validate required headers are present
        if (-not $headers['psu-clientusername'] -or -not $headers['psu-clientdevice'] -or -not $headers['psu-clientip']) {
            throw "Missing required authentication metadata. Ensure New-PSUApiKey has been called successfully."
        }

        Write-Verbose "Request prepared with Authorization and custom headers"
        Write-Verbose "Username: $($headers['psu-clientusername'])"
        Write-Verbose "Device: $($headers['psu-clientdevice'])"
        Write-Verbose "IP: $($headers['psu-clientip'])"

        # ============================================
        # 3. Retry Logic with API Key Refresh
        # ============================================
        $maxAttempts = $RetryCount
        $attempt = 0

        while ($attempt -lt $maxAttempts) {
            $attempt++

            try {
                Write-Verbose "Attempt $attempt of $maxAttempts..."

                $invokeParams = @{
                    Method      = 'Post'
                    Uri         = $ApiUrl
                    Body        = $body
                    Headers     = $headers
                    TimeoutSec  = $TimeoutSeconds
                    ErrorAction = 'Stop'
                }

                Write-Verbose "Calling Gemini AI API (attempt $attempt)..."
                $response = Invoke-RestMethod @invokeParams

                Write-Verbose "Response received successfully"
                return $response
            }
            catch {
                $errorMessage = $_.Exception.Message
                $statusCode = 0

                # Extract status code if available
                if ($_.Exception.Response) {
                    $statusCode = $_.Exception.Response.StatusCode.value__
                }

                # Try to parse error details from response body
                $errorDetails = $null
                if ($_.ErrorDetails.Message) {
                    try {
                        $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction Stop

                        Write-Verbose "Error details received from API:"
                        Write-Verbose ($errorDetails | ConvertTo-Json -Depth 5)

                        # Handle specific error types
                        if ($errorDetails.error -eq "Rate Limit Exceeded") {
                            $resetTime = if ($errorDetails.quota.resetTime) { $errorDetails.quota.resetTime } else { "unknown" }
                            $fullMessage = "Rate limit exceeded: $($errorDetails.message). Reset in: $resetTime"
                            Write-Error $fullMessage
                            throw $fullMessage
                        }

                        if ($statusCode -eq 401) {
                            $fullMessage = "Authentication failed: $($errorDetails.message)"
                            if ($errorDetails.correlationId) {
                                $fullMessage += " (CorrelationID: $($errorDetails.correlationId))"
                            }
                            Write-Error $fullMessage
                            throw $fullMessage
                        }

                        if ($statusCode -eq 400) {
                            $fullMessage = "Bad request: $($errorDetails.message)"
                            if ($errorDetails.correlationId) {
                                $fullMessage += " (CorrelationID: $($errorDetails.correlationId))"
                            }
                            Write-Error $fullMessage
                            throw $fullMessage
                        }

                        # Generic error with details - use the actual message from response
                        $errorMessage = $errorDetails.message
                        if ($errorDetails.correlationId) {
                            $errorMessage += " (CorrelationID: $($errorDetails.correlationId))"
                        }

                        # For verbose output, show full error object
                        Write-Verbose "Parsed error message: $errorMessage"
                    }
                    catch {
                        Write-Verbose "Could not parse error details as JSON: $($_.Exception.Message)"
                        Write-Verbose "Raw error body: $($_.ErrorDetails.Message)"
                    }
                }

                # Last attempt - throw error with full details
                if ($attempt -ge $maxAttempts) {
                    $finalError = "All $maxAttempts retry attempts failed. Last error: $errorMessage"

                    # If we have error details, show them
                    if ($errorDetails) {
                        Write-Host "`nError Details:" -ForegroundColor Red
                        Write-Host "  Error: $($errorDetails.error)" -ForegroundColor Yellow
                        Write-Host "  Message: $($errorDetails.message)" -ForegroundColor Yellow
                        if ($errorDetails.correlationId) {
                            Write-Host "  CorrelationID: $($errorDetails.correlationId)" -ForegroundColor Yellow
                        }
                    }

                    Write-Error $finalError
                    throw $finalError
                }

                # Retry with delay (unless it's an auth error or rate limit)
                if ($statusCode -eq 401 -or ($errorDetails -and $errorDetails.error -eq "Rate Limit Exceeded")) {
                    throw $errorMessage
                }

                Write-Warning "Attempt $attempt failed (status: $statusCode): $errorMessage"
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }

        # Should never reach here if retry logic works correctly
        Write-Warning "Retry loop completed without success or failure"
    }

    end {
        Write-Verbose "=== Gemini AI API Call Complete ==="
    }
}