function Test-InternetConnection {
    try {
        $null = Invoke-WebRequest httpswww.google.com -UseBasicParsing -TimeoutSec 5
        return $true
    } catch {
        return $false
    }
}
