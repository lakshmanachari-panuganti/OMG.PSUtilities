# Regression tests for OMG.PSUtilities.AzureDevOps.
# Every HTTP call is mocked - these must never touch a real Azure DevOps endpoint.

BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $env:PSModulePath = "$repositoryRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    $moduleManifestPath = if ($env:PSU_AZUREDEVOPS_TEST_MANIFEST) {
        $env:PSU_AZUREDEVOPS_TEST_MANIFEST
    } else {
        Join-Path $repositoryRoot 'OMG.PSUtilities.AzureDevOps\OMG.PSUtilities.AzureDevOps.psd1'
    }
    Remove-Module OMG.PSUtilities.AzureDevOps -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifestPath -Force
}

Describe 'Set-PSUADOVariableGroup' {
    It 'preserves variables, secret flags, type, and provider data' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Mock Write-PSUAdoParameterTrace {}
            Mock Confirm-PSUAdoConnectionParameter {}
            Mock Get-PSUAdoAuthHeader { @{ Authorization = 'Basic test' } }
            Mock Get-PSUADOVariableGroup { [pscustomobject]@{ Id = 42; Name = 'Production' } }
            $script:putBody = $null
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Put' } -MockWith {
                $script:putBody = $Body
            }

            $inputObject = [pscustomobject]@{
                Id           = 42
                Name         = 'Production'
                Description  = 'Production variables'
                Project      = 'Platform Project'
                Type         = 'AzureKeyVault'
                ProviderData = [pscustomobject]@{
                    serviceEndpointId = 'endpoint-id'
                    vault             = 'production-vault'
                }
                Variables    = [pscustomobject]@{
                    Region = [pscustomobject]@{
                        value    = 'centralus'
                        isSecret = $false
                    }
                    ApiKey = [pscustomobject]@{
                        value    = $null
                        isSecret = $true
                    }
                }
            }

            $null = $inputObject | Set-PSUADOVariableGroup -Organization 'contoso' -PAT 'pat' -Confirm:$false

            $payload = $script:putBody | ConvertFrom-Json
            @($payload.variables.PSObject.Properties).Count | Should -Be 2
            $payload.variables.Region.value | Should -Be 'centralus'
            $payload.variables.Region.isSecret | Should -BeFalse
            $payload.variables.ApiKey.isSecret | Should -BeTrue
            $payload.type | Should -Be 'AzureKeyVault'
            $payload.providerData.serviceEndpointId | Should -Be 'endpoint-id'
            $payload.providerData.vault | Should -Be 'production-vault'
        }
    }

    It 'rejects a Key Vault group with no provider data' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Mock Write-PSUAdoParameterTrace {}
            Mock Confirm-PSUAdoConnectionParameter {}
            Mock Get-PSUAdoAuthHeader { @{ Authorization = 'Basic test' } }
            Mock Invoke-RestMethod {}
            Mock Get-PSUADOVariableGroup {}

            $inputObject = [pscustomobject]@{
                Id          = 42
                Name        = 'Production'
                Description = 'Production variables'
                Project     = 'Platform'
                Type        = 'AzureKeyVault'
                Variables   = [pscustomobject]@{}
            }

            {
                $inputObject | Set-PSUADOVariableGroup -Organization 'contoso' -PAT 'pat' -Confirm:$false
            } | Should -Throw '*providerData*'
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }
    }

    It 'does not update or refresh a variable group under WhatIf' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Mock Write-PSUAdoParameterTrace {}
            Mock Confirm-PSUAdoConnectionParameter {}
            Mock Get-PSUAdoAuthHeader { @{ Authorization = 'Basic test' } }
            Mock Invoke-RestMethod {}
            Mock Get-PSUADOVariableGroup { [pscustomobject]@{ Id = 42; Name = 'Production' } }

            $inputObject = [pscustomobject]@{
                Id          = 42
                Name        = 'Production'
                Description = 'Production variables'
                Project     = 'Platform'
                Type        = 'Vsts'
                Variables   = [pscustomobject]@{}
            }

            $result = $inputObject | Set-PSUADOVariableGroup -Organization 'contoso' -PAT 'pat' -WhatIf

            $result | Should -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
            Should -Invoke Get-PSUADOVariableGroup -Times 0 -Exactly
        }
    }
}

Describe 'Complete-PSUADOPullRequest' {
    BeforeEach {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Mock Write-PSUAdoParameterTrace {}
            Mock Confirm-PSUAdoConnectionParameter {}
            Mock Get-PSUAdoAuthHeader { @{ Authorization = 'Basic test' } }
            Mock Get-PSUADORepositories { @([pscustomobject]@{ Name = 'Widget'; Id = 'repo-id' }) }
            Mock Write-Host {}
            $script:completionBody = $null
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } -MockWith {
                [pscustomobject]@{
                    lastMergeSourceCommit = [pscustomobject]@{ commitId = 'source-commit' }
                }
            }
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Patch' } -MockWith {
                $script:completionBody = $Body
                [pscustomobject]@{
                    pullRequestId = 17
                    status        = 'completed'
                    title         = 'Ship widget'
                    sourceRefName = 'refs/heads/feature/widget'
                    targetRefName = 'refs/heads/main'
                    closedBy      = [pscustomobject]@{ displayName = 'Reviewer' }
                    closedDate    = '2026-08-15T00:00:00Z'
                    mergeId       = 'merge-id'
                }
            }
        }
    }

    It 'preserves caller options and lets explicit parameters take precedence' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            $options = @{
                bypassPolicy       = $true
                bypassReason       = 'Emergency release'
                mergeStrategy      = 'squash'
                deleteSourceBranch = $false
            }

            $null = Complete-PSUADOPullRequest `
                -Project 'Platform' `
                -Repository 'Widget' `
                -PullRequestId 17 `
                -CompletionOptions $options `
                -MergeStrategy rebase `
                -DeleteSourceBranch `
                -Organization 'contoso' `
                -PAT 'pat'

            $payload = $script:completionBody | ConvertFrom-Json
            $payload.completionOptions.bypassPolicy | Should -BeTrue
            $payload.completionOptions.bypassReason | Should -Be 'Emergency release'
            $payload.completionOptions.mergeStrategy | Should -Be 'rebase'
            $payload.completionOptions.deleteSourceBranch | Should -BeTrue
        }
    }

    It 'keeps the caller merge strategy when the explicit parameter is omitted' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            $null = Complete-PSUADOPullRequest `
                -Project 'Platform' `
                -Repository 'Widget' `
                -PullRequestId 17 `
                -CompletionOptions @{ mergeStrategy = 'squash'; transitionWorkItems = $true } `
                -Organization 'contoso' `
                -PAT 'pat'

            $payload = $script:completionBody | ConvertFrom-Json
            $payload.completionOptions.mergeStrategy | Should -Be 'squash'
            $payload.completionOptions.transitionWorkItems | Should -BeTrue
        }
    }
}

Describe 'New-PSUADOPullRequest' {
    It 'does not create or auto-complete a pull request under WhatIf' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Mock git { @('feature/widget', 'main') }
            Mock Write-PSUAdoParameterTrace {}
            Mock Confirm-PSUAdoConnectionParameter {}
            Mock Get-PSUAdoAuthHeader { @{ Authorization = 'Basic test' } }
            Mock Get-PSUADORepositories { @([pscustomobject]@{ Name = 'Widget'; Id = 'repo-id' }) }
            Mock Write-Host {}
            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    pullRequestId = 17
                    isDraft       = $false
                    createdBy     = [pscustomobject]@{
                        id          = 'creator-id'
                        displayName = 'Creator'
                        uniqueName  = 'creator@example.com'
                    }
                    completionOptions = [pscustomobject]@{ mergeStrategy = 'noFastForward' }
                    repository        = [pscustomobject]@{
                        id      = 'repo-id'
                        name    = 'Widget'
                        project = [pscustomobject]@{ name = 'Platform' }
                    }
                }
            }

            $result = New-PSUADOPullRequest `
                -Project 'Platform' `
                -RepositoryName 'Widget' `
                -SourceBranch 'feature/widget' `
                -TargetBranch 'main' `
                -Title 'Ship widget' `
                -Description 'Ready to ship' `
                -CompleteOnApproval `
                -Organization 'contoso' `
                -PAT 'pat' `
                -WhatIf

            $result | Should -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }
    }
}

Describe 'Get-PSUADOVariableGroupInventory optional ThreadJob dependency' {
    # ThreadJob is intentionally absent from RequiredModules. That is only defensible while
    # the sequential fallback actually works, so these tests exercise it directly.
    BeforeEach {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Mock Write-Host {}
            Mock Write-Progress {}
            Mock Write-Warning {}
            Mock Confirm-PSUAdoConnectionParameter {}
            Mock Get-PSUAdoAuthHeader { @{ Authorization = 'Basic x' } }
        }
    }

    It 'still returns inventory when the ThreadJob module is unavailable' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Mock Get-Module { $null } -ParameterFilter { $ListAvailable -and $Name -eq 'ThreadJob' }

            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/_apis/projects*' } -MockWith {
                @{ value = @(
                        [pscustomobject]@{ name = 'Alpha'; id = 'id-alpha' }
                        [pscustomobject]@{ name = 'Beta'; id = 'id-beta' }
                    )
                }
            }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*distributedtask/variablegroups*' } -MockWith {
                @{ value = @([pscustomobject]@{ id = 7; name = 'shared-vg'; variables = [pscustomobject]@{} }) }
            }

            $result = @(Get-PSUADOVariableGroupInventory -Organization 'contoso' -PAT 'pat')

            # Two projects, one variable group each, produced without ThreadJob.
            $result.Count | Should -Be 2
            $result.VariableGroupName | Should -Contain 'shared-vg'
        }
    }

    It 'does not start a thread job when the module is unavailable' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Mock Get-Module { $null } -ParameterFilter { $ListAvailable -and $Name -eq 'ThreadJob' }
            Mock Start-ThreadJob { throw 'Sequential fallback must not start a thread job.' }

            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/_apis/projects*' } -MockWith {
                @{ value = @(
                        [pscustomobject]@{ name = 'Alpha'; id = 'id-alpha' }
                        [pscustomobject]@{ name = 'Beta'; id = 'id-beta' }
                    )
                }
            }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*distributedtask/variablegroups*' } -MockWith {
                @{ value = @() }
            }

            { Get-PSUADOVariableGroupInventory -Organization 'contoso' -PAT 'pat' } | Should -Not -Throw
            Should -Invoke Start-ThreadJob -Times 0 -Exactly
        }
    }
}

Describe 'Azure DevOps PAT handling (9.4a)' {
    BeforeEach {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            $script:sentinelPat = 'SENTINEL-PAT-0xC0FFEE'
            $script:hostMessages = @()
            $script:verboseMessages = @()
            Mock Write-Host { $script:hostMessages += [string]$Object }
            Mock Write-Verbose { $script:verboseMessages += [string]$Message }
        }
    }

    AfterEach {
        Remove-Item Env:\PAT -ErrorAction SilentlyContinue
    }

    It 'resolves a stored PAT when no environment variable is configured' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Remove-Item Env:\PAT -ErrorAction SilentlyContinue
            Mock Get-PSUSecret { $script:sentinelPat }

            $headers = Get-PSUAdoAuthHeader

            Should -Invoke Get-PSUSecret -Times 1
            $headers.Authorization | Should -Match '^Basic '
        }
    }

    It 'builds the same header the API expects from the resolved token' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Remove-Item Env:\PAT -ErrorAction SilentlyContinue
            Mock Get-PSUSecret { $script:sentinelPat }

            $headers = Get-PSUAdoAuthHeader
            $expected = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$script:sentinelPat"))

            $headers.Authorization | Should -Be "Basic $expected"
        }
    }

    It 'keeps the PAT out of host and verbose output' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Remove-Item Env:\PAT -ErrorAction SilentlyContinue
            Mock Get-PSUSecret { $script:sentinelPat }

            $null = Get-PSUAdoAuthHeader

            ($script:hostMessages + $script:verboseMessages) -join "`n" |
                Should -Not -Match ([regex]::Escape($script:sentinelPat))
        }
    }

    It 'keeps the PAT out of the error raised when no token is available' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            Remove-Item Env:\PAT -ErrorAction SilentlyContinue
            Mock Get-PSUSecret { throw 'not stored' }

            $errorText = ''
            try { Get-PSUAdoAuthHeader -ErrorAction Stop } catch { $errorText = $_.Exception.Message }

            $errorText | Should -Match 'PAT is required'
            $errorText | Should -Not -Match ([regex]::Escape($script:sentinelPat))
        }
    }

    It 'still honours the environment variable during the compatibility window' {
        InModuleScope OMG.PSUtilities.AzureDevOps {
            $env:PAT = $script:sentinelPat
            Mock Get-PSUSecret { throw 'should not be consulted when the environment is set' }

            $headers = Get-PSUAdoAuthHeader
            $expected = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$script:sentinelPat"))

            $headers.Authorization | Should -Be "Basic $expected"
        }
    }

    It 'reveals no leading characters of the token in parameter traces' {
        # Masking that keeps a prefix narrows a brute-force search and lets a token be
        # correlated across logs, so no part of it may survive.
        $moduleRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'OMG.PSUtilities.AzureDevOps'
        $partialMasks = Get-ChildItem -Path $moduleRoot -Include '*.ps1' -Recurse |
            Select-String -Pattern 'Substring\(0,\s*\d+\)\s*\+\s*"\*'

        $partialMasks | Should -BeNullOrEmpty
    }
}
