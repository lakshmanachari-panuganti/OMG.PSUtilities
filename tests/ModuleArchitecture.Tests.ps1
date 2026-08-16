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

Describe 'Live public function contracts' {
    BeforeAll {
        $liveModuleNames = @(
            'OMG.PSUtilities.ActiveDirectory'
            'OMG.PSUtilities.AI'
            'OMG.PSUtilities.AzureCore'
            'OMG.PSUtilities.AzureDevOps'
            'OMG.PSUtilities.Core'
            'OMG.PSUtilities.ServiceNow'
            'OMG.PSUtilities.VSphere'
            'OMG.DevTools'
        )
        $approvedExternalCommands = @(
            'az'
            'Close-ExcelPackage'
            'Connect-AzAccount'
            'Export-Excel'
            'Get-ADUser'
            'Get-AzAccessToken'
            'Get-AzCognitiveServicesAccount'
            'Get-AzCognitiveServicesAccountKey'
            'Get-AzContext'
            'Get-AzResourceGroup'
            'Get-AzRoleAssignment'
            'Get-AzSubscription'
            'Get-MgApplication'
            'Get-MgAuditLogSignIn'
            'Get-MgContext'
            'Get-MgIdentityConditionalAccessPolicy'
            'Get-MgOauth2PermissionGrant'
            'Get-MgOrganization'
            'Get-MgRoleManagementDirectoryRoleAssignment'
            'Get-MgRoleManagementDirectoryRoleDefinition'
            'Get-MgServicePrincipal'
            'Get-MgServicePrincipalAppRoleAssignedTo'
            'Get-MgServicePrincipalAppRoleAssignment'
            'Get-NetIPConfiguration'
            'Get-WinEvent'
            'git'
            'Invoke-ScriptAnalyzer'
            'kubectl'
            'logoff'
            'New-AzCognitiveServicesAccount'
            'New-AzResourceGroup'
            'New-MgUserEvent'
            'netsh'
            'query'
            'Reset-OMGModuleManifests'
            'Resolve-DnsName'
            'Set-AzContext'
            'Set-ExcelRange'
            'Start-ThreadJob'
            'terraform'
        )
        $requiredHelpTags = @('SYNOPSIS', 'DESCRIPTION', 'EXAMPLE', 'OUTPUTS', 'NOTES')
        $operatorNames = @(
            'as', 'contains', 'eq', 'ge', 'gt', 'in', 'is', 'isnot', 'join',
            'le', 'like', 'lt', 'match', 'ne', 'notcontains', 'notin',
            'notlike', 'notmatch', 'replace', 'split'
        )

        function ConvertTo-ArchitectureFunctionAst {
            param (
                [Parameter(Mandatory)]
                [string]$Source
            )

            $tokens = $null
            $parseErrors = $null
            $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput(
                $Source,
                [ref]$tokens,
                [ref]$parseErrors
            )
            if ($parseErrors.Count -gt 0) {
                throw "Fixture parse failed: $($parseErrors[0].Message)"
            }

            $functions = @($scriptAst.FindAll(
                    { param ($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
                    $true
                ))
            if ($functions.Count -ne 1) {
                throw "Expected one fixture function, found $($functions.Count)."
            }

            $functions[0]
        }

        function Test-ActionableCommandGuard {
            param (
                [Parameter(Mandatory)]
                [System.Management.Automation.Language.FunctionDefinitionAst]$FunctionAst,

                [Parameter()]
                [string]$CommandName
            )

            $availabilityChecks = @($FunctionAst.Body.FindAll(
                    {
                        param ($node)
                        $node -is [System.Management.Automation.Language.CommandAst] -and
                        $node.GetCommandName() -eq 'Get-Command'
                    },
                    $true
                ))
            if ($availabilityChecks.Count -eq 0) {
                return $false
            }

            if ($CommandName -and -not @($availabilityChecks | Where-Object {
                        $_.Extent.Text -match [regex]::Escape($CommandName)
                    })) {
                return $false
            }

            $failureGuidance = @($FunctionAst.Body.FindAll(
                    {
                        param ($node)
                        $node -is [System.Management.Automation.Language.ThrowStatementAst] -or
                        ($node -is [System.Management.Automation.Language.CommandAst] -and
                            $node.GetCommandName() -eq 'Write-Error')
                    },
                    $true
                ))

            [bool]@($failureGuidance | Where-Object {
                    $_.Extent.Text -match '(?i)\b(install|import|update|configure)\b'
                })
        }

        function Test-OperatorExpressionCommand {
            param (
                [Parameter(Mandatory)]
                [System.Management.Automation.Language.CommandAst]$CommandAst
            )

            $CommandAst.CommandElements.Count -gt 1 -and
            $CommandAst.CommandElements[1] -is [System.Management.Automation.Language.CommandParameterAst] -and
            $CommandAst.CommandElements[1].ParameterName -in $operatorNames
        }

        function Assert-FunctionCommandsResolve {
            param (
                [Parameter(Mandatory)]
                [System.Management.Automation.Language.FunctionDefinitionAst]$FunctionAst,

                [Parameter(Mandatory)]
                [AllowEmptyCollection()]
                [string[]]$KnownCommand,

                [Parameter(Mandatory)]
                [AllowEmptyCollection()]
                [string[]]$ApprovedExternalCommand
            )

            $unresolvedCommands = [System.Collections.Generic.List[string]]::new()
            $commandAsts = @($FunctionAst.Body.FindAll(
                    { param ($node) $node -is [System.Management.Automation.Language.CommandAst] },
                    $true
                ))

            foreach ($commandAst in $commandAsts) {
                if (Test-OperatorExpressionCommand -CommandAst $commandAst) {
                    continue
                }

                $commandName = $commandAst.GetCommandName()
                if (-not $commandName) {
                    if (-not (Test-ActionableCommandGuard -FunctionAst $FunctionAst)) {
                        $unresolvedCommands.Add("dynamic command at line $($commandAst.Extent.StartLineNumber)")
                    }
                    continue
                }

                if ($commandName -in $KnownCommand -or
                    $commandName -in $ApprovedExternalCommand -or
                    (Get-Command -Name $commandName -ErrorAction SilentlyContinue) -or
                    (Test-ActionableCommandGuard -FunctionAst $FunctionAst -CommandName $commandName)) {
                    continue
                }

                $unresolvedCommands.Add("$commandName at line $($commandAst.Extent.StartLineNumber)")
            }

            if ($unresolvedCommands.Count -gt 0) {
                throw "[$($FunctionAst.Name)] Unresolved command invocation(s): $($unresolvedCommands -join ', ')."
            }
        }

        function Assert-FunctionUsesShouldProcess {
            param (
                [Parameter(Mandatory)]
                [System.Management.Automation.Language.FunctionDefinitionAst]$FunctionAst
            )

            $supportsShouldProcess = @($FunctionAst.Body.ParamBlock.Attributes | Where-Object {
                    $_.TypeName.Name -eq 'CmdletBinding' -and
                    @($_.NamedArguments | Where-Object {
                            $_.ArgumentName -eq 'SupportsShouldProcess' -and
                            (-not $_.Argument -or $_.Argument.Extent.Text -ne '$false')
                        }).Count -gt 0
                }).Count -gt 0
            if (-not $supportsShouldProcess) {
                return
            }

            $shouldProcessCalls = @($FunctionAst.Body.FindAll(
                    {
                        param ($node)
                        $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                        $node.Member.Extent.Text -eq 'ShouldProcess'
                    },
                    $true
                ))
            if ($shouldProcessCalls.Count -eq 0) {
                throw "[$($FunctionAst.Name)] SupportsShouldProcess is declared without a ShouldProcess method call."
            }
        }

        function Assert-FunctionUsesApprovedVerb {
            param (
                [Parameter(Mandatory)]
                [System.Management.Automation.Language.FunctionDefinitionAst]$FunctionAst
            )

            $verb = ($FunctionAst.Name -split '-', 2)[0]
            if ($verb -notin @((Get-Verb).Verb)) {
                throw "[$($FunctionAst.Name)] '$verb' is not an approved PowerShell verb."
            }
        }

        $architectureRepositoryRoot = Split-Path -Parent $PSScriptRoot
        $knownCommands = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        $livePublicFunctions = [System.Collections.Generic.List[object]]::new()

        foreach ($moduleName in $liveModuleNames) {
            $modulePath = Join-Path $architectureRepositoryRoot $moduleName
            $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $modulePath "$moduleName.psd1")
            foreach ($exportName in @($manifest.FunctionsToExport) + @($manifest.CmdletsToExport) + @($manifest.AliasesToExport)) {
                if ($exportName) {
                    [void]$knownCommands.Add([string]$exportName)
                }
            }

            foreach ($scriptFile in (Get-ChildItem -LiteralPath $modulePath -Recurse -Filter '*.ps1' -File |
                    Where-Object { $_.Name -notlike '*--wip.ps1' })) {
                $tokens = $null
                $parseErrors = $null
                $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile(
                    $scriptFile.FullName,
                    [ref]$tokens,
                    [ref]$parseErrors
                )
                if ($parseErrors.Count -gt 0) {
                    throw "[$moduleName] Unable to parse '$($scriptFile.FullName)': $($parseErrors[0].Message)"
                }

                foreach ($functionAst in @($scriptAst.FindAll(
                            { param ($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
                            $true
                        ))) {
                    [void]$knownCommands.Add($functionAst.Name)
                }
            }

            foreach ($functionName in @($manifest.FunctionsToExport)) {
                $publicFile = Join-Path $modulePath "Public/$functionName.ps1"
                $content = Get-Content -LiteralPath $publicFile -Raw
                $tokens = $null
                $parseErrors = $null
                $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput(
                    $content,
                    [ref]$tokens,
                    [ref]$parseErrors
                )
                if ($parseErrors.Count -gt 0) {
                    throw "[$moduleName] Unable to parse '$publicFile': $($parseErrors[0].Message)"
                }

                $functionAst = $scriptAst.Find(
                    {
                        param ($node)
                        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                        $node.Name -eq $functionName
                    },
                    $true
                )
                $livePublicFunctions.Add([PSCustomObject]@{
                        Content      = $content
                        FunctionAst  = $functionAst
                        RelativePath = [System.IO.Path]::GetRelativePath(
                            $architectureRepositoryRoot,
                            $publicFile
                        ).Replace('\', '/')
                    })
            }
        }
    }

    It 'resolves commands invoked by every live EIGHT-scope public function' {
        $violations = @($livePublicFunctions | ForEach-Object {
                try {
                    Assert-FunctionCommandsResolve `
                        -FunctionAst $_.FunctionAst `
                        -KnownCommand @($knownCommands) `
                        -ApprovedExternalCommand $approvedExternalCommands
                } catch {
                    "$($_.RelativePath): $($_.Exception.Message)"
                }
            })

        $violations | Should -BeNullOrEmpty
    }

    It 'requires a ShouldProcess method call when SupportsShouldProcess is declared' {
        $violations = @($livePublicFunctions | ForEach-Object {
                try {
                    Assert-FunctionUsesShouldProcess -FunctionAst $_.FunctionAst
                } catch {
                    "$($_.RelativePath): $($_.Exception.Message)"
                }
            })

        $violations | Should -BeNullOrEmpty
    }

    It 'uses approved verbs for every live EIGHT-scope public function' {
        $violations = @($livePublicFunctions | ForEach-Object {
                try {
                    Assert-FunctionUsesApprovedVerb -FunctionAst $_.FunctionAst
                } catch {
                    "$($_.RelativePath): $($_.Exception.Message)"
                }
            })

        $violations | Should -BeNullOrEmpty
    }

    It 'retains all required comment-based help tags' {
        $violations = @($livePublicFunctions | ForEach-Object {
                $functionRecord = $_
                $missingTags = @($requiredHelpTags | Where-Object {
                        $functionRecord.Content -notmatch "(?im)^\s*\.$_\b"
                    })
                if ($missingTags.Count -gt 0) {
                    "$($functionRecord.RelativePath): missing $($missingTags -join ', ')"
                }
            })

        $violations | Should -BeNullOrEmpty
    }

    It 'rejects an unresolved command fixture' {
        $functionAst = ConvertTo-ArchitectureFunctionAst -Source @'
function Get-ArchitectureFixture {
    Invoke-MissingArchitectureFixture
}
'@

        {
            Assert-FunctionCommandsResolve `
                -FunctionAst $functionAst `
                -KnownCommand @() `
                -ApprovedExternalCommand @()
        } | Should -Throw '*Invoke-MissingArchitectureFixture*'
    }

    It 'rejects a SupportsShouldProcess fixture without a method call' {
        $functionAst = ConvertTo-ArchitectureFunctionAst -Source @'
function Set-ArchitectureFixture {
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    Write-Output 'changed'
}
'@

        { Assert-FunctionUsesShouldProcess -FunctionAst $functionAst } |
            Should -Throw '*without a ShouldProcess method call*'
    }

    It 'rejects an unapproved verb fixture' {
        $functionAst = ConvertTo-ArchitectureFunctionAst -Source @'
function Frobnicate-ArchitectureFixture {
    'fixture'
}
'@

        { Assert-FunctionUsesApprovedVerb -FunctionAst $functionAst } |
            Should -Throw "*'Frobnicate' is not an approved PowerShell verb*"
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

Describe 'PSScriptAnalyzer warning ratchet' {
    BeforeAll {
        $warningRatchetRepositoryRoot = Split-Path -Parent $PSScriptRoot
        $testRepositoryPath = Join-Path $warningRatchetRepositoryRoot 'build/Test-Repository.ps1'

        function New-WarningRatchetFixture {
            param (
                [Parameter(Mandatory)]
                [string]$RootPath
            )

            $fixturePath = Join-Path $RootPath 'warning-ratchet'
            $moduleName = 'OMG.PSUtilities.Fixture'
            $modulePath = Join-Path $fixturePath $moduleName
            $publicPath = Join-Path $modulePath 'Public'
            New-Item -Path $publicPath -ItemType Directory -Force | Out-Null
            Copy-Item `
                -LiteralPath (Join-Path $warningRatchetRepositoryRoot 'PSScriptAnalyzerSettings.psd1') `
                -Destination $fixturePath

            Set-Content -LiteralPath (Join-Path $modulePath "$moduleName.psd1") -Value @"
@{
    RootModule = '$moduleName.psm1'
    ModuleVersion = '1.0.0'
    GUID = '22fc9f20-9700-4078-a967-cd82c5a9c9c1'
    Author = 'Architecture Test'
    Description = 'Warning ratchet fixture'
    FunctionsToExport = @('Get-WarningRatchetFixture')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
"@
            Set-Content `
                -LiteralPath (Join-Path $modulePath "$moduleName.psm1") `
                -Value ". '`$PSScriptRoot/Public/Get-WarningRatchetFixture.ps1'"
            $publicFile = Join-Path $publicPath 'Get-WarningRatchetFixture.ps1'
            Set-Content -LiteralPath $publicFile -Value @'
function Get-WarningRatchetFixture {
    <#
    .SYNOPSIS
        Returns fixture output.
    .DESCRIPTION
        Produces one deliberate analyzer warning for baseline testing.
    .EXAMPLE
        Get-WarningRatchetFixture
    .OUTPUTS
        None
    .NOTES
        Test fixture only.
    #>
    [CmdletBinding()]
    param ()

    Write-Host 'existing baseline warning'
}
'@

            [PSCustomObject]@{
                BaselinePath  = Join-Path $fixturePath 'warning-baseline.json'
                PublicFile    = $publicFile
                RepositoryRoot = $fixturePath
            }
        }
    }

    It 'blocks a new warning and records warning removal' {
        $fixture = New-WarningRatchetFixture -RootPath $TestDrive
        $initialResult = & $testRepositoryPath `
            -RepositoryRoot $fixture.RepositoryRoot `
            -WarningBaseline $fixture.BaselinePath `
            -UpdateWarningBaseline `
            -WarningAction SilentlyContinue
        $initialBaseline = Get-Content -LiteralPath $fixture.BaselinePath -Raw | ConvertFrom-Json

        $initialResult.NewAnalyzerWarnings | Should -Be 0
        $initialBaseline.warningCount | Should -BeGreaterThan 0

        $content = Get-Content -LiteralPath $fixture.PublicFile -Raw
        $content = $content.Replace(
            "    Write-Host 'existing baseline warning'",
            "    Write-Host 'existing baseline warning'`n    Write-Host 'new unbaselined warning'"
        )
        Set-Content -LiteralPath $fixture.PublicFile -Value $content

        {
            & $testRepositoryPath `
                -RepositoryRoot $fixture.RepositoryRoot `
                -WarningBaseline $fixture.BaselinePath `
                -IncludeScriptAnalyzer `
                -WarningAction SilentlyContinue | Out-Null
        } | Should -Throw '*Repository validation failed*'

        $content = $content.Replace("`n    Write-Host 'new unbaselined warning'", '')
        Set-Content -LiteralPath $fixture.PublicFile -Value $content
        $restoredResult = & $testRepositoryPath `
            -RepositoryRoot $fixture.RepositoryRoot `
            -WarningBaseline $fixture.BaselinePath `
            -IncludeScriptAnalyzer `
            -WarningAction SilentlyContinue
        $restoredResult.NewAnalyzerWarnings | Should -Be 0

        $content = $content.Replace(
            "    Write-Host 'existing baseline warning'",
            "    Write-Output 'warning removed'"
        )
        Set-Content -LiteralPath $fixture.PublicFile -Value $content
        & $testRepositoryPath `
            -RepositoryRoot $fixture.RepositoryRoot `
            -WarningBaseline $fixture.BaselinePath `
            -UpdateWarningBaseline `
            -WarningAction SilentlyContinue | Out-Null
        $reducedBaseline = Get-Content -LiteralPath $fixture.BaselinePath -Raw | ConvertFrom-Json

        $reducedBaseline.warningCount | Should -BeLessThan $initialBaseline.warningCount
    }
}
