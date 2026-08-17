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

Describe 'New-PSUGithubPullRequest auto-merge' {
    It 'enables auto-merge through GraphQL with the pull request node ID' {
        InModuleScope OMG.PSUtilities.Core {
            $script:graphqlBody = $null
            Mock Write-Host {}
            Mock Invoke-RestMethod {
                if ($Uri -eq 'https://api.github.com/graphql') {
                    $script:graphqlBody = $Body | ConvertFrom-Json
                    return [pscustomobject]@{
                        data = [pscustomobject]@{
                            enablePullRequestAutoMerge = [pscustomobject]@{
                                pullRequest = [pscustomobject]@{ number = 42 }
                            }
                        }
                    }
                }

                [pscustomobject]@{
                    number = 42
                    node_id = 'PR_node_id'
                    id = 1234
                    title = 'Test pull request'
                    body = 'Test description'
                    state = 'open'
                    draft = $false
                    head = [pscustomobject]@{ ref = 'feature/test' }
                    base = [pscustomobject]@{ ref = 'main' }
                    user = [pscustomobject]@{ login = 'example' }
                    html_url = 'https://github.com/example/repository/pull/42'
                    url = 'https://api.github.com/repos/example/repository/pulls/42'
                    mergeable = $true
                    mergeable_state = 'clean'
                    created_at = '2026-08-16T00:00:00Z'
                    updated_at = '2026-08-16T00:00:00Z'
                }
            }

            New-PSUGithubPullRequest `
                -Owner 'example' `
                -Repository 'repository' `
                -SourceBranch 'feature/test' `
                -TargetBranch 'main' `
                -Title 'Test pull request' `
                -Description 'Test description' `
                -Token 'test-token' `
                -CompleteOnApproval `
                -Confirm:$false | Out-Null

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Post' -and $Uri -eq 'https://api.github.com/graphql'
            }
            $script:graphqlBody.variables.pullRequestId | Should -Be 'PR_node_id'
            $script:graphqlBody.query | Should -Match 'enablePullRequestAutoMerge'
            $script:graphqlBody.query | Should -Match 'mergeMethod:\s*MERGE'
        }
    }
}

Describe 'Get-PSUGitFileChangeMetadata index safety' {
    It 'reports untracked files without changing the index' {
        $gitRepository = Join-Path $TestDrive 'git-metadata'
        New-Item -Path $gitRepository -ItemType Directory -Force | Out-Null
        git -C $gitRepository init --quiet
        git -C $gitRepository config user.name 'Core Tests'
        git -C $gitRepository config user.email 'core-tests@example.invalid'
        Set-Content -Path (Join-Path $gitRepository 'tracked.txt') -Value 'tracked'
        git -C $gitRepository add tracked.txt
        git -C $gitRepository commit --quiet -m 'Initial commit'
        git -C $gitRepository branch -M main
        git -C $gitRepository checkout --quiet -b feature/test
        Set-Content -Path (Join-Path $gitRepository 'untracked.txt') -Value 'untracked'

        Push-Location $gitRepository
        try {
            $stagedBefore = @(git diff --cached --name-only)
            $changes = @(Get-PSUGitFileChangeMetadata -BaseBranch main -FeatureBranch feature/test)
            $stagedAfter = @(git diff --cached --name-only)
        } finally {
            Pop-Location
        }

        $untrackedChange = $changes | Where-Object File -eq 'untracked.txt'
        $untrackedChange.TypeOfChange | Should -Be 'Untracked'
        ($stagedAfter -join "`n") | Should -Be ($stagedBefore -join "`n")
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
                -CompleteOnApproval `
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

            $accessKey = ConvertTo-SecureString 'access-key' -AsPlainText -Force
            $secretKey = ConvertTo-SecureString 'secret-key' -AsPlainText -Force

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
                -AccessKey $accessKey `
                -SecretKey $secretKey `
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
        $script:secureAccessKey = ConvertTo-SecureString $script:accessKey -AsPlainText -Force
        $script:secureSecretKey = ConvertTo-SecureString $script:secretKey -AsPlainText -Force
        $env:AWS_ACCESS_KEY_ID = 'prior-access'
        $env:AWS_SECRET_ACCESS_KEY = 'prior-secret'
    }

    It 'requires SecureString credentials and documents secure interactive acquisition' {
        $command = Get-Command Unlock-PSUTerraformStateAWS
        $command.Parameters['AccessKey'].ParameterType | Should -Be ([securestring])
        $command.Parameters['SecretKey'].ParameterType | Should -Be ([securestring])

        $help = Get-Help Unlock-PSUTerraformStateAWS -Full | Out-String
        $help | Should -Match 'Read-Host\s+.+-AsSecureString'
        $help | Should -Not -Match '-AccessKey\s+[''"]'
        $help | Should -Not -Match '-SecretKey\s+[''"]'
    }

    It 'uses child-process environment credentials without putting them in argv' {
        InModuleScope OMG.PSUtilities.Core -Parameters @{
            TerraformPath = $script:terraformPath
            AccessKey = $script:accessKey
            SecretKey = $script:secretKey
            SecureAccessKey = $script:secureAccessKey
            SecureSecretKey = $script:secureSecretKey
        } {
            param ($TerraformPath, $AccessKey, $SecretKey, $SecureAccessKey, $SecureSecretKey)

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
                -AccessKey $SecureAccessKey `
                -SecretKey $SecureSecretKey `
                -Force

            Should -Invoke Write-Host -ParameterFilter {
                "$Object" -match [regex]::Escape($AccessKey) -or "$Object" -match [regex]::Escape($SecretKey)
            } -Times 0

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
            SecureAccessKey = $script:secureAccessKey
            SecureSecretKey = $script:secureSecretKey
        } {
            param ($TerraformPath, $AccessKey, $SecretKey, $SecureAccessKey, $SecureSecretKey)

            function terraform { }

            Mock Write-Host {}
            Mock Write-Error {}
            Mock Set-Location {}
            Mock terraform {
                $global:LASTEXITCODE = 1
                "Terraform failed with $AccessKey and -backend-config=secret_key=$SecretKey"
            }

            $errorRecord = {
                Unlock-PSUTerraformStateAWS `
                    -Path $TerraformPath `
                    -LockId 'lock-id' `
                    -AccessKey $SecureAccessKey `
                    -SecretKey $SecureSecretKey `
                    -Force
            } | Should -Throw -PassThru

            $errorRecord.Exception.Message | Should -Not -Match ([regex]::Escape($AccessKey))
            $errorRecord.Exception.Message | Should -Not -Match ([regex]::Escape($SecretKey))
            $errorRecord.Exception.Message | Should -Not -Match 'backend-config=secret_key'
            $errorRecord.Exception.Message | Should -Match '\*\*\*'
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