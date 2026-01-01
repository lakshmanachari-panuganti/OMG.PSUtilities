function Invoke-OMGBuildModule {
    <#
    .SYNOPSIS
        Builds all OMG modules locally.

    .DESCRIPTION
        Builds each OMG module independently with optional script analysis.
        This function is self-contained and does not depend on other build functions.

        The build process includes:
        - Running PSScriptAnalyzer (unless skipped)
        - Scanning Public folder for functions and aliases
        - Updating .psd1 manifest with FunctionsToExport and AliasesToExport
        - Regenerating .psm1 module loader
        - Removing old module from session
        - Importing updated module

    .PARAMETER ModuleName
        Specific module name(s) to build. If not specified, builds all modules.
        Accepts short names (AI, Core) or full names (OMG.PSUtilities.AI).

    .PARAMETER UseScriptAnalyzer
        Run PSScriptAnalyzer validation during build.

    .PARAMETER SkipUpdateManifests
        Skip updating the module manifest files (.psd1 and .psm1).

    .PARAMETER WhatIf
        Shows what would be built without making changes.

    .EXAMPLE
        Invoke-OMGBuildModule
        Builds all OMG modules.

    .EXAMPLE
        Invoke-OMGBuildModule -ModuleName "OMG.PSUtilities.Core" -UseScriptAnalyzer
        Builds a specific module with script analysis enabled.

    .EXAMPLE
        Invoke-OMGBuildModule -ModuleName "AI", "Core"
        Builds multiple modules using short names.

    .OUTPUTS
        [PSCustomObject] Build results with Success and Failed arrays.

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 2025-12-30
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [Alias('omgbuild')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [ValidateSet('AI', 'AzureCore', 'AzureDevOps', 'Core', 'ServiceNow', 'VSphere', 'ActiveDirectory')]
        [string[]]$ModuleName,

        [Parameter()]
        [switch]$UseScriptAnalyzer,

        [Parameter()]
        [switch]$SkipUpdateManifests
    )

    begin {
        # Display parameters
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Parameters:"
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            Write-Verbose "  $($param.Key) = $($param.Value)"
        }

        # Validate BASE_MODULE_PATH
        if (-not $env:BASE_MODULE_PATH) {
            throw "Environment variable BASE_MODULE_PATH is not set. Use: Set-PSUUserEnvironmentVariable -Name 'BASE_MODULE_PATH' -Value '<path>'"
        }

        if (-not (Test-Path $env:BASE_MODULE_PATH)) {
            throw "BASE_MODULE_PATH does not exist: $env:BASE_MODULE_PATH"
        }

        Write-Host "`n=== OMG Module Builder ===" -ForegroundColor Cyan

        $buildResults = @{
            Success = @()
            Failed  = @()
        }

        # Map short names to full module names
        $moduleMap = @{
            'AI'             = 'OMG.PSUtilities.AI'
            'AzureCore'      = 'OMG.PSUtilities.AzureCore'
            'AzureDevOps'    = 'OMG.PSUtilities.AzureDevOps'
            'Core'           = 'OMG.PSUtilities.Core'
            'ServiceNow'     = 'OMG.PSUtilities.ServiceNow'
            'VSphere'        = 'OMG.PSUtilities.VSphere'
            'ActiveDirectory' = 'OMG.PSUtilities.ActiveDirectory'
        }
    }

    process {
        # Get modules to build
        if ($ModuleName) {
            $modulesToBuild = $ModuleName | ForEach-Object {
                if ($moduleMap.ContainsKey($_)) {
                    $moduleMap[$_]
                } else {
                    $_  # Use as-is if not in map (allows full names too)
                }
            }
        } else {
            # Get all OMG modules from BASE_MODULE_PATH
            $modulesToBuild = Get-ChildItem -Path $env:BASE_MODULE_PATH -Directory |
                Where-Object { $_.Name -like 'OMG.PSUtilities.*' } |
                Select-Object -ExpandProperty Name
        }

        if (-not $modulesToBuild) {
            Write-Warning "No modules found to build"
            return
        }

        Write-Host "Building $($modulesToBuild.Count) module(s)...`n" -ForegroundColor Yellow

        foreach ($module in $modulesToBuild) {
            try {
                Write-Host "Building $module..." -ForegroundColor Cyan

                if (-not $PSCmdlet.ShouldProcess($module, "Build module")) {
                    continue
                }

                $modulePath = Join-Path $env:BASE_MODULE_PATH $module
                $publicPath = Join-Path $modulePath "Public"
                $psm1Path = Join-Path $modulePath "$module.psm1"
                $psd1Path = Join-Path $modulePath "$module.psd1"

                # Validate paths
                if (-not (Test-Path $modulePath)) {
                    throw "Module path not found: $modulePath"
                }
                if (-not (Test-Path $psm1Path)) {
                    throw "Module manifest not found: $psm1Path"
                }
                if (-not (Test-Path $psd1Path)) {
                    throw "Module data file not found: $psd1Path"
                }

                # Run PSScriptAnalyzer
                if ($UseScriptAnalyzer) {
                    Write-Verbose "Running PSScriptAnalyzer on $module..."

                    $rules = @(
                        'PSAvoidUsingWriteHost',
                        'PSAvoidTrailingWhitespace',
                        'PSUseConsistentIndentation',
                        'PSPlaceOpenBrace',
                        'PSPlaceCloseBrace',
                        'PSSpaceAroundOperators',
                        'PSAvoidGlobalVars',
                        'PSAvoidUsingCmdletAliases',
                        'PSAvoidUsingPositionalParameters',
                        'PSUseCorrectCasingForCmdlets',
                        'PSUseCorrectCasingForCommonCmdlets',
                        'PSUseCorrectCasingForCommonParameters',
                        'PSUseShouldProcessForStateChangingFunctions',
                        'PSAvoidLongLines'
                    )

                    $settings = @{
                        ExcludeRules = @('PSUseBOMForUnicodeEncodedFile')
                    }

                    $scriptAnalyzerParams = @{
                        Path          = $modulePath
                        Recurse       = $true
                        IncludeRule   = $rules
                        Settings      = $settings
                        Fix           = $true
                        Severity      = @('Warning', 'Error')
                        ReportSummary = $true
                    }

                    Invoke-ScriptAnalyzer @scriptAnalyzerParams | Out-Null
                }

                # Update manifests
                if (-not $SkipUpdateManifests) {
                    Write-Verbose "Updating manifests for $module..."

                    # Get existing content
                    $existingPsd1Content = (Get-Content -Path $psd1Path -Raw -ErrorAction SilentlyContinue).Trim()
                    $existingPsm1Content = (Get-Content -Path $psm1Path -Raw -ErrorAction SilentlyContinue).Trim()

                    # Scan Public folder for functions
                    $functionsList = Get-ChildItem -Path $publicPath -Filter *.ps1 -Recurse |
                        Where-Object { $_.Name -notlike "*--wip.ps1" } |
                        Select-Object -ExpandProperty BaseName |
                        Sort-Object -Unique

                    # Collect aliases from function files
                    $aliasList = @()
                    Get-ChildItem -Path $publicPath -Filter *.ps1 -Recurse |
                        Where-Object { $_.Name -notlike "*--wip.ps1" } |
                        ForEach-Object {
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
                            } catch {
                                Write-Warning "Failed to read file: $($_.FullName)"
                            }
                        }
                    $aliasList = $aliasList | Sort-Object -Unique

                    # Build quoted array strings for .psd1
                    $functionsArray = @($functionsList | ForEach-Object { "    '$_'" }) -join ",`n"
                    $aliasesArray = @($aliasList | ForEach-Object { "    '$_'" }) -join ",`n"

                    $functionsString = "@(`n$functionsArray`n)"
                    $aliasesString = "@(`n$aliasesArray`n)"

                    # Update .psd1 content
                    $psd1Content = Get-Content $psd1Path -Raw

                    # Replace FunctionsToExport
                    $psd1Content = [regex]::Replace(
                        $psd1Content,
                        "(?s)(FunctionsToExport\s*=\s*)\@\((.*?)\)",
                        "`$1$functionsString"
                    )

                    # Replace AliasesToExport
                    $psd1Content = [regex]::Replace(
                        $psd1Content,
                        "(?s)(AliasesToExport\s*=\s*)\@\((.*?)\)",
                        "`$1$aliasesString"
                    )

                    # Compare and update .psd1
                    $normExistingPsd1 = ($existingPsd1Content -replace "`r`n|`r|`n", "`n").Trim()
                    $normNewPsd1 = ($psd1Content -replace "`r`n|`r|`n", "`n").Trim()

                    if ($normNewPsd1 -ne $normExistingPsd1) {
                        $psd1Content.Trim() | Set-Content -Path $psd1Path -Encoding UTF8
                        Write-Host "  UPDATED: $module.psd1" -ForegroundColor Green
                    } else {
                        Write-Host "  No changes: $module.psd1" -ForegroundColor Yellow
                    }

                    # Build .psm1 content
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

                    # Compare and update .psm1
                    $normExistingPsm1 = ($existingPsm1Content -replace "`r`n|`r|`n", "`n").Trim()
                    $normNewPsm1 = ($psm1Content -replace "`r`n|`r|`n", "`n").Trim()

                    if ($normExistingPsm1 -ne $normNewPsm1) {
                        $psm1Content.Trim() | Set-Content -Path $psm1Path -Encoding UTF8
                        Write-Host "  UPDATED: $module.psm1" -ForegroundColor Green
                    } else {
                        Write-Host "  No changes: $module.psm1" -ForegroundColor Yellow
                    }
                }

                # Remove old module from session
                try {
                    Remove-Module -Name $module -Force -ErrorAction SilentlyContinue
                    Write-Verbose "Removed existing $module from session"
                } catch {
                    # Ignore errors if module wasn't loaded
                }

                # Import updated module
                Import-Module $psm1Path -Force -ErrorAction Stop
                Write-Host "  IMPORTED: $module" -ForegroundColor Green

                $buildResults.Success += $module
                Write-Host "✓ $module built successfully`n" -ForegroundColor Green

            } catch {
                $buildResults.Failed += @{
                    Module = $module
                    Error  = $_.Exception.Message
                }
                Write-Error "✗ Failed to build $module : $_`n"
            }
        }
    }

    end {
        # Summary
        Write-Host "=== Build Summary ===" -ForegroundColor Cyan
        Write-Host "Successfully built: $($buildResults.Success.Count)" -ForegroundColor Green
        Write-Host "Failed: $($buildResults.Failed.Count)" -ForegroundColor Red

        if ($buildResults.Failed.Count -gt 0) {
            Write-Host "`nFailed modules:" -ForegroundColor Red
            $buildResults.Failed | ForEach-Object {
                Write-Host "  • $($_.Module): $($_.Error)" -ForegroundColor Yellow
            }
        }

        return $buildResults
    }
}