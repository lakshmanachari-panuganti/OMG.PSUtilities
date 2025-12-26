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
    [CmdletBinding()]
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
            if (-not $Force -and $script:PSU_API_KEY -and $script:PSU_API_KEY_EXPIRY) {
                $now = [DateTime]::UtcNow
                if ($now -lt $script:PSU_API_KEY_EXPIRY) {
                    $timeLeft = $script:PSU_API_KEY_EXPIRY - $now
                    Write-Verbose "Using cached API key (expires in $($timeLeft.TotalHours.ToString('F1')) hours)"
                    Write-Host "✓ Using cached API key (expires in $($timeLeft.TotalHours.ToString('F1')) hours)" -ForegroundColor Green
                    return $script:PSU_API_KEY
                }
                else {
                    Write-Verbose "Cached API key has expired, generating new one"
                }
            }

            # ============================================
            # 6. Call Token Issuer Service
            # ============================================
            $tokenIssuerUrl = "https://omgissuetoken.azurewebsites.net/api/IssueToken-Dev"
            $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $tokenUrl = "$tokenIssuerUrl`?t=$timestamp"

            Write-Verbose "Calling token issuer service..."
            Write-Verbose "URL: $tokenUrl"

            try {
                $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -TimeoutSec 30 -ErrorAction Stop

                if (-not $tokenResponse.HeaderScript) {
                    throw "Token issuer did not return HeaderScript"
                }

                # Execute the header script to set local variables
                Write-Verbose "Executing header script from token issuer..."
                Invoke-Expression $tokenResponse.HeaderScript

                # Extract the authorization token from $Headers (set by HeaderScript)
                if (-not $Headers -or -not $Headers['Authorization']) {
                    throw "HeaderScript did not set Authorization header"
                }

                $apiKey = $Headers['Authorization'] -replace '^Bearer\s+', ''
                $clientUsername = $Headers['psu-clientusername']
                $clientDevice = $Headers['psu-clientdevice']
                $clientIP = $Headers['psu-clientip']

                Write-Verbose "Token received from issuer service"
                Write-Verbose "Username: $clientUsername"
                Write-Verbose "Device: $clientDevice"
                Write-Verbose "IP: $clientIP"
            }
            catch {
                $errorMsg = "Failed to retrieve token from issuer service: $($_.Exception.Message)"
                throw $errorMsg
            }

            # ============================================
            # 7. Parse expiry from token (if possible)
            # ============================================
            try {
                # Token format: IP|xx|startISO|xx|endISO|xx|signature (Base64 encoded)
                $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($apiKey))
                $parts = $decoded -split '\|xx\|'

                if ($parts.Count -ge 3) {
                    $expiryISO = $parts[2]
                    $expiryDate = [DateTimeOffset]::Parse($expiryISO)
                    $script:PSU_API_KEY_EXPIRY = $expiryDate.UtcDateTime
                    Write-Verbose "Token expires: $expiryISO"
                }
                else {
                    # Default to requested expiry time
                    $script:PSU_API_KEY_EXPIRY = [DateTime]::UtcNow.AddHours($ExpireTimeHours)
                    Write-Verbose "Using default expiry: $ExpireTimeHours hours from now"
                }
            }
            catch {
                # If parsing fails, use default expiry
                $script:PSU_API_KEY_EXPIRY = [DateTime]::UtcNow.AddHours($ExpireTimeHours)
                Write-Verbose "Token parsing failed, using default expiry"
            }

            # ============================================
            # 8. Cache the key for session reuse
            # ============================================
            $script:PSU_API_KEY = $apiKey
            $script:PSU_API_KEY_USERNAME = $clientUsername
            $script:PSU_API_KEY_COMPUTER = $clientDevice
            $script:PSU_API_KEY_IP = $clientIP

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
            Write-Verbose "API key length: $($apiKey.Length) characters"

            return $apiKey
        }
        catch {
            # Clear any partial cache on error
            $script:PSU_API_KEY = $null
            $script:PSU_API_KEY_EXPIRY = $null

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