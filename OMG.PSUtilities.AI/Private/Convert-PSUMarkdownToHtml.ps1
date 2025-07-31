function Convert-PSUMarkdownToHtml {
    <#
    .SYNOPSIS
    Converts a Markdown string to HTML using available tools.

    .DESCRIPTION
    This function attempts to convert a given Markdown string to HTML format.
    It first tries to use the built-in `ConvertFrom-Markdown` cmdlet (available in newer PowerShell versions).
    If that fails or is not available, it falls back to using the `Markdig` .NET library (downloaded from NuGet if not already available).

    .PARAMETER Markdown
    The raw Markdown content to convert into HTML.

    .OUTPUTS
    [string]

    .EXAMPLE
$markdown = @"
## Hello World

This is a *markdown* to **HTML** test.
"@
    $html = Convert-PSUMarkdownToHtml -Markdown $markdown

    .EXAMPLE
    Get-Content README.md -Raw | Convert-PSUMarkdownToHtml

    .NOTES
    Author  : Lakshmanachari Panuganti
    Created : 2025-07-30
    Dependencies: PowerShell 7+ for `ConvertFrom-Markdown`, or fallback to Markdig.dll
    NuGet: Downloads `Markdig` package from NuGet.org if fallback path is triggered.
    #>

    param ([string]$Markdown)

    # Try ConvertFrom-Markdown first
    if (Get-Command ConvertFrom-Markdown -ErrorAction SilentlyContinue) {
        try {
            return ($Markdown | ConvertFrom-Markdown).Html
        }
        catch {
            Write-Warning "ConvertFrom-Markdown failed. Falling back to Markdig..."
        }
    }

    # Fallback to Markdig.dll
    $markdigDll = "$env:TEMP\markdig\lib\netstandard2.0\Markdig.dll"
    if (-not (Test-Path $markdigDll)) {
        Write-Verbose "Downloading Markdig..."
        $nugetUrl = "https://www.nuget.org/api/v2/package/Markdig"
        $nupkgPath = "$env:TEMP\markdig.nupkg"
        $extractPath = "$env:TEMP\markdig"
        Invoke-WebRequest -Uri $nugetUrl -OutFile $nupkgPath -UseBasicParsing
        [System.IO.Compression.ZipFile]::ExtractToDirectory($nupkgPath, $extractPath)
    }

    Add-Type -Path $markdigDll -ErrorAction SilentlyContinue
    return [Markdig.Markdown]::ToHtml($Markdown)
}
