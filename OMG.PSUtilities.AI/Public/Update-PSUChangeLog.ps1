function Update-PSUChangeLog {
    <#
    .SYNOPSIS
        Uses Gemini AI to generate and append a professional changelog entry for major module updates.
    .DESCRIPTION
        Scans for major changes (new functions, bug fixes, etc.) in a module, summarizes them with Gemini AI, and appends the result to CHANGELOG.md.
    .PARAMETER ModuleName
        The name of the module to update (e.g., OMG.PSUtilities.AI).
    .PARAMETER RootPath
        The root path where modules are located. Defaults to $env:BASE_MODULE_PATH.
    .PARAMETER ApiKey
        (Optional) Gemini API key. Defaults to $env:API_KEY_GEMINI.
    .EXAMPLE
        Update-PSUChangeLog -ModuleName OMG.PSUtilities.AI
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [string]$RootPath = $env:BASE_MODULE_PATH,
        [string]$ApiKey = $env:API_KEY_GEMINI
    )
    $moduleRoot = Join-Path $RootPath $ModuleName
    $changelogPath = Join-Path $moduleRoot 'CHANGELOG.md'
    if (-not (Test-Path $changelogPath)) {
        Write-Error "CHANGELOG.md not found for $ModuleName."
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
    $date = (Get-Date -Format 'yyyy-MM-dd')
    $entry = "## [$date]`n$aiSummary`n"
    Add-Content -Path $changelogPath -Value $entry
    Write-Host "CHANGELOG.md updated for $ModuleName." -ForegroundColor Green
}
