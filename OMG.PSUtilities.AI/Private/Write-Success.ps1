function Write-Success {
    <#
    .SYNOPSIS
        Displays a success message in green color.

    .DESCRIPTION
        Helper function for displaying success messages during Azure OpenAI setup.
        Outputs messages in green color to indicate successful operations.

    .PARAMETER Message
        (Mandatory) The success message to display.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 7th October 2025
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'Console UX: colorized success messages for interactive user guidance'
    )]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    process {
        Write-ColorOutput "$Message" -Color Green
    }
}
