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

    $missingVars = @()
    switch ($Name) {
        "AzureOpenAi" {
            if (-not $env:API_KEY_AZURE_OPENAI) { $missingVars += "API_KEY_AZURE_OPENAI" }
            if (-not $env:AZURE_OPENAI_ENDPOINT) { $missingVars += "AZURE_OPENAI_ENDPOINT" }
            if (-not $env:AZURE_OPENAI_DEPLOYMENT) { $missingVars += "AZURE_OPENAI_DEPLOYMENT" }
        }
        "GeminiAi" {
            if (-not $env:API_KEY_GEMINI) { $missingVars += "API_KEY_GEMINI" }
        }
        "PerplexityAi" {
            if (-not $env:API_KEY_PERPLEXITY) { $missingVars += "API_KEY_PERPLEXITY" }
        }
    }

    if ($missingVars.Count -gt 0) {
        Write-Warning "The following required environment variables are missing for $Name`:"
        $missingVars | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
        Write-Host "Please set them using Set-PSUUserEnvironmentVariable before proceeding." -ForegroundColor Cyan
        foreach ($var in $missingVars) {
            Write-Host "Set-PSUUserEnvironmentVariable -Name '$var' -Value '<your-value>'" -ForegroundColor Magenta
        }
        return
    }

    try {
        Set-PSUUserEnvironmentVariable -Name "DEFAULT_AI_ENGINE" -Value $Name
        Write-Host "Default AI Engine set to: $Name" -ForegroundColor Green
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}