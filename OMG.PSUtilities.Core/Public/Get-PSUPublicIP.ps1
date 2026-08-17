function Get-PSUPublicIP {
    <#
    .SYNOPSIS
        Retrieves the public IP address of the current machine.

    .DESCRIPTION
        Attempts to determine public IP using multiple methods with caching:
        1. DNS lookup via OpenDNS (fastest)
        2. HTTP requests to several endpoints in turn, taking the first valid answer
        Results are cached for 5 minutes to improve performance.

    .PARAMETER TimeoutSec
        Timeout in seconds for each HTTP request. Default is 3 seconds. The HTTP fallback
        tries endpoints one at a time, so a total outage of all four can take up to four
        times this value before the command reports failure.

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

    .OUTPUTS
        [System.String]

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

    # 2️⃣ Fallback: try HTTP endpoints in order and take the first valid answer.
    # Sequential on purpose. The parallel version used Start-ThreadJob, which Windows
    # PowerShell 5.1 does not ship, so on 5.1 this fallback raised CommandNotFoundException
    # instead of returning an address. Declaring ThreadJob in the manifest would have pushed
    # that dependency onto every module that requires Core, for a path that only runs when
    # the DNS lookup above has already failed.
    Write-Verbose "DNS failed, trying HTTP endpoints..."

    $endpoints = @(
        'https://checkip.amazonaws.com'
        'https://api.ipify.org'
        'https://icanhazip.com'
        'https://ifconfig.me/ip'
    )

    $ip = $null
    foreach ($endpoint in $endpoints) {
        try {
            Write-Verbose "Querying $endpoint ..."
            $response = Invoke-RestMethod -Uri $endpoint -TimeoutSec $TimeoutSec -ErrorAction Stop
            $candidate = ([string]$response).Trim()

            if ($candidate -match '^\d{1,3}(\.\d{1,3}){3}$') {
                $ip = $candidate
                Write-Verbose "Received valid IP from ${endpoint}: $ip"
                break
            }

            Write-Verbose "Endpoint $endpoint returned no usable address."
        }
        catch {
            Write-Verbose "Endpoint $endpoint failed: $($_.Exception.Message)"
        }
    }

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