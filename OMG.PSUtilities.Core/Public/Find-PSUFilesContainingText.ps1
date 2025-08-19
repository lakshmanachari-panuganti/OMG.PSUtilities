
function Find-PSUFilesContainingText {
    <#
    .SYNOPSIS
        Searches files for a specific text string.

    .DESCRIPTION
        Recursively or non-recursively searches files in a directory for a given text string, with options to filter by extension and exclude certain file types.

    .PARAMETER SearchPath
        (Mandatory) Directory to search. Must be a valid existing directory path.

    .PARAMETER SearchText
        (Mandatory) Text to search for in files.

    .PARAMETER FileExtension
        (Optional) Only search files with this specific extension.

    .PARAMETER ExcludeExtensions
        (Optional) Array of file extensions to exclude from search.
        Default value is @('exe','dll','msi','bin','jpg','png','zip','iso','img','sys').

    .PARAMETER NoRecurse
        (Optional) Switch parameter to search only the top-level directory without recursion.

    .EXAMPLE
        Find-PSUFilesContainingText -SearchPath 'C:\Projects' -SearchText 'TODO'

    .OUTPUTS
        [PSCustomObject]
        Properties include: FileName, LineNumber, LineContent, FullPath

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 27th June 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
        https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/select-string

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({
            if (-Not (Test-Path -Path $_)) {
                throw "Directory path '$_' does not exist."
            }
            return $true
        })]
        [string]$SearchPath,

        [Parameter(Mandatory)]
        [string]$SearchText,

        [Parameter()]
        [string]$FileExtension,

        [Parameter()]
        [string[]]$ExcludeExtensions = @('exe','dll','msi','bin','jpg','png','zip','iso','img','sys'),

        [Parameter()]
        [switch]$NoRecurse
    )

    if ($FileExtension) {
        Write-Verbose "Searching for '*.$FileExtension' files in '$SearchPath' containing text: '$SearchText'..."
        $filter = "*.$FileExtension"
    } else {
        Write-Verbose "Searching all files in '$SearchPath' containing text: '$SearchText'..."
        $filter = "*"
    }

    if ($NoRecurse) {
        Write-Verbose "Recursion disabled. Searching only in the top-level directory."
        $files = Get-ChildItem -Path $SearchPath -File -Filter $filter -ErrorAction SilentlyContinue
    } else {
        Write-Verbose "Recursively searching subdirectories..."
        $files = Get-ChildItem -Path $SearchPath -Recurse -File -Filter $filter -ErrorAction SilentlyContinue
    }

    # Exclude files with specified extensions
    $files = $files | Where-Object {
        $ext = $_.Extension.TrimStart('.').ToLower()
        -not ($ExcludeExtensions -contains $ext)
    }

    $matchedFiles = foreach ($file in $files) {
        if (Select-String -Path $file.FullName -Pattern $SearchText -Quiet) {
            $file.FullName
        }
    }

    if ($matchedFiles) {
        $matchedFiles
    } else {
        if ($FileExtension) {
            Write-Warning "No *.$FileExtension files found containing '$SearchText' in '$SearchPath'."
        } else {
            Write-Warning "No files found containing '$SearchText' in '$SearchPath'."
        }
    }
}