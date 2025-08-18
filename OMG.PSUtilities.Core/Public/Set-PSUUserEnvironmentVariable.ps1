function Set-PSUUserEnvironmentVariable {
    <#
    .SYNOPSIS
        Sets or updates a user environment variable.

    .DESCRIPTION
        Sets a user environment variable both for the current session and persistently for the user.

    .PARAMETER Name
        The name of the environment variable.

    .PARAMETER Value
        The value to set for the environment variable.

    .EXAMPLE
        Set-PSUUserEnvironmentVariable -Name 'API_KEY_OPENAI' -Value 'sk-proj-S@MpLe-Gk4NL--gFyTu305hMnQoYE6GuT3BlbkFJggn'
    
    .EXAMPLE
        Set-PSUUserEnvironmentVariable -Name 'ADO_ORGANIZATION' -Value 'OmgIT'

    .OUTPUTS
        None

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 27th June 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value
    )

    try {
        # Set at user scope (persists across sessions)
        [System.Environment]::SetEnvironmentVariable($Name, $Value, "User")

        # Set in current session
        Set-Item -Path "Env:\$Name" -Value $Value
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
