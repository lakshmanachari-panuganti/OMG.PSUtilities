function Write-Info {
    <#
    .SYNOPSIS
        Displays an informational message in yellow color.

    .DESCRIPTION
        Helper function for displaying informational messages during Azure OpenAI setup.
        Outputs messages in yellow color to indicate important information or warnings.

    .PARAMETER Message
        (Mandatory) The informational message to display.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 7th October 2025
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'Console UX: colorized info messages for interactive user guidance'
    )]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    process {
        Write-ColorOutput "$Message" -Color Yellow
    }
}
