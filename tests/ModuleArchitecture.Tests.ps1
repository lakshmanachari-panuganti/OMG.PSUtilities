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
    BeforeAll {
        function Assert-ManifestExportsSynchronized {
            param (
                [Parameter(Mandatory)]
                [string]$ModulePath
            )

            $moduleName = Split-Path -Leaf $ModulePath
            $manifestPath = Join-Path $ModulePath "$moduleName.psd1"
            $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
            $publicPath = Join-Path $ModulePath 'Public'
            $publicFunctions = if (Test-Path -LiteralPath $publicPath) {
                @(Get-ChildItem -LiteralPath $publicPath -Recurse -Filter '*.ps1' -File |
                    Where-Object { $_.Name -notlike '*--wip.ps1' } |
                    ForEach-Object { $_.BaseName } |
                    Sort-Object -Unique)
            } else {
                @()
            }
            $manifestFunctions = @($manifest.FunctionsToExport | Sort-Object -Unique)
            $missingFromManifest = @($publicFunctions | Where-Object { $_ -notin $manifestFunctions })
            $missingFromPublic = @($manifestFunctions | Where-Object { $_ -notin $publicFunctions })

            if ($missingFromManifest.Count -gt 0 -or $missingFromPublic.Count -gt 0) {
                $missingFromManifestText = if ($missingFromManifest.Count -gt 0) {
                    $missingFromManifest -join ', '
                } else {
                    '(none)'
                }
                $missingFromPublicText = if ($missingFromPublic.Count -gt 0) {
                    $missingFromPublic -join ', '
                } else {
                    '(none)'
                }
                throw "[$moduleName] Export mismatch. Missing from manifest: $missingFromManifestText. Not found in Public: $missingFromPublicText."
            }
        }
    }

    It 'contains a valid manifest for every module' -ForEach $moduleDirectories {
        $manifestPath = Join-Path $_.FullName "$($_.Name).psd1"
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'keeps manifest exports synchronized with Public files' -ForEach $moduleDirectories {
        { Assert-ManifestExportsSynchronized -ModulePath $_.FullName } | Should -Not -Throw
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

    It 'rejects an export that has no Public function' {
        $modulePath = Join-Path $TestDrive 'OMG.PSUtilities.InvalidExport'
        New-Item -Path (Join-Path $modulePath 'Public') -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $modulePath 'OMG.PSUtilities.InvalidExport.psd1') -Value @"
@{
    ModuleVersion = '1.0.0'
    FunctionsToExport = @('Get-MissingFixture')
}
"@

        {
            Assert-ManifestExportsSynchronized -ModulePath $modulePath
        } | Should -Throw '*Get-MissingFixture*'
    }
}

Describe 'Repository architecture guardrails' {
    BeforeAll {
        function Get-ModuleDependencyGraph {
            param (
                [Parameter(Mandatory)]
                [System.IO.DirectoryInfo[]]$ModuleDirectory
            )

            $moduleNames = @($ModuleDirectory.Name)
            $graph = @{}

            foreach ($directory in $ModuleDirectory) {
                $manifestPath = Join-Path $directory.FullName "$($directory.Name).psd1"
                $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
                $dependencyNames = @($manifest.RequiredModules | ForEach-Object {
                        if ($null -eq $_) {
                            return
                        } elseif ($_ -is [string]) {
                            $_
                        } elseif ($_ -is [System.Collections.IDictionary]) {
                            [string]$_['ModuleName']
                        } elseif ($_.PSObject.Properties['Name']) {
                            [string]$_.Name
                        } elseif ($_.PSObject.Properties['ModuleName']) {
                            [string]$_.ModuleName
                        }
                    } | Where-Object { $_ -in $moduleNames })
                $graph[$directory.Name] = $dependencyNames
            }

            $graph
        }

        function Find-ModuleDependencyCycle {
            param (
                [Parameter(Mandatory)]
                [hashtable]$Graph
            )

            foreach ($startModule in ($Graph.Keys | Sort-Object)) {
                $paths = [System.Collections.Generic.Stack[object]]::new()
                $paths.Push([PSCustomObject]@{
                        Module = $startModule
                        Path   = @($startModule)
                    })

                while ($paths.Count -gt 0) {
                    $currentPath = $paths.Pop()
                    foreach ($dependency in @($Graph[$currentPath.Module])) {
                        if (-not $Graph.ContainsKey($dependency)) {
                            continue
                        }

                        if ($dependency -eq $startModule) {
                            return (@($currentPath.Path) + $dependency) -join ' -> '
                        }

                        if ($dependency -notin $currentPath.Path) {
                            $paths.Push([PSCustomObject]@{
                                    Module = $dependency
                                    Path   = @($currentPath.Path) + $dependency
                                })
                        }
                    }
                }
            }

            $null
        }

        function Assert-NoModuleDependencyCycle {
            param (
                [Parameter(Mandatory)]
                [hashtable]$Graph
            )

            $cycle = Find-ModuleDependencyCycle -Graph $Graph
            if ($cycle) {
                throw "Module dependency cycle detected: $cycle"
            }
        }

        function Assert-NoPackagedWipScript {
            param (
                [Parameter(Mandatory)]
                [string]$PackageRoot
            )

            $wipFiles = @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Filter '*--wip.ps1')
            if ($wipFiles.Count -gt 0) {
                $relativePaths = @($wipFiles | ForEach-Object {
                        [System.IO.Path]::GetRelativePath($PackageRoot, $_.FullName).Replace('\', '/')
                    } | Sort-Object)
                throw "Built package contains work-in-progress scripts: $($relativePaths -join ', ')"
            }
        }

        $architectureRepositoryRoot = Split-Path -Parent $PSScriptRoot
        $architectureModuleDirectories = @(Get-ChildItem -Path $architectureRepositoryRoot -Directory |
            Where-Object {
                $_.Name -eq 'OMG.PSUtilities' -or
                $_.Name -like 'OMG.PSUtilities.*' -or
                $_.Name -eq 'OMG.DevTools'
            } |
            Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psd1") })
        $dependencyGraph = Get-ModuleDependencyGraph -ModuleDirectory $architectureModuleDirectories
        $builtModuleRoot = Join-Path $TestDrive 'built-modules'
        & (Join-Path $architectureRepositoryRoot 'build/Build-Modules.ps1') `
            -RepositoryRoot $architectureRepositoryRoot `
            -OutputPath $builtModuleRoot `
            -Clean | Out-Null
    }

    It 'contains no module dependency cycle' {
        { Assert-NoModuleDependencyCycle -Graph $dependencyGraph } | Should -Not -Throw
    }

    It 'packages no work-in-progress scripts' {
        { Assert-NoPackagedWipScript -PackageRoot $builtModuleRoot } | Should -Not -Throw
    }

    It 'rejects a dependency-cycle fixture' {
        $cyclicGraph = @{
            'OMG.PSUtilities.A' = @('OMG.PSUtilities.B')
            'OMG.PSUtilities.B' = @('OMG.PSUtilities.C')
            'OMG.PSUtilities.C' = @('OMG.PSUtilities.A')
        }

        { Assert-NoModuleDependencyCycle -Graph $cyclicGraph } |
            Should -Throw '*Module dependency cycle detected*'
    }

    It 'rejects a built-package WIP fixture' {
        $packageRoot = Join-Path $TestDrive 'invalid-built-package'
        $wipPath = Join-Path $packageRoot 'OMG.PSUtilities.Fixture/Public/Get-Fixture--wip.ps1'
        New-Item -Path (Split-Path -Parent $wipPath) -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath $wipPath -Value 'function Get-Fixture { }'

        { Assert-NoPackagedWipScript -PackageRoot $packageRoot } |
            Should -Throw '*Get-Fixture--wip.ps1*'
    }
}

Describe 'Module release integrity' {
    BeforeAll {
        $versionGatePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'build/Test-ModuleVersionChange.ps1'
        $publishedComparisonPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'build/Compare-PublishedModule.ps1'

        function New-VersionGateFixture {
            param (
                [Parameter(Mandatory)]
                [string]$RootPath
            )

            $fixturePath = Join-Path $RootPath ([guid]::NewGuid().ToString('N'))
            $moduleName = 'OMG.PSUtilities.Fixture'
            $modulePath = Join-Path $fixturePath $moduleName
            New-Item -Path $modulePath -ItemType Directory -Force | Out-Null

            & git -C $fixturePath init --quiet
            & git -C $fixturePath config user.name 'Release Integrity Test'
            & git -C $fixturePath config user.email 'release-integrity@example.invalid'
            & git -C $fixturePath config core.autocrlf false

            Set-Content -LiteralPath (Join-Path $modulePath "$moduleName.psd1") -NoNewline -Value @"
@{
    ModuleVersion = '1.0.0'
    Description = 'Fixture module'
}
"@
            Set-Content -LiteralPath (Join-Path $modulePath "$moduleName.psm1") -NoNewline -Value "function Get-Fixture { 'base' }`n"

            & git -C $fixturePath add .
            & git -C $fixturePath commit --quiet -m 'base'

            [PSCustomObject]@{
                RepositoryPath = $fixturePath
                ModuleName     = $moduleName
                ModulePath     = $modulePath
                BaseCommit     = (& git -C $fixturePath rev-parse HEAD).Trim()
            }
        }

        function Add-VersionGateFixtureCommit {
            param (
                [Parameter(Mandatory)]
                [PSCustomObject]$Fixture,

                [Parameter(Mandatory)]
                [hashtable]$Changes,

                [Parameter(Mandatory)]
                [string]$Message
            )

            foreach ($change in $Changes.GetEnumerator()) {
                $path = Join-Path $Fixture.RepositoryPath $change.Key
                New-Item -Path (Split-Path -Parent $path) -ItemType Directory -Force | Out-Null
                Set-Content -LiteralPath $path -NoNewline -Value $change.Value
            }

            & git -C $Fixture.RepositoryPath add .
            & git -C $Fixture.RepositoryPath commit --quiet -m $Message
            (& git -C $Fixture.RepositoryPath rev-parse HEAD).Trim()
        }

        function New-PublishedComparisonFixture {
            param (
                [Parameter(Mandatory)]
                [string]$RootPath
            )

            $fixturePath = Join-Path $RootPath ([guid]::NewGuid().ToString('N'))
            $artifactRoot = Join-Path $fixturePath 'artifacts'
            $publishedRoot = Join-Path $fixturePath 'published'
            $moduleName = 'OMG.PSUtilities.Fixture'
            $artifactModulePath = Join-Path $artifactRoot $moduleName
            New-Item -Path $artifactModulePath -ItemType Directory -Force | Out-Null
            New-Item -Path $publishedRoot -ItemType Directory -Force | Out-Null

            Set-Content -LiteralPath (Join-Path $artifactModulePath "$moduleName.psd1") -NoNewline -Value @"
@{
    ModuleVersion = '1.0.0'
}
"@
            Set-Content -LiteralPath (Join-Path $artifactModulePath "$moduleName.psm1") -NoNewline -Value "function Get-Fixture { 'same' }`n"
            Copy-Item -Path (Join-Path $artifactModulePath '*') -Destination $publishedRoot -Recurse

            [PSCustomObject]@{
                ArtifactRoot  = $artifactRoot
                ModuleName    = $moduleName
                PublishedRoot = $publishedRoot
            }
        }
    }

    It 'passes when module source and version are unchanged' {
        $fixture = New-VersionGateFixture -RootPath $TestDrive

        {
            & $versionGatePath `
                -RepositoryRoot $fixture.RepositoryPath `
                -BaseRef $fixture.BaseCommit `
                -HeadRef $fixture.BaseCommit | Out-Null
        } | Should -Not -Throw
    }

    It 'rejects a publishable source change without a version increase' {
        $fixture = New-VersionGateFixture -RootPath $TestDrive
        $headCommit = Add-VersionGateFixtureCommit -Fixture $fixture -Message 'change source' -Changes @{
            "$($fixture.ModuleName)/$($fixture.ModuleName).psm1" = "function Get-Fixture { 'changed' }`n"
        }

        {
            & $versionGatePath `
                -RepositoryRoot $fixture.RepositoryPath `
                -BaseRef $fixture.BaseCommit `
                -HeadRef $headCommit | Out-Null
        } | Should -Throw '*OMG.PSUtilities.Fixture*ModuleVersion remains 1.0.0*'
    }

    It 'passes when publishable source changes with an increased version' {
        $fixture = New-VersionGateFixture -RootPath $TestDrive
        $headCommit = Add-VersionGateFixtureCommit -Fixture $fixture -Message 'change source and version' -Changes @{
            "$($fixture.ModuleName)/$($fixture.ModuleName).psd1" = @"
@{
    ModuleVersion = '1.0.1'
    Description = 'Fixture module'
}
"@
            "$($fixture.ModuleName)/$($fixture.ModuleName).psm1" = "function Get-Fixture { 'changed' }`n"
        }

        {
            & $versionGatePath `
                -RepositoryRoot $fixture.RepositoryPath `
                -BaseRef $fixture.BaseCommit `
                -HeadRef $headCommit | Out-Null
        } | Should -Not -Throw
    }

    It 'passes when only a build-excluded repository file changes' {
        $fixture = New-VersionGateFixture -RootPath $TestDrive
        $headCommit = Add-VersionGateFixtureCommit -Fixture $fixture -Message 'change excluded file' -Changes @{
            "$($fixture.ModuleName)/.github/config.yml" = "repository-only: true`n"
        }

        {
            & $versionGatePath `
                -RepositoryRoot $fixture.RepositoryPath `
                -BaseRef $fixture.BaseCommit `
                -HeadRef $headCommit | Out-Null
        } | Should -Not -Throw
    }

    It 'rejects a packaged <Name> change without a version increase' -ForEach @(
        @{
            Name    = 'manifest'
            Path    = 'OMG.PSUtilities.Fixture/OMG.PSUtilities.Fixture.psd1'
            Content = @"
@{
    ModuleVersion = '1.0.0'
    Description = 'Changed fixture metadata'
}
"@
        }
        @{
            Name    = 'help'
            Path    = 'OMG.PSUtilities.Fixture/en-US/OMG.PSUtilities.Fixture-help.xml'
            Content = "<helpItems schema='maml'><changed /></helpItems>`n"
        }
        @{
            Name    = 'format data'
            Path    = 'OMG.PSUtilities.Fixture/OMG.PSUtilities.Fixture.format.ps1xml'
            Content = "<Configuration><ViewDefinitions /></Configuration>`n"
        }
    ) {
        $fixture = New-VersionGateFixture -RootPath $TestDrive
        $headCommit = Add-VersionGateFixtureCommit -Fixture $fixture -Message "change $Name" -Changes @{
            $Path = $Content
        }

        {
            & $versionGatePath `
                -RepositoryRoot $fixture.RepositoryPath `
                -BaseRef $fixture.BaseCommit `
                -HeadRef $headCommit | Out-Null
        } | Should -Throw '*OMG.PSUtilities.Fixture*ModuleVersion remains 1.0.0*'
    }

    It 'rejects a same-version Gallery package with different content' {
        $fixture = New-PublishedComparisonFixture -RootPath $TestDrive
        Set-Content `
            -LiteralPath (Join-Path $fixture.PublishedRoot "$($fixture.ModuleName).psm1") `
            -NoNewline `
            -Value "function Get-Fixture { 'different' }`n"

        Mock Find-Module {
            [PSCustomObject]@{
                Name    = $fixture.ModuleName
                Version = [version]'1.0.0'
            }
        }
        Mock Save-Module {
            $destination = Join-Path $Path "$Name/$RequiredVersion"
            New-Item -Path $destination -ItemType Directory -Force | Out-Null
            Copy-Item -Path (Join-Path $fixture.PublishedRoot '*') -Destination $destination -Recurse -Force
        }

        {
            & $publishedComparisonPath `
                -ArtifactRoot $fixture.ArtifactRoot `
                -ModuleName $fixture.ModuleName | Out-Null
        } | Should -Throw '*OMG.PSUtilities.Fixture 1.0.0*Files with different hashes: OMG.PSUtilities.Fixture.psm1*'
        Should -Invoke Find-Module -Exactly 1
        Should -Invoke Save-Module -Exactly 1
    }

    It 'passes when the downloaded new package equals the artifact' {
        $fixture = New-PublishedComparisonFixture -RootPath $TestDrive

        Mock Find-Module {
            [PSCustomObject]@{
                Name    = $fixture.ModuleName
                Version = [version]'1.0.0'
            }
        }
        Mock Save-Module {
            $destination = Join-Path $Path "$Name/$RequiredVersion"
            New-Item -Path $destination -ItemType Directory -Force | Out-Null
            Copy-Item -Path (Join-Path $fixture.PublishedRoot '*') -Destination $destination -Recurse -Force
        }

        $result = & $publishedComparisonPath `
            -ArtifactRoot $fixture.ArtifactRoot `
            -ModuleName $fixture.ModuleName `
            -RequirePublishedVersion

        $result.Status | Should -Be 'Matched'
        $result.FilesCompared | Should -Be 2
        Should -Invoke Find-Module -Exactly 1
        Should -Invoke Save-Module -Exactly 1
    }
}
