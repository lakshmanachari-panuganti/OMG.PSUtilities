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
