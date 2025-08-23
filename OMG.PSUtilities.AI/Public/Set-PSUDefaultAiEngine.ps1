function Set-PSUDefaultAiEngine {
    <#
    .SYNOPSIS
        Sets the default AI Engine (e.g., OpenAi, GeminiAi, PerplexityAi) for PSU functions.

    .DESCRIPTION
        Persists the default AI Engine in user environment variables and sets it
        for the current PowerShell session. This value will be used by PSU AI-related
        functions when the -Provider parameter is not explicitly provided.

    .PARAMETER Name
        The name of the AI Engine to set (e.g., OpenAi, GeminiAi, PerplexityAi).

    .EXAMPLE
        Set-PSUDefaultAiEngine -Name 'OpenAi'

    .EXAMPLE
        Set-PSUDefaultAiEngine -Name 'GeminiAi'

    .OUTPUTS
        None

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 22nd Aug 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet("AzureOpenAi", "GeminiAi", "PerplexityAi")]
        [string]$Name
    )

    try {
        Set-PSUUserEnvironmentVariable -Name "DEFAULT_AI_ENGINE" -Value $Name
        Write-Host "Default AI Engine set to: $Name" -ForegroundColor Green
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}