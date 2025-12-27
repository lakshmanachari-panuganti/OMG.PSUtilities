function Invoke-OMGUpdateModule {
    <#
    .SYNOPSIS
        Updates all OMG modules from PowerShell Gallery.

    .DESCRIPTION
        Checks each OMG module for updates in PSGallery and installs newer versions.

    .PARAMETER Force
        Forces update even if version matches.

    .PARAMETER WhatIf
        Shows what would be updated without making changes.

    .EXAMPLE
        Invoke-OMGUpdateModule
        Updates all OMG modules that have newer versions in PSGallery.

    .EXAMPLE
        Invoke-OMGUpdateModule -WhatIf
        Shows which modules would be updated.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [alias("updateomgmodule")]
    param(
        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Host "`n=== OMG Module Updater ===" -ForegroundColor Cyan
        $updateResults = @{
            Updated = @()
            UpToDate = @()
            Failed = @()
            NotFound = @()
        }
    }

    process {
        $modules = Get-OMGModule

        if (-not $modules) {
            Write-Warning "No OMG modules found to update"
            return
        }

        Write-Host "Checking $($modules.Count) module(s) for updates...`n" -ForegroundColor Yellow

        foreach ($module in $modules) {
            try {
                Write-Host "Checking $($module.ModuleName)..." -ForegroundColor Cyan

                # Get local version
                $localModule = Get-Module -ListAvailable -Name $module.ModuleName -ErrorAction SilentlyContinue |
                    Sort-Object Version -Descending |
                    Select-Object -First 1

                if (-not $localModule) {
                    Write-Warning "  ⚠ Module not installed locally: $($module.ModuleName)"
                    $updateResults.NotFound += $module.ModuleName
                    continue
                }

                # Get gallery version
                $galleryModule = Find-Module -Name $module.ModuleName -Repository PSGallery -ErrorAction SilentlyContinue

                if (-not $galleryModule) {
                    Write-Warning "  ⚠ Module not found in PSGallery: $($module.ModuleName)"
                    $updateResults.NotFound += $module.ModuleName
                    continue
                }

                # Compare versions
                if ($localModule.Version -ne $galleryModule.Version -or $Force) {
                    Write-Host "  Local: $($localModule.Version) | PSGallery: $($galleryModule.Version)" -ForegroundColor Yellow

                    if ($PSCmdlet.ShouldProcess($module.ModuleName, "Update from $($localModule.Version) to $($galleryModule.Version)")) {
                        Update-Module -Name $module.ModuleName -Force -Verbose:$VerbosePreference
                        $updateResults.Updated += @{
                            Module = $module.ModuleName
                            OldVersion = $localModule.Version
                            NewVersion = $galleryModule.Version
                        }
                        Write-Host "  ✓ Updated successfully" -ForegroundColor Green
                    }
                }
                else {
                    Write-Host "  ✓ Already up to date ($($localModule.Version))" -ForegroundColor Green
                    $updateResults.UpToDate += $module.ModuleName
                }
            }
            catch {
                $updateResults.Failed += @{
                    Module = $module.ModuleName
                    Error = $_.Exception.Message
                }
                Write-Error "  ✗ Failed to update $($module.ModuleName): $_"
            }

            Write-Host ""
        }

        # Summary
        Write-Host "=== Update Summary ===" -ForegroundColor Cyan
        Write-Host "Updated: $($updateResults.Updated.Count)" -ForegroundColor Green
        Write-Host "Up to date: $($updateResults.UpToDate.Count)" -ForegroundColor Green
        Write-Host "Failed: $($updateResults.Failed.Count)" -ForegroundColor Red
        Write-Host "Not found: $($updateResults.NotFound.Count)" -ForegroundColor Yellow

        return $updateResults
    }
}