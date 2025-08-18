function Test-PSUInternetConnection {
    <#
    .SYNOPSIS
        Tests general internet connectivity.

    .DESCRIPTION
        Attempts to connect to www.google.com to verify internet access.

    .EXAMPLE
        Test-PSUInternetConnection

        Tests internet connectivity to Google and returns True or False.

    .OUTPUTS
        [Boolean]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 27th June 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $null = Invoke-WebRequest www.google.com -UseBasicParsing -TimeoutSec 5
        return $true
    } catch {
        return $false
    }
}
