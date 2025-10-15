<#
.SYNOPSIS
    Formats all PowerShell files in the workspace using Invoke-Formatter.

.DESCRIPTION
    Recursively finds all .ps1 and .psm1 files in the workspace and formats them
    using PSScriptAnalyzer's Invoke-Formatter cmdlet with your custom settings.

.PARAMETER Path
    The root path to search for PowerShell files. Defaults to the workspace root.

.EXAMPLE
    .\Format-AllPowerShellFiles.ps1

.EXAMPLE
    .\Format-AllPowerShellFiles.ps1 -Path "C:\repos\OMG.PSUtilities"
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Path = "C:\repos\OMG.PSUtilities\OMG.PSUtilities.AzureDevOps\"
)

# Check if PSScriptAnalyzer is installed
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Warning "PSScriptAnalyzer module is not installed."
    Write-Host "Install it using: Install-Module -Name PSScriptAnalyzer -Scope CurrentUser"
    return
}

Import-Module PSScriptAnalyzer

# Define formatting settings based on your .vscode/settings.json
$settings = @{
    IncludeRules = @(
        'PSPlaceOpenBrace',
        'PSPlaceCloseBrace',
        'PSUseConsistentWhitespace',
        'PSUseConsistentIndentation',
        'PSAlignAssignmentStatement'
    )
    Rules = @{
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $false  # This keeps '} else {' on same line
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore = $false
        }
        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = 'space'
            IndentationSize = 4
        }
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckSeparator = $true
        }
        PSAlignAssignmentStatement = @{
            Enable = $true
            CheckHashtable = $true
        }
    }
}

# Get all PowerShell files
$files = Get-ChildItem -Path $Path -Include *.ps1, *.psm1 -Recurse -File | 
    Where-Object { $_.FullName -notmatch '\\\.git\\|\\node_modules\\|\\bin\\|\\obj\\' }

Write-Host "Found $($files.Count) PowerShell files to format" -ForegroundColor Cyan
Write-Host ""

$formatted = 0
$errors = 0

foreach ($file in $files) {
    try {
        Write-Host "Formatting: $($file.FullName)" -ForegroundColor Gray
        
        # Read the file content
        $content = Get-Content -Path $file.FullName -Raw
        
        # Format the content
        $formattedContent = Invoke-Formatter -ScriptDefinition $content -Settings $settings
        
        # Write back to file
        Set-Content -Path $file.FullName -Value $formattedContent -NoNewline
        
        $formatted++
    } catch {
        Write-Error "Failed to format $($file.FullName): $_"
        $errors++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Successfully formatted: $formatted files" -ForegroundColor Green
if ($errors -gt 0) {
    Write-Host "Errors: $errors files" -ForegroundColor Red
}
Write-Host "========================================" -ForegroundColor Cyan
