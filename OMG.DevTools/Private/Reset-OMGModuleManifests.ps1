function Reset-OMGModuleManifests {
    <#
    .SYNOPSIS
        Updates a PowerShell module's manifest and module files by exporting all public functions.

    .DESCRIPTION
        This function automates the regeneration of a PowerShell module's `.psm1` and `.psd1` files by:
        - Loading all public/private functions from the module's directory
        - Rewriting the `.psm1` file to dot-source all functions and export only public ones
        - Updating or inserting the `FunctionsToExport` entry in the `.psd1` manifest with all public function names

        Useful during module development to keep manifest and exports in sync with actual function files.
        Environment Variable: BASE_MODULE_PATH must be set

    .PARAMETER ModuleName
        The name of the module folder (inside `$env:BASE_MODULE_PATH`) to process.
        The folder should contain a `Public` directory and optionally a `Private` directory with `.ps1` function files.

    .INPUTS
        System.String

    .OUTPUTS
        None

    .EXAMPLE
        Reset-OMGModuleManifests.ps1 -ModuleName 'OMG.PSUtilities.ActiveDirectory'

        Updates the manifest and module files for the specified module.

    .EXAMPLE
        @(
            [pscustomobject]@{ ModuleName = 'OMG.PSUtilities.ActiveDirectory' }
            [pscustomobject]@{ ModuleName = 'OMG.PSUtilities.Azure' }
        ) | Reset-OMGModuleManifests.ps1

        Uses pipeline input to update multiple module manifests.

    .NOTES
        Author   : Lakshmanachari Panuganti
        Created  : 2025-07-17
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory, 
            Position = 0, 
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [string]$ModuleName
    )

    Write-Host "Resetting psd1 & psm1 for: $ModuleName" -ForegroundColor Cyan

    # Checking $env:BASE_MODULE_PATH existance
    if (-not (Test-Path $env:BASE_MODULE_PATH)) {
        throw "Environment variable BASE_MODULE_PATH is not set."
    }

    $modulePath = Join-Path $env:BASE_MODULE_PATH $ModuleName
    $publicPath = Join-Path $modulePath "Public"
    $psm1Path = Join-Path $modulePath "$ModuleName.psm1"
    $psd1Path = Join-Path $modulePath "$ModuleName.psd1"

    if (-not (Test-Path $modulePath)) {
        throw "Module path not found: $modulePath"
    }

    if (-not (Test-Path $psm1Path)) {
        throw "Path not found: $psm1Path"
    }

    if (-not (Test-Path $psd1Path)) {
        throw "Path not found: $psd1Path"
    }
    
    # --------- [Reset .psd1 content] --------------
    $existingPsd1content = (Get-Content -Path $psd1Path -Raw -ErrorAction SilentlyContinue).trim()
    $functionsList = Get-ChildItem -Path $publicPath -Filter *.ps1 -Recurse | Where-Object { $_.name -notlike "*--wip.ps1" } |
    Select-Object -ExpandProperty BaseName | Sort-Object -Unique


    # Collect aliases (from defined functions)
    $aliasList = @()
    Get-ChildItem -Path $publicPath -Filter *.ps1 -Recurse | Where-Object { $_.name -notlike "*--wip.ps1" } | ForEach-Object {
        $content = $null
        try {
            $content = Get-Content $_.FullName -Raw -ErrorAction Stop
            
            if ($content) {
                $aliasMatches = [regex]::Matches($content, '\[Alias\((.*?)\)\]', 'IgnoreCase')

                foreach ($match in $aliasMatches) {
                    $raw = $match.Groups[1].Value
                    $cleaned = $raw -replace '[\'']', '' -split '\s*,\s*' -replace '"', '' 
                    $aliasList += $cleaned
                }
            }
        }
        catch {
            Write-Warning "[Reset-OMGModuleManifests] Failed to read file: $($_.FullName)"
        }
    }

    $aliasList = $aliasList | Sort-Object -Unique

    # Convert into quoted array strings (multi-line)
    $functionsString = $functionsList | ConvertTo-QuotedArrayString
    $aliasesString = $aliasList     | ConvertTo-QuotedArrayString

    # Read manifest content
    $psd1content = Get-Content $psd1Path -Raw

    # Replace FunctionsToExport block
    $psd1content = [regex]::Replace(
        $psd1content,
        "(?s)(FunctionsToExport\s*=\s*)\@\((.*?)\)",
        "`$1$functionsString"
    )

    # Replace AliasesToExport block
    $psd1content = [regex]::Replace(
        $psd1content,
        "(?s)(AliasesToExport\s*=\s*)\@\((.*?)\)",
        "`$1$aliasesString"
    )

    # Normalize line endings and trim for accurate comparison
    $normExistingPsd1 = ($existingPsd1content -replace "`r`n|`r|`n", "`n").Trim()
    $normNewPsd1 = ($psd1content -replace "`r`n|`r|`n", "`n").Trim()

    if ($normNewPsd1 -eq $normExistingPsd1) {
        Write-Host "No changes detected in: $ModuleName.psd1" -ForegroundColor Yellow
    } else {
        $psd1content.Trim() | Set-Content -Path $psd1Path -Encoding UTF8
        Write-Host "UPDATED: $ModuleName.psd1" -ForegroundColor Green
    }

    # --------- [Reset .psm1 content] --------------
    $existingPsm1content = (Get-Content -Path $psm1Path -Raw -ErrorAction SilentlyContinue).Trim()

    $publicFunctionsBlock = @($functionsList | ForEach-Object { "    '$_'," })
    if ($publicFunctionsBlock.Count -gt 0) {
        $publicFunctionsBlock[-1] = $publicFunctionsBlock[-1].TrimEnd(',')
    }
    $publicFunctionsBlock = $publicFunctionsBlock -join "`n"

    $aliasesBlock = @($aliasList | ForEach-Object { "    '$_'," })
    if ($aliasesBlock.Count -gt 0) {
        $aliasesBlock[-1] = $aliasesBlock[-1].TrimEnd(',')
    }
    $aliasesBlock = $aliasesBlock -join "`n"

    $psm1Content = @"
# Load private functions
Get-ChildItem -Path "`$PSScriptRoot\Private\*.ps1" -Recurse | Where-Object{`$_.name -notlike "*--wip.ps1"} | ForEach-Object {
    try {
        . `$(`$_.FullName)
    } catch {
        Write-Error "Failed to load private function `$(`$_.FullName): `$(`$_)"
    }
}

# Load public functions
Get-ChildItem -Path "`$PSScriptRoot\Public\*.ps1" -Recurse | Where-Object{`$_.name -notlike "*--wip.ps1"} | ForEach-Object {
    try {
        . `$(`$_.FullName)
    } catch {
        Write-Error "Failed to load public function `$(`$_.FullName): `$(`$_)"
    }
}

# Export public functions
`$PublicFunctions = @(
$publicFunctionsBlock
)

`$AliasesToExport = @(
$aliasesBlock
)

Export-ModuleMember -Function `$PublicFunctions -Alias `$AliasesToExport
"@

    # Normalize line endings and trim for accurate comparison
    $normExistingpsm1 = ($existingPsm1content -replace "`r`n|`r|`n", "`n").Trim()
    $normNewpsm1 = ($psm1Content -replace "`r`n|`r|`n", "`n").Trim()

    if ($normExistingpsm1 -eq $normNewpsm1) {
        Write-Host "No changes detected in: $ModuleName.psm1" -ForegroundColor Yellow
    } else {
        $psm1Content.Trim() | Set-Content -Path $psm1Path -Encoding UTF8
        Write-Host "UPDATED: $ModuleName.psm1" -ForegroundColor Green
    }
}
