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

.PARAMETER ModuleName
    The name of the module folder (inside `$env:BASE_MODULE_PATH`) to process.
    The folder should contain a `Public` directory and optionally a `Private` directory with `.ps1` function files.

.INPUTS
    System.String
    Accepts the `ModuleName` property from pipeline input objects.

.OUTPUTS
    None. Writes output and warnings to the console.

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
    Requires : PowerShell 5.1+ or PowerShell Core
    Environment Variable: BASE_MODULE_PATH must be set
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName)]
        [string]$ModuleName
    )

    process {
        $modulePath = Join-Path $env:BASE_MODULE_PATH $ModuleName

        if (-not (Test-Path $modulePath)) {
            Write-Warning "[Reset-OMGModuleManifests] Module path not found: $modulePath"
            return
        }
        Write-Verbose "Processing module: $ModuleName at $modulePath"
        $publicPath = Join-Path $modulePath "Public"
        $psm1Path = Join-Path $modulePath "$ModuleName.psm1"
        $psd1Path = Join-Path $modulePath "$ModuleName.psd1"

        if (-not (Test-Path $publicPath)) {
            Write-Warning "[Reset-OMGModuleManifests] Missing Public folder in $ModuleName"
            return
        }

        # Get all public function names
        $publicFunctions = Get-ChildItem -Path $publicPath -Filter *.ps1 -Recurse | Where-Object{$_.name -notlike "*--wip.ps1"} |
        Select-Object -ExpandProperty BaseName

        if (-not $publicFunctions) {
            Write-Warning "[Reset-OMGModuleManifests] No functions found in $publicPath"
            return
        }

        # --- Extract aliases from each public function -----
        $aliasList = @()
        Get-ChildItem -Path $publicPath -Filter *.ps1 -Recurse | Where-Object{$_.name -notlike "*--wip.ps1"} | ForEach-Object {
            $content = $null
            try{
            $content = Get-Content $_.FullName -Raw -ErrorAction Stop
            
            if($content){
                $aliasMatches = [regex]::Matches($content, '\[Alias\((.*?)\)\]', 'IgnoreCase')

                foreach ($match in $aliasMatches) {
                    $raw = $match.Groups[1].Value
                    $cleaned = $raw -replace '[\'']', '' -split '\s*,\s*' -replace '"','' 
                    $aliasList += $cleaned
                }
            }
            } catch{
                Write-Warning "[Reset-OMGModuleManifests] Failed to read file: $($_.FullName)"
            }
        }


        # --------- [Generate .psm1 content] --------------
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
$(@($publicFunctions | ForEach-Object { "    '$_'" }) -join "`n")
)

`$AliasesToExport = @(
$(@($aliasList | ForEach-Object { "    '$_'" }) -join "`n")
)

Export-ModuleMember -Function `$PublicFunctions -Alias `$AliasesToExport
"@

        $psm1Content | Set-Content -Path $psm1Path -Encoding UTF8
        Write-Host "UPDATED: $ModuleName.psm1" -ForegroundColor Green

        # ------------------- [Patch .psd1 → FunctionsToExport] --------------------
        # --- Patch .psd1
        if (Test-Path $psd1Path) {
            $psd1 = Get-Content $psd1Path

            $functionsLine = "FunctionsToExport = @(" + (
                $publicFunctions | ForEach-Object { "'$_'" } | Join-String -Separator ", "
            ) + ")"

            $aliasesLine = "AliasesToExport = @(" + (
                $aliasList | ForEach-Object { "'$_'" } | Join-String -Separator ", "
            ) + ")"


            if ($psd1 -match 'FunctionsToExport\s*=\s*@\([^\)]*\)') {
                $psd1 = $psd1 -replace 'FunctionsToExport\s*=\s*@\([^\)]*\)', $functionsLine
            }
            else {
                $psd1 += "`n$functionsLine"
            }

            if ($psd1 -match 'AliasesToExport\s*=\s*@\([^\)]*\)') {
                $psd1 = $psd1 -replace 'AliasesToExport\s*=\s*@\([^\)]*\)', $aliasesLine
            }
            else {
                $psd1 += "`n$aliasesLine"
            }
            
            $psd1 | Set-Content -Path $psd1Path -Encoding UTF8
            Write-Host "PATCHED: $ModuleName.psd1" -ForegroundColor Green
        }
        else {
            Write-Warning "[Reset-OMGModuleManifests] $ModuleName.psd1 not found"
        }
    }
}
