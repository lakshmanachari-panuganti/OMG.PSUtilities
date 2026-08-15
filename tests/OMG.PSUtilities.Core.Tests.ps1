# Regression tests for OMG.PSUtilities.Core.

BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $env:PSModulePath = "$repositoryRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    $moduleManifestPath = if ($env:PSU_CORE_TEST_MANIFEST) {
        $env:PSU_CORE_TEST_MANIFEST
    } else {
        Join-Path $repositoryRoot 'OMG.PSUtilities.Core\OMG.PSUtilities.Core.psd1'
    }
    Remove-Module OMG.PSUtilities.Core -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifestPath -Force
}

Describe 'Core pull request dispatcher guards' {
    It 'routes GitHub approval with mapped parameters' {
        InModuleScope OMG.PSUtilities.Core {
            Mock Write-Host {}
            Mock git { 'https://github.com/example/repository.git' }
            Mock Approve-PSUGithubPullRequest { 'github-approved' }

            Approve-PSUPullRequest -PullRequestId 42 -Comment 'Approved' | Should -Be 'github-approved'

            Should -Invoke Approve-PSUGithubPullRequest -Times 1 -Exactly -ParameterFilter {
                $PullRequestNumber -eq 42 -and
                $ReviewState -eq 'APPROVE' -and
                $Comment -eq 'Approved'
            }
        }
    }

    It 'routes Azure DevOps approval with mapped parameters' {
        InModuleScope OMG.PSUtilities.Core {
            function Approve-PSUADOPullRequest { }

            Mock Write-Host {}
            Mock git { 'https://dev.azure.com/example/project/_git/repository' }
            $script:adoApprovalParameters = $null
            Mock Approve-PSUADOPullRequest {
                $script:adoApprovalParameters = [pscustomobject]@{
                    PullRequestId = $PullRequestId
                    Vote = $Vote
                    Comment = $Comment
                }
                'ado-approved'
            }

            Approve-PSUPullRequest -PullRequestId 42 -Comment 'Approved' | Should -Be 'ado-approved'

            $script:adoApprovalParameters.PullRequestId | Should -Be 42
            $script:adoApprovalParameters.Vote | Should -Be 10
            $script:adoApprovalParameters.Comment | Should -Be 'Approved'
        }
    }

    It 'routes GitHub completion with mapped parameters' {
        InModuleScope OMG.PSUtilities.Core {
            Mock Write-Host {}
            Mock git { 'git@github.com:example/repository.git' }
            $script:githubCompletionParameters = $null
            Mock Complete-PSUGithubPullRequest {
                $script:githubCompletionParameters = [pscustomobject]@{
                    PullRequestNumber = $PullRequestNumber
                    MergeMethod = $MergeMethod
                    DeleteBranch = $DeleteBranch
                }
                'github-completed'
            }

            Complete-PSUPullRequest -PullRequestId 42 -MergeStrategy squash -DeleteSourceBranch | Should -Be 'github-completed'

            $script:githubCompletionParameters.PullRequestNumber | Should -Be 42
            $script:githubCompletionParameters.MergeMethod | Should -Be 'squash'
            $script:githubCompletionParameters.DeleteBranch | Should -BeTrue
        }
    }

    It 'routes Azure DevOps completion with mapped parameters' {
        InModuleScope OMG.PSUtilities.Core {
            function Complete-PSUADOPullRequest { }

            Mock Write-Host {}
            Mock git { 'https://example.visualstudio.com/project/_git/repository' }
            $script:adoCompletionParameters = $null
            Mock Complete-PSUADOPullRequest {
                $script:adoCompletionParameters = [pscustomobject]@{
                    PullRequestId = $PullRequestId
                    MergeStrategy = $MergeStrategy
                    DeleteSourceBranch = $DeleteSourceBranch
                }
                'ado-completed'
            }

            Complete-PSUPullRequest -PullRequestId 42 -MergeStrategy rebaseMerge -DeleteSourceBranch | Should -Be 'ado-completed'

            $script:adoCompletionParameters.PullRequestId | Should -Be 42
            $script:adoCompletionParameters.MergeStrategy | Should -Be 'rebaseMerge'
            $script:adoCompletionParameters.DeleteSourceBranch | Should -BeTrue
        }
    }

    It 'guides users when GitHub approval support is unavailable' {
        InModuleScope OMG.PSUtilities.Core {
            Mock Write-Host {}
            Mock git { 'https://github.com/example/repository.git' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Approve-PSUGithubPullRequest' }

            $errorRecord = { Approve-PSUPullRequest -PullRequestId 42 } | Should -Throw -PassThru

            $errorRecord.Exception.Message | Should -Match 'OMG\.PSUtilities\.Core'
            $errorRecord.Exception.Message | Should -Match 'Update-Module|Install-Module'
        }
    }

    It 'guides users when Azure DevOps approval support is unavailable' {
        InModuleScope OMG.PSUtilities.Core {
            Mock Write-Host {}
            Mock git { 'https://dev.azure.com/example/project/_git/repository' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Approve-PSUADOPullRequest' }

            $errorRecord = { Approve-PSUPullRequest -PullRequestId 42 } | Should -Throw -PassThru

            $errorRecord.Exception.Message | Should -Match 'OMG\.PSUtilities\.AzureDevOps'
            $errorRecord.Exception.Message | Should -Match 'Install-Module'
            $errorRecord.Exception.Message | Should -Match 'Import-Module'
        }
    }

    It 'guides users when GitHub completion support is unavailable' {
        InModuleScope OMG.PSUtilities.Core {
            Mock Write-Host {}
            Mock git { 'git@github.com:example/repository.git' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Complete-PSUGithubPullRequest' }

            $errorRecord = { Complete-PSUPullRequest -PullRequestId 42 } | Should -Throw -PassThru

            $errorRecord.Exception.Message | Should -Match 'OMG\.PSUtilities\.Core'
            $errorRecord.Exception.Message | Should -Match 'Update-Module|Install-Module'
        }
    }

    It 'guides users when Azure DevOps completion support is unavailable' {
        InModuleScope OMG.PSUtilities.Core {
            Mock Write-Host {}
            Mock git { 'https://example.visualstudio.com/project/_git/repository' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Complete-PSUADOPullRequest' }

            $errorRecord = { Complete-PSUPullRequest -PullRequestId 42 } | Should -Throw -PassThru

            $errorRecord.Exception.Message | Should -Match 'OMG\.PSUtilities\.AzureDevOps'
            $errorRecord.Exception.Message | Should -Match 'Install-Module'
            $errorRecord.Exception.Message | Should -Match 'Import-Module'
        }
    }

    It 'rejects a missing origin remote before dispatch' {
        InModuleScope OMG.PSUtilities.Core {
            Mock git { $null }

            { Approve-PSUPullRequest -PullRequestId 42 } | Should -Throw '*No git remote origin found*'
        }
    }

    It 'rejects an unsupported origin provider before dispatch' {
        InModuleScope OMG.PSUtilities.Core {
            Mock git { 'https://gitlab.com/example/repository.git' }

            { Complete-PSUPullRequest -PullRequestId 42 } | Should -Throw '*Unsupported git provider*'
        }
    }
}

Describe 'Complete-PSUGithubPullRequest' {
    It 'merges an open pull request with the selected method' {
        InModuleScope OMG.PSUtilities.Core {
            Mock Write-Host {}
            Mock Invoke-RestMethod {
                if ($Method -eq 'Get') {
                    return [pscustomobject]@{
                        state = 'open'
                        html_url = 'https://github.com/example/repository/pull/42'
                        head = [pscustomobject]@{ ref = 'feature/test' }
                        base = [pscustomobject]@{ ref = 'main' }
                    }
                }
                return [pscustomobject]@{
                    merged = $true
                    sha = 'merge-sha'
                    message = 'Pull Request successfully merged'
                }
            }

            $result = Complete-PSUGithubPullRequest `
                -Owner 'example' `
                -Repository 'repository' `
                -PullRequestNumber 42 `
                -MergeMethod squash `
                -Token 'test-token' `
                -Confirm:$false

            $result.Merged | Should -BeTrue
            $result.MergeMethod | Should -Be 'squash'
            $result.MergeCommitSha | Should -Be 'merge-sha'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Put' -and $Uri -like '*/pulls/42/merge'
            }
        }
    }
}

Describe 'Core WhatIf guards' {
    It 'does not call GitHub under WhatIf' {
        InModuleScope OMG.PSUtilities.Core {
            Mock Invoke-RestMethod { throw 'GitHub must not be called under WhatIf.' }

            New-PSUGithubPullRequest `
                -Owner 'example' `
                -Repository 'repository' `
                -SourceBranch 'feature/test' `
                -TargetBranch 'main' `
                -Title 'Test pull request' `
                -Description 'Test description' `
                -Token 'test-token' `
                -WhatIf

            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }
    }

    It 'does not import Graph or create a meeting under WhatIf' {
        InModuleScope OMG.PSUtilities.Core {
            function New-MgUserEvent { }

            Mock Get-Module { [pscustomobject]@{ Name = 'Microsoft.Graph.Calendar' } } -ParameterFilter { $ListAvailable }
            Mock Get-Module { $null } -ParameterFilter { -not $ListAvailable }
            Mock Import-Module {}
            Mock New-MgUserEvent { throw 'Microsoft Graph must not be called under WhatIf.' }

            New-PSUOutlookMeeting `
                -Subject 'Test meeting' `
                -StartTime '2026-08-16 10:00' `
                -EndTime '2026-08-16 10:30' `
                -User 'user@example.com' `
                -WhatIf

            Should -Invoke Import-Module -Times 0 -Exactly
            Should -Invoke New-MgUserEvent -Times 0 -Exactly
        }
    }

    It 'does not initialize, select, or unlock Terraform under WhatIf' {
        $terraformPath = Join-Path $TestDrive 'terraform'
        New-Item -Path $terraformPath -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $terraformPath 'main.tf') -Value 'terraform { backend "s3" {} }'

        InModuleScope OMG.PSUtilities.Core -Parameters @{ TerraformPath = $terraformPath } {
            param ($TerraformPath)

            function terraform { }

            Mock Write-Host {}
            Mock Set-Location {}
            Mock terraform {
                $global:LASTEXITCODE = 0
                if ("$args" -eq 'workspace list') {
                    '* default'
                }
            }

            Unlock-PSUTerraformStateAWS `
                -Path $TerraformPath `
                -LockId 'lock-id' `
                -AccessKey 'access-key' `
                -SecretKey 'secret-key' `
                -Force `
                -WhatIf

            Should -Invoke Set-Location -Times 0 -Exactly
            Should -Invoke terraform -Times 0 -Exactly
        }
    }
}

Describe 'Update-OMGModuleVersion manifest integrity' {
    It 'updates only the top-level ModuleVersion assignment' {
        $moduleName = 'Fixture.Module'
        $modulePath = Join-Path $TestDrive $moduleName
        $manifestPath = Join-Path $modulePath "$moduleName.psd1"
        New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
        Set-Content -Path $manifestPath -Value @'
@{
ModuleVersion = '1.0.0'
RequiredModules = @(
    @{ ModuleName = 'ImportExcel'; ModuleVersion = '7.8.9' }
)
}
'@

        $previousBaseModulePath = $env:BASE_MODULE_PATH
        try {
            $env:BASE_MODULE_PATH = $TestDrive
            InModuleScope OMG.PSUtilities.Core -Parameters @{ ModuleName = $moduleName } {
                param ($ModuleName)

                Mock Find-Module { [pscustomobject]@{ Version = [version]'1.0.0' } }
                Mock Write-Host {}
                Mock Write-Warning {}

                Update-OMGModuleVersion -ModuleName $ModuleName -Increment Patch
            }
        } finally {
            $env:BASE_MODULE_PATH = $previousBaseModulePath
        }

        $updatedManifest = Get-Content -Path $manifestPath -Raw
        $updatedManifest | Should -Match "(?m)^ModuleVersion = '1\.0\.1'\r?$"
        $updatedManifest | Should -Match "ModuleName = 'ImportExcel'; ModuleVersion = '7\.8\.9'"
    }
}

Describe 'Unlock-PSUTerraformStateAWS credential isolation' {
    BeforeAll {
        $script:hadOriginalAccessKey = Test-Path Env:\AWS_ACCESS_KEY_ID
        $script:hadOriginalSecretKey = Test-Path Env:\AWS_SECRET_ACCESS_KEY
        $script:originalAccessKey = $env:AWS_ACCESS_KEY_ID
        $script:originalSecretKey = $env:AWS_SECRET_ACCESS_KEY
    }

    BeforeEach {
        $script:terraformPath = Join-Path $TestDrive 'terraform-secrets'
        New-Item -Path $script:terraformPath -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $script:terraformPath 'main.tf') -Value 'terraform { backend "s3" {} }'
        $script:accessKey = 'ACCESS-KEY-SENTINEL'
        $script:secretKey = 'SECRET-KEY-SENTINEL'
        $env:AWS_ACCESS_KEY_ID = 'prior-access'
        $env:AWS_SECRET_ACCESS_KEY = 'prior-secret'
    }

    It 'uses child-process environment credentials without putting them in argv' {
        InModuleScope OMG.PSUtilities.Core -Parameters @{
            TerraformPath = $script:terraformPath
            AccessKey = $script:accessKey
            SecretKey = $script:secretKey
        } {
            param ($TerraformPath, $AccessKey, $SecretKey)

            function terraform { }

            $script:terraformCalls = [System.Collections.Generic.List[string]]::new()
            $script:terraformEnvironments = [System.Collections.Generic.List[string]]::new()
            Mock Write-Host {}
            Mock Set-Location {}
            Mock terraform {
                $script:terraformCalls.Add("$args")
                $script:terraformEnvironments.Add("$env:AWS_ACCESS_KEY_ID|$env:AWS_SECRET_ACCESS_KEY")
                $global:LASTEXITCODE = 0
                if ("$args" -eq 'workspace list') {
                    '* default'
                }
            }

            Unlock-PSUTerraformStateAWS `
                -Path $TerraformPath `
                -LockId 'lock-id' `
                -AccessKey $AccessKey `
                -SecretKey $SecretKey `
                -Force

            ($script:terraformCalls -join "`n") | Should -Not -Match ([regex]::Escape($AccessKey))
            ($script:terraformCalls -join "`n") | Should -Not -Match ([regex]::Escape($SecretKey))
            $script:terraformEnvironments | Should -Contain "$AccessKey|$SecretKey"
        }

        $env:AWS_ACCESS_KEY_ID | Should -Be 'prior-access'
        $env:AWS_SECRET_ACCESS_KEY | Should -Be 'prior-secret'
    }

    It 'redacts credentials from Terraform failures and restores the environment' {
        InModuleScope OMG.PSUtilities.Core -Parameters @{
            TerraformPath = $script:terraformPath
            AccessKey = $script:accessKey
            SecretKey = $script:secretKey
        } {
            param ($TerraformPath, $AccessKey, $SecretKey)

            function terraform { }

            Mock Write-Host {}
            Mock Write-Error {}
            Mock Set-Location {}
            Mock terraform {
                $global:LASTEXITCODE = 1
                "Terraform failed with $AccessKey and $SecretKey"
            }

            $errorRecord = {
                Unlock-PSUTerraformStateAWS `
                    -Path $TerraformPath `
                    -LockId 'lock-id' `
                    -AccessKey $AccessKey `
                    -SecretKey $SecretKey `
                    -Force
            } | Should -Throw -PassThru

            $errorRecord.Exception.Message | Should -Not -Match ([regex]::Escape($AccessKey))
            $errorRecord.Exception.Message | Should -Not -Match ([regex]::Escape($SecretKey))
        }

        $env:AWS_ACCESS_KEY_ID | Should -Be 'prior-access'
        $env:AWS_SECRET_ACCESS_KEY | Should -Be 'prior-secret'
    }

    AfterAll {
        if ($script:hadOriginalAccessKey) {
            $env:AWS_ACCESS_KEY_ID = $script:originalAccessKey
        } else {
            Remove-Item Env:\AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue
        }
        if ($script:hadOriginalSecretKey) {
            $env:AWS_SECRET_ACCESS_KEY = $script:originalSecretKey
        } else {
            Remove-Item Env:\AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
        }
    }
}