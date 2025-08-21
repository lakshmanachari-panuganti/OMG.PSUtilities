function Update-PSUReadMe {
    <#
    .SYNOPSIS
        Uses Gemini AI to generate and update the README.md with a summary of recent major changes.
    .DESCRIPTION
        Summarizes recent major changes (new functions, bug fixes, etc.) using Gemini AI and updates the module's README.md with version, last updated, and a human-friendly summary.
    .PARAMETER ModuleName
        The name of the module to update (e.g., OMG.PSUtilities.AI).
    .PARAMETER RootPath
        The root path where modules are located. Defaults to $env:BASE_MODULE_PATH.
    .PARAMETER ApiKey
        (Optional) Gemini API key. Defaults to $env:API_KEY_GEMINI.
    .EXAMPLE
        Update-PSUReadMe -ModuleName OMG.PSUtilities.AI
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [string]$RootPath = $env:BASE_MODULE_PATH,
        [string]$ApiKey = $env:API_KEY_GEMINI
    )
    $moduleRoot = Join-Path $RootPath $ModuleName
    $readmePath = Join-Path $moduleRoot 'README.md'
    if (-not (Test-Path $readmePath)) {
        Write-Error "README.md not found for $ModuleName."
        return
    }
    $changeSummaries = Get-PSUAiPoweredGitChangeSummary -ApiKeyGemini $ApiKey
    if (-not $changeSummaries) {
        Write-Host "No major changes detected for $ModuleName."
        return
    }
    $aiSummary = ($changeSummaries | ForEach-Object {
        "- [$($_.TypeOfChange)] $($_.File): $($_.Summary)"
    }) -join "`n"
    $version = (Select-String -Path (Join-Path $moduleRoot "$ModuleName.psd1") -Pattern 'ModuleVersion\s*=\s*"([^"]+)"').Matches.Groups[1].Value
    $metaLine = "> Module version: $version | Last updated: $(Get-OrdinalDate)"
    $readmeLines = Get-Content $readmePath | Where-Object { $_ -notmatch '^> Module version:' }
    $readmeLines += ""
    $readmeLines += $metaLine
    $readmeLines += "### 🚀 Recent Major Updates"
    $readmeLines += $aiSummary
    Set-Content -Path $readmePath -Value $readmeLines
    Write-Host "README.md updated for $ModuleName." -ForegroundColor Green
}
