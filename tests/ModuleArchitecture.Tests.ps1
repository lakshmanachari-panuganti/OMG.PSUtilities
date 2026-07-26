$repositoryRoot = Split-Path -Parent $PSScriptRoot
$env:PSModulePath = "$repositoryRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
$moduleDirectories = Get-ChildItem -Path $repositoryRoot -Directory |
    Where-Object {
        $_.Name -eq 'OMG.PSUtilities' -or
        $_.Name -like 'OMG.PSUtilities.*' -or
        $_.Name -eq 'OMG.DevTools'
    } |
    Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psd1") }

Describe 'Module portfolio architecture' {
    It 'contains a valid manifest for every module' -ForEach $moduleDirectories {
        $manifestPath = Join-Path $_.FullName "$($_.Name).psd1"
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'keeps manifest exports synchronized with Public files' -ForEach $moduleDirectories {
        $publicPath = Join-Path $_.FullName 'Public'
        if (-not (Test-Path $publicPath)) {
            Set-ItResult -Skipped -Because 'the meta-module has no Public folder'
            return
        }

        $manifestPath = Join-Path $_.FullName "$($_.Name).psd1"
        $manifest = Test-ModuleManifest -Path $manifestPath
        $publicFunctions = Get-ChildItem -Path $publicPath -Recurse -Filter '*.ps1' -File |
            Where-Object { $_.Name -notlike '*--wip.ps1' } |
            ForEach-Object { $_.BaseName } |
            Sort-Object -Unique
        $manifestFunctions = @($manifest.ExportedFunctions.Keys) | Sort-Object -Unique

        Compare-Object -ReferenceObject $publicFunctions -DifferenceObject $manifestFunctions |
            Should -BeNullOrEmpty
    }

    It 'does not export a function from Private' -ForEach $moduleDirectories {
        $privatePath = Join-Path $_.FullName 'Private'
        if (-not (Test-Path $privatePath)) {
            Set-ItResult -Skipped -Because 'the module has no Private folder'
            return
        }

        $manifestPath = Join-Path $_.FullName "$($_.Name).psd1"
        $manifest = Test-ModuleManifest -Path $manifestPath
        $privateFunctions = Get-ChildItem -Path $privatePath -Recurse -Filter '*.ps1' -File |
            ForEach-Object { $_.BaseName }

        @($manifest.ExportedFunctions.Keys | Where-Object { $_ -in $privateFunctions }) |
            Should -BeNullOrEmpty
    }
}