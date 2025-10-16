function Write-ErrorMsg {
    <#
    .SYNOPSIS
        Displays an error message in red color.

    .DESCRIPTION
        Helper function for displaying error messages during Azure OpenAI setup.
        Outputs messages in red color to indicate errors or failures.

    .PARAMETER Message
        (Mandatory) The error message to display.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 7th October 2025
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'Console UX: colorized error messages for interactive user guidance'
    )]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    process {
        Write-ColorOutput "$Message" -Color Red
    }
}
