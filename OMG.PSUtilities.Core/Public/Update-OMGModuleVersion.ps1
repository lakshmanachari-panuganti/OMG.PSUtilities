<#
.SYNOPSIS
Increments the version of a specified PowerShell module by Major, Minor, or Patch.

.DESCRIPTION
The Update-OMGModuleVersion function updates the version number of a PowerShell module by incrementing the Major, Minor, or Patch component. It modifies the ModuleVersion in the module's .psd1 manifest file and, if present, updates the version in the plasterManifest.xml file as well.

.PARAMETER ModuleName
The name of the module whose version should be updated. This should correspond to a directory under the path specified by the BASE_MODULE_PATH environment variable.

.PARAMETER Increment
Specifies which part of the version to increment. Valid values are 'Major', 'Minor', or 'Patch'.

.INPUTS
System.String
Accepts the module name from the pipeline.

.OUTPUTS
PSCustomObject

.EXAMPLE
Update-OMGModuleVersion -ModuleName 'MyModule' -Increment 'Minor'

Increments the minor version of 'MyModule' and updates the relevant manifest files.

.EXAMPLE
'MyModule' | Update-OMGModuleVersion -Increment 'Patch'

Increments the patch version of 'MyModule' using pipeline input.

.NOTES
- The function expects the BASE_MODULE_PATH environment variable to be set.
- The function will only update the version if the .psd1 manifest file and (optionally) plasterManifest.xml are present in the module directory.
- The current version is retrieved from the PSGallery repository.

#>
function Update-OMGModuleVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [ValidateSet("Major", "Minor", "Patch")]
        [string]$Increment
    )
    process {
        $modulePath = Join-Path $env:BASE_MODULE_PATH $ModuleName

        if (-not (Test-Path $modulePath)) {
            Write-Error "Module path not found: $modulePath"
            return
        }

        $psd1Path = Get-ChildItem -Path $modulePath -Filter *.psd1 | Select-Object -First 1
        if (-not $psd1Path) {
            Write-Error "Could not find .psd1 in $modulePath"
            return
        }

        $content = Get-Content $psd1Path.FullName
        $currentVersion = (Find-Module $ModuleName -Repository PSGallery).Version

        if (-not $currentVersion -or $currentVersion -notmatch '^\d+\.\d+\.\d+$') {
            Write-Error "Invalid or missing version in $($psd1Path.Name)"
            return
        }

        # Split and bump version
        $versionParts = $currentVersion -split '\.'
        [int]$major = $versionParts[0]
        [int]$minor = $versionParts[1]
        [int]$patch = $versionParts[2]

        switch ($Increment) {
            "Major" { $major++; $minor = 0; $patch = 0 }
            "Minor" { $minor++; $patch = 0 }
            "Patch" { $patch++ }
        }

        $newVersion = "$major.$minor.$patch"
        Write-Host "Attempting to update module version from $currentVersion to $newVersion..." -ForegroundColor Cyan

        # Update .psd1
        $newContent = $content -replace "(ModuleVersion\s*=\s*)['""][^'""]+['""]", "`$1'$newVersion'"
        Set-Content -Path $psd1Path.FullName -Value $newContent -Encoding UTF8
        Write-Host "Updated $newVersion in $($psd1Path.Name)" -ForegroundColor Green

        # Update plasterManifest.xml
        $plasterManifestPath = Join-Path $modulePath "plasterManifest.xml"
        if (Test-Path $plasterManifestPath) {
            $xml = [xml](Get-Content $plasterManifestPath)
            $xml.plasterManifest.metadata.version = $newVersion
            $xml.Save($plasterManifestPath)
            Write-Host "Updated $newVersion in $plasterManifestPath " -ForegroundColor DarkCyan
        }
        else {
            Write-Warning "plasterManifest.xml not found in $ModuleName — skipping update."
        }

        Return [psobject] @{
            ModuleName = $ModuleName
            NewVersion = $newVersion
        }
    
    }
}