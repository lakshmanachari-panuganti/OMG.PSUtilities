function Write-ColorOutput {
    <#
    .SYNOPSIS
        Outputs a message with specified color to the console.

    .DESCRIPTION
        Helper function for displaying colorized console output.
        Used by Azure OpenAI setup functions for user-facing messages.

    .PARAMETER Message
        (Mandatory) The message to display.

    .PARAMETER Color
        (Optional) The foreground color for the message. Default is 'White'.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 7th October 2025
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'Console UX: colorized output for interactive user guidance'
    )]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string]$Color = "White"
    )

    process {
        Write-Host $Message -ForegroundColor $Color
    }
}
