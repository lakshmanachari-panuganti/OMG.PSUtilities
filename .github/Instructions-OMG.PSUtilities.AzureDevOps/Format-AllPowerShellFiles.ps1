<#
.SYNOPSIS
    Formats all PowerShell files in the workspace using Invoke-Formatter with additional cleanup.

.DESCRIPTION
    Recursively finds all .ps1 and .psm1 files in the workspace and formats them
    using PSScriptAnalyzer's Invoke-Formatter cmdlet with custom settings.
    
    Additional post-processing includes:
    - Removes trailing whitespace from all lines
    - Limits consecutive blank lines to maximum of 2
    - Ensures files end with single newline
    - Removes trailing blank lines at end of file

.PARAMETER Path
    The root path to search for PowerShell files. Defaults to the AzureDevOps module.

.EXAMPLE
    .\Format-AllPowerShellFiles.ps1

    Formats all PowerShell files in the default path (AzureDevOps module).

.EXAMPLE
    .\Format-AllPowerShellFiles.ps1 -Path "C:\repos\OMG.PSUtilities"

    Formats all PowerShell files in the entire workspace.

.NOTES
    Formatting Rules Applied:
    - Opening braces on same line (K&R style)
    - Closing braces with else on same line: } else {
    - 4-space indentation
    - Consistent whitespace around operators
    - Aligned hashtable assignments
    - No trailing whitespace
    - Maximum 2 consecutive blank lines
    
.LINK
    https://github.com/lakshmanachari-panuganti/OMG.PSUtilities
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
        
        # Format the content using PSScriptAnalyzer
        $formattedContent = Invoke-Formatter -ScriptDefinition $content -Settings $settings
        
        # Post-processing: Clean up the formatted content
        # 1. Remove trailing whitespace from each line
        $lines = $formattedContent -split "`r?`n"
        $cleanedLines = $lines | ForEach-Object { $_.TrimEnd() }
        
        # 2. Remove excessive blank lines (more than 2 consecutive blank lines)
        $result = @()
        $blankLineCount = 0
        
        foreach ($line in $cleanedLines) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                $blankLineCount++
                # Allow maximum 2 consecutive blank lines
                if ($blankLineCount -le 2) {
                    $result += $line
                }
            } else {
                $blankLineCount = 0
                $result += $line
            }
        }
        
        # 3. Ensure file ends with single newline (no trailing blank lines)
        while ($result.Count -gt 0 -and [string]::IsNullOrWhiteSpace($result[-1])) {
            $result = $result[0..($result.Count - 2)]
        }
        
        # Join lines back together
        $finalContent = $result -join "`r`n"
        
        # Write back to file with newline at end
        Set-Content -Path $file.FullName -Value $finalContent -NoNewline
        Add-Content -Path $file.FullName -Value "`r`n" -NoNewline
        
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
Write-Host ""
Write-Host "Formatting applied:" -ForegroundColor Yellow
Write-Host "  ✓ K&R brace style (opening brace on same line)" -ForegroundColor Gray
Write-Host "  ✓ } else { on same line" -ForegroundColor Gray
Write-Host "  ✓ 4-space indentation" -ForegroundColor Gray
Write-Host "  ✓ Trailing whitespace removed" -ForegroundColor Gray
Write-Host "  ✓ Excessive blank lines removed (max 2)" -ForegroundColor Gray
Write-Host "  ✓ Files end with single newline" -ForegroundColor Gray
