function Get-PSUPublicIP {
    <#
    .SYNOPSIS
        Retrieves the public IP address of the current machine.

    .DESCRIPTION
        Attempts to determine public IP using multiple methods with caching:
        1. DNS lookup via OpenDNS (fastest)
        2. Parallel HTTP requests to multiple endpoints
        Results are cached for 5 minutes to improve performance.

    .PARAMETER TimeoutSec
        Timeout in seconds for HTTP requests. Default is 3 seconds.

    .PARAMETER NoCache
        Skip cache and force fresh lookup.

    .PARAMETER CacheMinutes
        How long to cache the IP address. Default is 5 minutes.

    .EXAMPLE
        Get-PSUPublicIP
        # Returns: 203.0.113.42

    .EXAMPLE
        Get-PSUPublicIP -NoCache -TimeoutSec 5
        # Forces fresh lookup with 5 second timeout

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 11 December 2025
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateRange(1, 30)]
        [int]$TimeoutSec = 3,

        [Parameter()]
        [switch]$NoCache,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$CacheMinutes = 5
    )

    # Return cached IP if available and not expired
    if (-not $NoCache -and
        $script:CachedPublicIP -and
        $script:CachedIPExpiry -and
        (Get-Date) -lt $script:CachedIPExpiry) {
        Write-Verbose "Using cached public IP: $script:CachedPublicIP (expires: $script:CachedIPExpiry)"
        return $script:CachedPublicIP
    }

    try {
        Write-Verbose "Attempting DNS lookup via OpenDNS..."
        $dnsResult = Resolve-DnsName -Name myip.opendns.com -Server resolver1.opendns.com -ErrorAction Stop -DnsOnly
        $ip = $dnsResult.Where({ $_.Type -eq "A" }, 'First').IPAddress

        if ($ip -match '^\d{1,3}(\.\d{1,3}){3}$') {
            $script:CachedPublicIP = $ip
            $script:CachedIPExpiry = (Get-Date).AddMinutes($CacheMinutes)
            Write-Verbose "Public IP retrieved via DNS: $ip (cached until $script:CachedIPExpiry)"
            return $ip
        }
    }
    catch {
        Write-Verbose "DNS lookup failed: $($_.Exception.Message)"
    }

    # 2️⃣ Fallback: Try multiple HTTP endpoints in parallel
    Write-Verbose "DNS failed, trying HTTP endpoints in parallel..."

    $endpoints = @(
        'https://checkip.amazonaws.com'
        'https://api.ipify.org'
        'https://icanhazip.com'
        'https://ifconfig.me/ip'
    )

    $jobs = foreach ( $endpoint in $endpoints ) {
        Start-ThreadJob -ScriptBlock {
            param($url, $timeout)
            try {
                $response = Invoke-RestMethod -Uri $url -TimeoutSec $timeout -ErrorAction Stop
                return $response.Trim()
            }
            catch {
                return $null
            }
        } -ArgumentList $endpoint, $TimeoutSec
    }

    # Wait for first successful response
    $ip = $null
    $waitTime = 0
    $maxWait = $TimeoutSec * 1000  # Convert to milliseconds
    $checkInterval = 100  # Check every 100ms

    while ($waitTime -lt $maxWait -and -not $ip) {
        Start-Sleep -Milliseconds $checkInterval
        $waitTime += $checkInterval

        foreach ($job in $jobs) {
            if ($job.State -eq 'Completed') {
                $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                if ($result -match '^\d{1,3}(\.\d{1,3}){3}$') {
                    $ip = $result
                    Write-Verbose "Received valid IP from endpoint: $ip"
                    break
                }
            }
        }
    }

    # Cleanup all jobs
    $jobs | Stop-Job -PassThru | Remove-Job -Force

    if ($ip) {
        $script:CachedPublicIP = $ip
        $script:CachedIPExpiry = (Get-Date).AddMinutes($CacheMinutes)
        Write-Verbose "Public IP retrieved via HTTP: $ip (cached until $script:CachedIPExpiry)"
        return $ip
    }

    # All methods failed
    $errorMsg = "Unable to determine public IP address after trying DNS and $($endpoints.Count) HTTP endpoints"
    Write-Error $errorMsg
    throw $errorMsg
}