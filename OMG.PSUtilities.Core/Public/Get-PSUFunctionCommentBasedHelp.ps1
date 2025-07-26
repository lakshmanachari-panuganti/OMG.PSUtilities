function Get-PSUFunctionCommentBasedHelp {
    <#
    .SYNOPSIS
        This function pulls out a specific help section (like .SYNOPSIS or .EXAMPLE) from a PowerShell script, useful for reading documentation automatically.

    .DESCRIPTION
        This function extracts a specific section of comment-based help (like .SYNOPSIS, .DESCRIPTION, .EXAMPLE, or .NOTES) from a given PowerShell function file. 
        It's useful when you want to programmatically access structured documentation data from a script.

    .PARAMETER FunctionPath
        Full path to the PowerShell function file (usually from the Public folder). The function validates the path.

    .PARAMETER HelpType
        The section of comment-based help you want to extract. Supports:
        .SYNOPSIS, .DESCRIPTION, .EXAMPLE, .NOTES

    .EXAMPLE
        Get-PSUFunctionCommentBasedHelp -FunctionPath "C:\repos\OMG.PSUtilities.Core\Public\Get-PSUGitRepositoryChanges.ps1" -HelpType SYNOPSIS

    .NOTES
        Author: Lakshmanachari Panuganti
        Date  : 2025-07-16
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FunctionPath,

        [Parameter(Mandatory)]
        [ValidateSet('SYNOPSIS', 'DESCRIPTION', 'EXAMPLE', 'NOTES', 'PARAMETER', 'EXAMPLE')] # Added PARAMETER to ValidateSet for completeness
        [string]$HelpType
    )

    try {
        $content = Get-Content $FunctionPath -Raw

        # This regex matches the entire comment-based help block <# ... #>
        $helpPattern = '<#(.*?)#>'
        $match = [regex]::Match($content, $helpPattern, 'Singleline')

        if (-not $match.Success) {
            Write-Warning "No comment-based help block found in $FunctionPath"
            return $null
        }

        $helpBlock = $match.Groups[1].Value

        # Build section pattern using a positive lookahead to stop before the next section
        # (?mi) = Multiline and IgnoreCase options
        # ^\s*\.$HelpType\s* = Matches the start of the specific help section (e.g., ".SYNOPSIS")
        # (.*?) = Non-greedy capture of the section content
        # (?=\s*^\.\w+|$) = Positive lookahead for (whitespace, then start of line, then '.KEYWORD') OR (end of string)
        $sectionPattern = "(?mi)^\s*\.$HelpType\s*(.*?)(?=\s*^\.\w+|$)"
        $sectionMatch = [regex]::Match($helpBlock, $sectionPattern) # Regex options are now in the pattern itself

        if ($sectionMatch.Success) {
            return $sectionMatch.Groups[1].Value.Trim()
        }
        else {
            Write-Warning "Section '.$HelpType' not found in $FunctionPath"
            return $null
        }
    }
    catch {
        Write-Error "Error reading file $FunctionPath : $_"
        return $null # Ensure null is returned on error
    }
}