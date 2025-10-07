function Write-Step {
    <#
    .SYNOPSIS
        Displays a step header message in cyan color.

    .DESCRIPTION
        Helper function for displaying step headers during Azure OpenAI setup.
        Outputs messages in cyan color with a step indicator prefix.

    .PARAMETER Message
        (Mandatory) The step message to display.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 7th October 2025
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'Console UX: colorized step headers for interactive user guidance'
    )]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    process {
        Write-ColorOutput "`n==> $Message" -Color Cyan
    }
}
