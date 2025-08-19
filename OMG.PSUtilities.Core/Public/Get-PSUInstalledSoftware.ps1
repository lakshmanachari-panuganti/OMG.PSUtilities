function Get-PSUInstalledSoftware {
    <#
    .SYNOPSIS
        Lists installed software on the system.

    .DESCRIPTION
        Retrieves a list of installed applications from both 32-bit and 64-bit registry paths.
        Optionally filters results by software name or publisher.

    .PARAMETER Name
        Filter the results by display name (supports wildcards, e.g., '*Chrome*').

    .PARAMETER Publisher
        Filter the results by publisher (supports wildcards, e.g., '*Microsoft*').

    .EXAMPLE
        Get-PSUInstalledSoftware -Name '*Chrome*'

    .EXAMPLE
        Get-PSUInstalledSoftware -Publisher '*Microsoft*'

    .OUTPUTS
        [PSCustomObject]
        Properties include: Name, Version, Publisher, InstallDate, UninstallString

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 3rd July 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [parameter()]
        [string]$Name,

        [parameter()]
        [string]$Publisher
    )

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $results = foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, UninstallString
    }

    if ($Name) {
        $results = $results | Where-Object { $_.DisplayName -like $Name }
    }

    if ($Publisher) {
        $results = $results | Where-Object { $_.Publisher -like $Publisher }
    }

    $results | Sort-Object DisplayName -Unique
}
