function Invoke-OMGBuildModule {
    <#
    .SYNOPSIS
        Builds all OMG modules locally.

    .DESCRIPTION
        Builds each OMG module using Build-OMGModuleLocally with optional script analysis.

    .PARAMETER SkipScriptAnalyzer
        Skip PSScriptAnalyzer validation during build.

    .PARAMETER ModuleName
        Specific module name(s) to build. If not specified, builds all modules.

    .PARAMETER WhatIf
        Shows what would be built without making changes.

    .EXAMPLE
        Invoke-OMGBuildModule
        Builds all OMG modules.

    .EXAMPLE
        Invoke-OMGBuildModule -ModuleName "OMG.PSUtilities.Core" -SkipScriptAnalyzer
        Builds a specific module without script analysis.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [Alias('omgbuild')]
    param(
        [Parameter()]
        [switch]$SkipScriptAnalyzer = $true,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, position=0)]
        [ValidateSet('AI','AzureCore','AzureDevOps','Core','ServiceNow','VSphere','ActiveDirectory')]
        [string[]]$ModuleName
    )

    begin {
        Initialize-ModuleDevTools

        Write-Host "`n=== OMG Module Builder ===" -ForegroundColor Cyan

        $buildResults = @{
            Success = @()
            Failed = @()
        }
    }

    process {
        # Map short names to full module names
        $moduleMap = @{
            'AI' = 'OMG.PSUtilities.AI'
            'AzureCore' = 'OMG.PSUtilities.AzureCore'
            'AzureDevOps' = 'OMG.PSUtilities.AzureDevOps'
            'Core' = 'OMG.PSUtilities.Core'
            'ServiceNow' = 'OMG.PSUtilities.ServiceNow'
            'VSphere' = 'OMG.PSUtilities.VSphere'
            'ActiveDirectory' = 'OMG.PSUtilities.ActiveDirectory'
        }

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
            $modulesToBuild = (Get-OMGModule).ModuleName
        }

        if (-not $modulesToBuild) {
            Write-Warning "No modules found to build"
            return
        }

        Write-Host "Building $($modulesToBuild.Count) module(s)...`n" -ForegroundColor Yellow

        foreach ($module in $modulesToBuild) {
            try {
                Write-Host "Building $module..." -ForegroundColor Cyan

                if ($PSCmdlet.ShouldProcess($module, "Build module")) {
                    Build-OMGModuleLocally -ModuleName $module -SkipScriptAnalyzer:$SkipScriptAnalyzer -Verbose:$VerbosePreference

                    $buildResults.Success += $module
                    Write-Host "✓ $module built successfully`n" -ForegroundColor Green
                }
            }
            catch {
                $buildResults.Failed += @{
                    Module = $module
                    Error = $_.Exception.Message
                }
                Write-Error "✗ Failed to build $module : $_`n"
            }
        }

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