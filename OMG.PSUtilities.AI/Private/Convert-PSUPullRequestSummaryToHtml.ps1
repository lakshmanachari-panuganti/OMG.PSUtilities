function Convert-PSUPullRequestSummaryToHtml {
    <#
    .SYNOPSIS
    Converts a pull request title and markdown-based description into a styled HTML summary file.

    .DESCRIPTION
    This function takes a pull request title and a markdown-formatted description, converts the description into HTML,
    and generates a visually styled HTML file. The output supports light/dark mode toggling in the browser and includes
    formatting for readability. Optionally, the HTML can be opened automatically in the default browser.

    .PARAMETER Title
    The title of the pull request to be displayed in the generated HTML summary.

    .PARAMETER Description
    The markdown-formatted body of the pull request. This content will be converted into HTML and styled accordingly.

    .PARAMETER OutputPath
    The file path where the HTML summary should be saved. Defaults to "$env:TEMP\PullRequestSummary.html".

    .PARAMETER OpenInBrowser
    If specified, the generated HTML file will automatically open in the default web browser after creation.

    .OUTPUTS
    [string] - Returns the path of the generated HTML file.

    .EXAMPLE
    Convert-PSUPullRequestSummaryToHtml -Title "Add new login feature" -Description "# Summary`nImplemented login flow using OAuth." -OpenInBrowser

    This example generates an HTML file for the given pull request title and markdown description and opens it in the browser.

    .EXAMPLE
    $htmlPath = Convert-PSUPullRequestSummaryToHtml -Title "Fix bug #1024" -Description (Get-Content PR.md -Raw)

    This example reads a markdown file from disk and generates the HTML summary file, storing the path in `$htmlPath`.

    .NOTES
    Author  : Lakshmanachari Panuganti
    Created : 2025-07-30
    Dependencies: Relies on `Convert-PSUMarkdownToHtml` for markdown to HTML conversion.
    Output includes a button to toggle between light and dark mode in modern browsers.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    param (
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter()]
        [string]$OutputPath = "$env:TEMP\PullRequestSummary.html",

        [Parameter()]
        [switch]$OpenInBrowser
    )

    $descriptionHtml = Convert-PSUMarkdownToHtml -Markdown $Description

    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>Pull Request Summary</title>
    <style>
        :root {
            --bg-light: #ffffff;
            --text-light: #000000;
            --border-light: #ccc;
            --bg-dark: #1e1e1e;
            --text-dark: #d4d4d4;
            --border-dark: #555;
            --font-family: Calibri, sans-serif;
            --font-size: 10.5pt;
        }

        body {
            background-color: var(--bg-light);
            color: var(--text-light);
            font-family: var(--font-family);
            font-size: var(--font-size);
            padding: 40px;
            transition: all 0.3s ease;
        }

        .dark-mode {
            background-color: var(--bg-dark);
            color: var(--text-dark);
        }

        .title-box {
            border: 1px solid var(--border-light);
            padding: 15px;
            font-size: 1.3em;
            font-weight: bold;
            background-color: #f9f9f9;
            border-radius: 8px;
        }

        .dark-mode .title-box {
            border: 1px solid var(--border-dark);
            background-color: #2d2d2d;
        }

        .description-box {
            border: 1px solid var(--border-light);
            padding: 20px;
            margin-top: 20px;
            background-color: #fafafa;
            border-radius: 8px;
        }

        .dark-mode .description-box {
            border: 1px solid var(--border-dark);
            background-color: #2a2a2a;
        }

        button {
            position: fixed;
            top: 10px;
            right: 20px;
            padding: 6px 14px;
            background-color: #0078d4;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }

        button:hover {
            background-color: #005fa1;
        }

        pre {
            background: #eee;
            padding: 10px;
            border-radius: 4px;
            overflow-x: auto;
        }

        .dark-mode pre {
            background: #333;
        }
    </style>
</head>
<body>
    <button onclick="toggleMode()">Toggle Light/Dark</button>

    <div class="title-box">$Title</div>
    <div class="description-box">
        $descriptionHtml
    </div>

    <script>
        function toggleMode() {
            document.body.classList.toggle("dark-mode");
        }
    </script>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "HTML preview saved to: $OutputPath" -ForegroundColor Green

    if ($OpenInBrowser) {
        Start-Process "msedge.exe" $OutputPath
    }

    return $OutputPath
}
