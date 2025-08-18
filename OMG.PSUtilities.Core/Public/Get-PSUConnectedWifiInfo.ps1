function Get-PSUConnectedWifiInfo {
    <#
    .SYNOPSIS
        Gets details of the currently connected Wi-Fi network.

    .DESCRIPTION
        Returns connection details for the currently connected Wi-Fi:
        SSID, Signal Strength, Private IP, Band, Transmit/Receive Rate, and Public IP.
        This function uses the Windows netsh command to gather network information.

    .EXAMPLE
        Get-PSUConnectedWifiInfo
        Gets details of the currently connected Wi-Fi network.

    .NOTES
        Author: Lakshmanachari Panuganti
        Created: 2025-07-03

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
        https://learn.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-contexts
    #>

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    [Alias('Get-WifiInfo')]
    param()
    if (-not (Get-Command netsh -ErrorAction SilentlyContinue)) {
        Write-Warning "The 'netsh' command is not available. This function is supported only on Windows."
        return
    }

    $netshOutput = netsh wlan show interfaces 2>$null
    if (-not $netshOutput) {
        Write-Verbose "No Wi-Fi interfaces found."
        return
    }

    # Get the connected block
    $connectedBlock = $netshOutput | Select-String '^\s*State\s*:\s*connected' -Context 0, 20 | ForEach-Object {
        $start = $_.LineNumber - 1
        $netshOutput[$start..([Math]::Min($start + 20, $netshOutput.Count - 1))]
    }

    if (-not $connectedBlock) {
        Write-Verbose "No connected Wi-Fi network detected."
        return
    }

    # Initialize property container
    $props = @{
        SSID               = ''
        Signal             = ''
        PrivateIPv4Address = ''
        Band               = ''
        PublicIPAddress    = ''
    }

    foreach ($line in $connectedBlock) {
        if ($line -match '^\s*SSID\s*:\s*(.+)$') { $props.SSID = $Matches[1].Trim() }
        elseif ($line -match '^\s*Signal\s*:\s*(.+)$') { $props.Signal = $Matches[1].Trim() }
        elseif ($line -match '^\s*Band\s*:\s*(.+)$') { $props.Band = $Matches[1].Trim() }
    }

    # Match interface via alias or description
    $ipconfig = Get-NetIPConfiguration | Where-Object {$_.NetProfile.Name -eq $props.SSID}

    if ($ipconfig -and $ipconfig.IPv4Address) {
        $props.PrivateIPv4Address = $ipconfig.IPv4Address.IPAddress
    }

    # Fetch public IP
    try {
        $props.PublicIPAddress = Invoke-RestMethod -Uri 'https://api.ipify.org'
    }
    catch {
        Write-Verbose "Failed to retrieve public IP address."
        $props.PublicIPAddress = 'Unavailable'
    }

    [pscustomobject]@{
        SSID               = $props.SSID
        PrivateIPv4Address = $props.PrivateIPv4Address
        PublicIPAddress    = $props.PublicIPAddress
        Signal             = $props.Signal
        Band               = $props.Band
    }
}
