function Find-PSUFilesContainingText {
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
            Write-Warning "⚠️ No *.$FileExtension files found containing '$SearchText' in '$SearchPath'."
        } else {
            Write-Warning "⚠️ No files found containing '$SearchText' in '$SearchPath'."
        }
    }
}