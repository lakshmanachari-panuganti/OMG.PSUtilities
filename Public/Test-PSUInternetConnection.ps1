function Test-PSUInternetConnection {
    try {
        $null = Invoke-WebRequest www.google.com -UseBasicParsing -TimeoutSec 5
        return $true
    } catch {
        return $false
    }
}
