function Invoke-OMGPublishModule {
    <#
    .SYNOPSIS
        Publishes updated OMG modules to PowerShell Gallery.

    .DESCRIPTION
        Detects modules with git changes, updates versions, optionally updates changelogs,
        commits changes, and publishes to PSGallery.

    .PARAMETER SkipChangelog
        Skip updating the CHANGELOG.md files.

    .PARAMETER SkipGitCommit
        Skip the git commit step.

    .PARAMETER Force
        Bypass confirmation prompts.

    .PARAMETER WhatIf
        Shows what would happen without making changes.

    .EXAMPLE
        Invoke-OMGPublishModule
        Interactively publishes updated modules.

    .EXAMPLE
        Invoke-OMGPublishModule -SkipChangelog -Force
        Publishes without updating changelogs and without prompts.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [alias("publishomgmodule")]
    param(
        [Parameter()]
        [switch]$SkipChangelog,

        [Parameter()]
        [switch]$SkipGitCommit,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Initialize-ModuleDevTools

        if (-not $env:API_KEY_PSGALLERY) {
            throw "API_KEY_PSGALLERY environment variable is not set. Run Initialize-OMGEnvironment first."
        }

        Write-Host "`n=== OMG Module Publisher ===" -ForegroundColor Cyan
    }

    process {
        try {
            # Get modules with changes
            Write-Host "`nDetecting modules with changes..." -ForegroundColor Yellow
            $modulesUpdated = Get-PSUGitFileChangeMetadata |
                Where-Object {
                    $_.file -like 'OMG.PSUtilities.*/*/*.ps1' -and
                    $_.file -notlike 'OMG.PSUtilities.*/*/*--wip.ps1'
                } |
                ForEach-Object { $_.file.Split('/')[0] } |
                Sort-Object -Unique

            if (-not $modulesUpdated) {
                Write-Host "✓ No modules to publish (no changes detected)" -ForegroundColor Green
                return
            }

            Write-Host "Found $($modulesUpdated.Count) module(s) with changes:" -ForegroundColor Green
            $modulesUpdated | ForEach-Object { Write-Host "  • $_" -ForegroundColor White }

            # Update versions
            Write-Host "`nUpdating module versions..." -ForegroundColor Yellow
            if ($PSCmdlet.ShouldProcess("Module versions", "Increment patch version")) {
                $modulesUpdated | Update-OMGModuleVersion -Increment Patch
            }

            # Reset manifests
            Write-Host "Resetting module manifests..." -ForegroundColor Yellow
            if ($PSCmdlet.ShouldProcess("Module manifests", "Reset")) {
                $modulesUpdated | Reset-OMGModuleManifests
            }

            # Update changelogs
            if (-not $SkipChangelog) {
                if ($Force -or (Read-Host "`nUpdate CHANGELOG.md for updated modules? (Y/N)") -eq 'Y') {
                    Write-Host "Updating changelogs..." -ForegroundColor Yellow
                    if ($PSCmdlet.ShouldProcess("Changelogs", "Update")) {
                        $modulesUpdated | Update-PSUChangeLog -ErrorAction Continue
                    }
                }
            }

            # Git commit
            if (-not $SkipGitCommit) {
                Write-Host "`nCreating git commit..." -ForegroundColor Yellow
                if ($PSCmdlet.ShouldProcess("Git repository", "Commit changes")) {
                    aigitcommit
                }
            }

            # Publish to PSGallery
            if ($Force -or (Read-Host "`nPublish updated modules to PSGallery? (Y/N)") -eq 'Y') {
                Write-Host "`nPublishing modules to PSGallery..." -ForegroundColor Yellow

                $publishResults = @{
                    Success = @()
                    AlreadyPublished = @()
                    Failed = @()
                }

                foreach ($moduleName in $modulesUpdated) {
                    $modulePath = Join-Path $env:BASE_MODULE_PATH $moduleName

                    if ($PSCmdlet.ShouldProcess($moduleName, "Publish to PSGallery")) {
                        try {
                            Write-Host "`n  Publishing $moduleName..." -ForegroundColor Cyan

                            Publish-Module -Path $modulePath -NuGetApiKey $env:API_KEY_PSGALLERY -ErrorAction Stop

                            $publishResults.Success += $moduleName
                            Write-Host "  ✓ $moduleName published successfully" -ForegroundColor Green
                        }
                        catch {
                            $exception = $_.Exception.Message

                            if ($exception -like "*current version*is already available in the repository*") {
                                $publishResults.AlreadyPublished += $moduleName
                                Write-Host "  ⚠ $moduleName : Current version already exists in PSGallery" -ForegroundColor Yellow
                            }
                            else {
                                $publishResults.Failed += @{
                                    Module = $moduleName
                                    Error = $exception
                                }
                                Write-Error "  ✗ Failed to publish $moduleName : $exception"
                            }
                        }
                    }
                }

                # Summary
                Write-Host "`n=== Publish Summary ===" -ForegroundColor Cyan
                Write-Host "Successfully published: $($publishResults.Success.Count)" -ForegroundColor Green
                Write-Host "Already published: $($publishResults.AlreadyPublished.Count)" -ForegroundColor Yellow
                Write-Host "Failed: $($publishResults.Failed.Count)" -ForegroundColor Red

                return $publishResults
            }
        }
        catch {
            Write-Error "Failed to publish modules: $_"
            throw
        }
    }
}