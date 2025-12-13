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

        $Body = @{
            Prompt = 'say Jai sreeram'
            ReturnJsonResponse = $false
        } | ConvertTo-Json

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
                    Body        = $Body
                    Headers     = $headers
                    #TimeoutSec  = $TimeoutSeconds
                    ErrorAction = 'Stop'
                }

                Write-Host "Calling Gemini AI API (attempt $attempt)..." -ForegroundColor Cyan
                $response = Invoke-RestMethod @invokeParams

                Write-Verbose "Response received successfully"
            }
            catch {
                $errorMessage = $_
                $errorMessageObj = $_ | ConvertFrom-json
                if ($errorMessageObj.Error -like "Bad Request") {
                    Write-Error "Invalid request: $errorMessage"
                    return
                }

                if ($errorMessageObj.Error -like "Rate Limit Exceeded") {
                    Write-Error "Invalid request: $errorMessage"
                    return
                }

                # Last attempt - throw error
                if ($attempt -ge $maxAttempts) {
                    $finalError = "All $maxAttempts retry attempts failed. Last error: $errorMessage"
                    Write-Error $finalError
                    throw $finalError
                }

                # Retry with delay
                Write-Warning "Attempt $attempt failed: $errorMessage"
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