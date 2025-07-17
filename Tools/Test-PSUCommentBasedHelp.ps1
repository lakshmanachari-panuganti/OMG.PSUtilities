function Test-PSUCommentBasedHelp {
    param (
        [Parameter(Mandatory)]
        [string]$ModulePath # = "C:\repos\OMG.PSUtilities"
    )

    $requiredTags = @('.SYNOPSIS', '.DESCRIPTION', '.EXAMPLE', '.NOTES')
    $results = @()

    $ps1Files = Get-ChildItem -Path $ModulePath -Recurse -Filter *.ps1 |
        Where-Object { $_.FullName -like "*\Public\*" }

    foreach ($file in $ps1Files) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction Stop

            if (-not $content -or $content.Trim().Length -eq 0) {
                $results += [pscustomobject]@{
                    File         = $file.FullName
                    HasHelpBlock = $false
                    MissingTags  = 'File is empty or unreadable'
                }
                continue
            }

            #TODO : Synopsis length check - if it is more than 100 characters, then warn

            $pattern = '<#(.*?)#>'
            $match = [regex]::Match($content, $pattern, 'Singleline')

            if ($match.Success) {
                $helpBlock = $match.Groups[1].Value
                $missingTags = @()

                foreach ($tag in $requiredTags) {
                    if ($helpBlock -notmatch [regex]::Escape($tag)) {
                        $missingTags += $tag
                    }
                }

                $results += [pscustomobject]@{
                    File         = $file.FullName
                    HasHelpBlock = $true
                    MissingTags  = if ($missingTags.Count -eq 0) { 'NothingMissed' } else { $missingTags -join ', ' }
                }
            }
            else {
                $results += [pscustomobject]@{
                    File         = $file.FullName
                    HasHelpBlock = $false
                    MissingTags  = 'All (No comment block found)'
                }
            }
        }
        catch {
            $results += [pscustomobject]@{
                File         = $file.FullName
                HasHelpBlock = $false
                MissingTags  = "Error: $_"
            }
        }
    }

    return $results | Sort-Object HasHelpBlock, MissingTags
}
