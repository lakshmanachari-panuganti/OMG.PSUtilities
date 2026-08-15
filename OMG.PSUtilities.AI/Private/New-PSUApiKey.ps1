function New-PSUApiKey {
    <#
    .SYNOPSIS
        Generates a secure 24-hour API key for PSU AI Proxy.

    .DESCRIPTION
        Creates a Base64-encoded API key containing:
        The key is cached in $script:PSU_API_KEY for reuse in the current session.

    .PARAMETER ExpireTimeHours
        How many hours until the key expires. Default is 24 hours.

    .PARAMETER Force
        Force regeneration even if a valid cached key exists.

    .EXAMPLE
        $apiKey = New-PSUApiKey
        # Generates and caches API key for 24 hours

    .EXAMPLE
        $apiKey = New-PSUApiKey -ExpireTimeHours 48
        # Generates key valid for 48 hours

    .EXAMPLE
        $apiKey = New-PSUApiKey -Force
        # Force regenerate even if cached key exists

    .OUTPUTS
        [String]

    .NOTES
        Author: Lakshmanachari Panuganti
        Cross-platform: Windows, Linux, macOS

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'Function is interactive and provides user feedback during key generation'
    )]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateRange(1, 8760)]
        [Alias('ExpireTime')]
        [int]$ExpireTimeHours = 24,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "=== Starting PSU API Key Generation ==="
    }

    process {
        try {
            # Check for cached key first (unless Force is specified)
            if (-not $Force -and $script:PSU_API_KEY -and $script:PSU_API_KEY_EXPIRY -and $script:PSU_API_HEADERS) {
                $now = [DateTime]::UtcNow
                if ($now -lt $script:PSU_API_KEY_EXPIRY) {
                    $timeLeft = $script:PSU_API_KEY_EXPIRY - $now
                    Write-Verbose "Using cached API key (expires in $($timeLeft.TotalHours.ToString('F1')) hours)"
                    Write-Host "✓ Using cached API key (expires in $($timeLeft.TotalHours.ToString('F1')) hours)" -ForegroundColor Green
                    return $script:PSU_API_KEY
                } else {
                    Write-Verbose "Cached API key has expired, generating new one"
                }
            }

            # ShouldProcess check
            if (-not $PSCmdlet.ShouldProcess("PSU API Key", "Generate new API key (expires in $ExpireTimeHours hours)")) {
                return
            }

            # ============================================
            # 6. Call Token Issuer Service
            # ============================================
            $tokenIssuerUrl = "https://omg-gemini.azurewebsites.net/api/issuetoken"
            $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $tokenUrl = "$tokenIssuerUrl`?t=$timestamp"

            Write-Verbose "Calling token issuer service..."
            Write-Verbose "URL: $tokenUrl"

            try {
                $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -TimeoutSec 30 -ErrorAction Stop

                $responseFields = if ($tokenResponse -is [System.Collections.IDictionary]) {
                    @($tokenResponse.Keys)
                } else {
                    @($tokenResponse.PSObject.Properties.Name)
                }
                $executableFields = @($responseFields | Where-Object {
                        $_ -match '(?i)(script|commands?)$|^executable'
                    })
                if ($executableFields.Count -gt 0) {
                    throw "Token issuer returned executable content, which is not supported."
                }

                foreach ($requiredField in 'authorization', 'clientUsername', 'clientDevice', 'clientIp', 'expiresOn') {
                    if ([string]::IsNullOrWhiteSpace([string]$tokenResponse.$requiredField)) {
                        throw "Token issuer response is missing required field '$requiredField'."
                    }
                }

                $authorization = [string]$tokenResponse.authorization
                if ($authorization -notmatch '^Bearer\s+\S+$') {
                    throw "Token issuer response field 'authorization' must contain a Bearer token."
                }

                $expiry = [DateTimeOffset]::MinValue
                if (-not [DateTimeOffset]::TryParse([string]$tokenResponse.expiresOn, [ref]$expiry) -or
                    $expiry -le [DateTimeOffset]::UtcNow) {
                    throw "Token issuer response field 'expiresOn' must be a valid future timestamp."
                }

                $apiKey = $authorization -replace '^Bearer\s+', ''
                $clientUsername = [string]$tokenResponse.clientUsername
                $clientDevice = [string]$tokenResponse.clientDevice
                $clientIP = [string]$tokenResponse.clientIp
                $headers = @{
                    Authorization        = $authorization
                    'psu-clientusername' = $clientUsername
                    'psu-clientdevice'   = $clientDevice
                    'psu-clientip'       = $clientIP
                }
                $script:PSU_API_KEY_EXPIRY = $expiry.UtcDateTime

                Write-Verbose "Token received from issuer service"
                Write-Verbose "Username: $clientUsername"
                Write-Verbose "Device: $clientDevice"
                Write-Verbose "IP: $clientIP"
            } catch {
                $errorMsg = "Failed to retrieve token from issuer service: $($_.Exception.Message)"
                throw $errorMsg
            }

            # ============================================
            # 8. Cache the key for session reuse
            # ============================================
            $script:PSU_API_KEY = $apiKey
            $script:PSU_API_KEY_USERNAME = $clientUsername
            $script:PSU_API_KEY_COMPUTER = $clientDevice
            $script:PSU_API_KEY_IP = $clientIP

            # Cache the whole header set - callers need the psu-client* headers, not just the token
            $script:PSU_API_HEADERS = $headers

            # ============================================
            # 9. Display success message
            # ============================================
            $expiryDisplay = if ($script:PSU_API_KEY_EXPIRY) {
                $script:PSU_API_KEY_EXPIRY.ToString("o")
            } else {
                "Unknown"
            }

            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║         ✓ API Key Generated Successfully               ║" -ForegroundColor Cyan
            Write-Host "╠════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
            Write-Host "║  User      : $($clientUsername.PadRight(40))  ║" -ForegroundColor White
            Write-Host "║  Computer  : $($clientDevice.PadRight(40))  ║" -ForegroundColor White
            Write-Host "║  Public IP : $($clientIP.PadRight(40))  ║" -ForegroundColor White
            Write-Host "║  Expires   : $($expiryDisplay.PadRight(40))  ║" -ForegroundColor Yellow
            Write-Host "║  Cached    : Yes (session-wide reuse enabled)          ║" -ForegroundColor Green
            Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""
            return $apiKey
        } catch {
            # Clear any partial cache on error
            $script:PSU_API_KEY = $null
            $script:PSU_API_KEY_EXPIRY = $null
            $script:PSU_API_HEADERS = $null

            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Red
            Write-Host "║         ✗ API Key Generation Failed                   ║" -ForegroundColor Red
            Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Red
            Write-Host ""

            $errorMsg = "Failed to generate PSU API key: $($_.Exception.Message)"
            Write-Error $errorMsg
            throw
        }
    }

    end {
        Write-Verbose "=== API Key Generation Complete ==="
    }
}