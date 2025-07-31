function Convert-PSUPullRequestSummaryToHtml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Description,

        [string]$OutputPath = "$env:TEMP\PullRequestSummary.html",

        [switch]$OpenInBrowser
    )

    # Ensure Markdig is available
    $markdigDll = "$env:TEMP\markdig\lib\netstandard2.0\Markdig.dll"
    if (-not (Test-Path $markdigDll)) {
        Write-Verbose "Downloading Markdig..."
        $nugetUrl = "https://www.nuget.org/api/v2/package/Markdig"
        $nupkgPath = "$env:TEMP\markdig.nupkg"
        $extractPath = "$env:TEMP\markdig"

        Invoke-WebRequest -Uri $nugetUrl -OutFile $nupkgPath -UseBasicParsing
        [System.IO.Compression.ZipFile]::ExtractToDirectory($nupkgPath, $extractPath)
    }

    Add-Type -Path $markdigDll

    # Convert Markdown description to HTML
    $htmlDescription = [Markdig.Markdown]::ToHtml($Description)

    # Build HTML content
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>PR Summary Preview</title>
    <style>
        body {
            font-family: Segoe UI, Arial, sans-serif;
            margin: 40px;
            background-color: #f8f9fa;
        }
        .card {
            background: #fff;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.05);
            padding: 20px 30px;
            margin-bottom: 20px;
        }
        .pr-title {
            font-size: 24px;
            font-weight: 600;
            margin: 0;
            color: #24292e;
        }
        .pr-description {
            font-size: 15px;
            color: #333;
        }
        h1, h2, h3 { color: #2c3e50; }
        pre {
            background: #f4f4f4;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
        }
        code {
            background: #f4f4f4;
            padding: 2px 4px;
            border-radius: 4px;
            font-family: Consolas, monospace;
        }
        ul { margin-left: 20px; }
    </style>
</head>
<body>

<div class="card">
    <div class="pr-title">$Title</div>
</div>

<div class="card pr-description">
    $htmlDescription
</div>

</body>
</html>
"@

    # Write HTML file
    $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "✅ PR preview HTML saved to: $OutputPath"

    if ($OpenInBrowser) {
        $edgePath = "msedge.exe"
        if (Get-Command $edgePath -ErrorAction SilentlyContinue) {
            Start-Process $edgePath $OutputPath
        } else {
            Write-Warning "Edge not found. Opening in default browser."
            Start-Process $OutputPath
        }
    }

    return $OutputPath
}
