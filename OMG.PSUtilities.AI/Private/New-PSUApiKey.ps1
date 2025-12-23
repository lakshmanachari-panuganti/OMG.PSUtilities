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
            # 1. Get Username (REQUIRED - NO FALLBACK)
            # ============================================
            Write-Verbose "Retrieving username..."
            $username = $null

            # Try environment variables first (cross-platform)
            $username = $env:USERNAME  # Windows
            if (-not $username) {
                $username = $env:USER  # Linux/macOS
            }

            # Try .NET method (Windows)
            if (-not $username) {
                try {
                    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                    if ($identity -and $identity.Name) {
                        $username = $identity.Name.Split('\')[-1]  # Get username part only
                    }
                }
                catch {
                    Write-Verbose "WindowsIdentity method failed: $($_.Exception.Message)"
                }
            }

            # Try whoami command (Linux/macOS fallback)
            if (-not $username) {
                try {
                    $username = (whoami 2>$null)
                    if ($username) {
                        $username = $username.Split('\')[-1].Trim()
                    }
                }
                catch {
                    Write-Verbose "whoami command failed: $($_.Exception.Message)"
                }
            }

            # Try id command (Linux/macOS alternative)
            if (-not $username) {
                try {
                    $idOutput = (id -un 2>$null)
                    if ($idOutput) {
                        $username = $idOutput.Trim()
                    }
                }
                catch {
                    Write-Verbose "id command failed: $($_.Exception.Message)"
                }
            }

            # Validate username
            if ([string]::IsNullOrWhiteSpace($username)) {
                throw "CRITICAL: Unable to determine username. This is required for API key generation."
            }

            Write-Verbose "Username: $username"

            # ============================================
            # 2. Get Computer Name (REQUIRED - NO FALLBACK)
            # ============================================
            Write-Verbose "Retrieving computer name..."
            $computer = $null

            # Try environment variables
            $computer = $env:COMPUTERNAME  # Windows
            if (-not $computer) {
                $computer = $env:HOSTNAME  # Linux/macOS
            }

            # Try .NET DNS method
            if (-not $computer) {
                try {
                    $computer = [System.Net.Dns]::GetHostName()
                }
                catch {
                    Write-Verbose "DNS GetHostName failed: $($_.Exception.Message)"
                }
            }

            # Try hostname command (cross-platform)
            if (-not $computer) {
                try {
                    $computer = (hostname 2>$null)
                    if ($computer) {
                        $computer = $computer.Trim()
                    }
                }
                catch {
                    Write-Verbose "hostname command failed: $($_.Exception.Message)"
                }
            }

            # Try uname command (Linux/macOS)
            if (-not $computer) {
                try {
                    $computer = (uname -n 2>$null)
                    if ($computer) {
                        $computer = $computer.Trim()
                    }
                }
                catch {
                    Write-Verbose "uname command failed: $($_.Exception.Message)"
                }
            }

            # Validate computer name
            if ([string]::IsNullOrWhiteSpace($computer)) {
                throw "CRITICAL: Unable to determine computer name. This is required for API key generation."
            }

            Write-Verbose "Computer name: $computer"

            # ============================================
            # 3. Get Public IP (REQUIRED - NO FALLBACK)
            # ============================================
            Write-Verbose "Retrieving public IP address..."

            # Check if Get-PublicIP function exists
            if (-not (Get-Command -Name Get-PublicIP -ErrorAction SilentlyContinue)) {
                throw "CRITICAL: Get-PublicIP function not found. Please ensure it is loaded in the current session."
            }

            try {
                $publicIP = Get-PublicIP -TimeoutSec 5 -ErrorAction Stop

                # Validate IP format
                if ([string]::IsNullOrWhiteSpace($publicIP) -or $publicIP -eq "0.0.0.0") {
                    throw "Invalid public IP address returned: $publicIP"
                }

                # Validate IP format with regex
                if ($publicIP -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
                    throw "Invalid IP address format: $publicIP"
                }

                # Validate octets are in valid range (0-255)
                $octets = $publicIP -split '\.'
                foreach ($octet in $octets) {
                    if ([int]$octet -gt 255) {
                        throw "Invalid IP address (octet > 255): $publicIP"
                    }
                }

                Write-Verbose "Public IP: $publicIP"
            }
            catch {
                $errorMsg = "CRITICAL: Failed to retrieve public IP address. This is required for API key generation.`n"
                $errorMsg += "Error: $($_.Exception.Message)`n"
                $errorMsg += "Ensure you have internet connectivity and the Get-PublicIP function is working correctly."
                throw $errorMsg
            }

            # ============================================
            # 4. Get Timestamps
            # ============================================
            $utcNow = [DateTime]::UtcNow
            $createdAt = $utcNow.ToString("o")
            $expiresAt = $utcNow.AddHours($ExpireTimeHours).ToString("o")
            Write-Verbose "Created: $createdAt"
            Write-Verbose "Expires: $expiresAt"

            # ============================================
            # 5. Get Hardware Serial Number (OPTIONAL - CAN FALLBACK)
            # ============================================
            Write-Verbose "Retrieving hardware serial number..."
            $serialNumber = "Unknown"

            # Windows: Try CIM/WMI
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                try {
                    # Try baseboard serial first
                    $baseboard = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop
                    $serialNumber = $baseboard.SerialNumber

                    # If empty, try system UUID
                    if ([string]::IsNullOrWhiteSpace($serialNumber) -or $serialNumber -match '^(None|To be filled)') {
                        $cs = Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction Stop
                        $serialNumber = $cs.UUID
                    }

                    # If still empty, try BIOS serial
                    if ([string]::IsNullOrWhiteSpace($serialNumber) -or $serialNumber -match '^(None|To be filled)') {
                        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
                        $serialNumber = $bios.SerialNumber
                    }

                    Write-Verbose "Windows serial number: $serialNumber"
                }
                catch {
                    Write-Verbose "Windows CIM query failed: $($_.Exception.Message)"
                }
            }

            # Linux: Try DMI
            if (($IsLinux -or $serialNumber -eq "Unknown") -and (Test-Path "/sys/class/dmi/id/product_uuid" -ErrorAction SilentlyContinue)) {
                try {
                    $uuid = Get-Content "/sys/class/dmi/id/product_uuid" -ErrorAction Stop
                    if ($uuid -and $uuid -ne "Unknown") {
                        $serialNumber = $uuid.Trim()
                        Write-Verbose "Linux DMI UUID: $serialNumber"
                    }
                }
                catch {
                    Write-Verbose "Linux DMI read failed: $($_.Exception.Message)"
                }
            }

            # macOS: Try system_profiler
            if (($IsMacOS -or $serialNumber -eq "Unknown") -and (Get-Command "system_profiler" -ErrorAction SilentlyContinue)) {
                try {
                    $hwInfo = system_profiler SPHardwareDataType 2>$null | Select-String "Serial Number"
                    if ($hwInfo) {
                        $serial = ($hwInfo.ToString() -replace '.*:\s*', '').Trim()
                        if ($serial) {
                            $serialNumber = $serial
                            Write-Verbose "macOS serial number: $serialNumber"
                        }
                    }
                }
                catch {
                    Write-Verbose "macOS system_profiler failed: $($_.Exception.Message)"
                }
            }

            # Final fallback is acceptable for serial number
            if ([string]::IsNullOrWhiteSpace($serialNumber)) {
                $serialNumber = "Unknown"
            }

            Write-Verbose "Hardware serial: $serialNumber"

            # ============================================
            # 6. Build API Key String
            # ============================================
            # Format: username|computer|publicIP|createdAt|expiresAt|serialNumber
            $parts = @(
                $username,
                $computer,
                $publicIP,
                $createdAt,
                $expiresAt,
                $serialNumber,
                (New-Guid).Guid
            )

            $combined = $parts -join '|'
            Write-Verbose "Key components: $combined"

            # ============================================
            # 7. Encode to Base64
            # ============================================
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($combined)
            $encoded = [Convert]::ToBase64String($bytes)

            # ============================================
            # 8. Cache the key for session reuse
            # ============================================
            $script:PSU_API_KEY = $encoded
            $script:PSU_API_KEY_EXPIRY = $utcNow.AddHours($ExpireTimeHours)
            $script:PSU_API_KEY_USERNAME = $username
            $script:PSU_API_KEY_COMPUTER = $computer
            $script:PSU_API_KEY_IP = $publicIP

            # ============================================
            # 9. Display success message
            # ============================================
            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║         ✓ API Key Generated Successfully              ║" -ForegroundColor Cyan
            Write-Host "╠════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
            Write-Host "║  User      : $($username.PadRight(40)) ║" -ForegroundColor White
            Write-Host "║  Computer  : $($computer.PadRight(40)) ║" -ForegroundColor White
            Write-Host "║  Public IP : $($publicIP.PadRight(40)) ║" -ForegroundColor White
            Write-Host "║  Hardware  : $($serialNumber.Substring(0, [Math]::Min(40, $serialNumber.Length)).PadRight(40)) ║" -ForegroundColor Gray
            Write-Host "║  Expires   : $($expiresAt.PadRight(40)) ║" -ForegroundColor Yellow
            Write-Host "║  Cached    : Yes (session-wide reuse enabled)         ║" -ForegroundColor Green
            Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""
            Write-Verbose "API key length: $($encoded.Length) characters"

            return $encoded
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