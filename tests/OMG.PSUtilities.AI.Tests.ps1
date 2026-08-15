# Regression tests for OMG.PSUtilities.AI.
# Every HTTP call is mocked - these must never touch a real AI endpoint.

BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $env:PSModulePath = "$repositoryRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    $moduleManifestPath = if ($env:PSU_AI_TEST_MANIFEST) {
        $env:PSU_AI_TEST_MANIFEST
    } else {
        Join-Path $repositoryRoot 'OMG.PSUtilities.AI\OMG.PSUtilities.AI.psd1'
    }
    Remove-Module OMG.PSUtilities.AI -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifestPath -Force
}

Describe 'Invoke-GeminiAIApi authentication headers' {
    It 'sends the headers produced by New-PSUApiKey to the proxy' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock Invoke-RestMethod { throw "Unexpected request to $Uri" }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*issuetoken*' } -MockWith {
                @{
                    authorization  = 'Bearer T'
                    clientUsername = 'u'
                    clientDevice   = 'd'
                    clientIp       = '1.2.3.4'
                    expiresOn      = [DateTimeOffset]::UtcNow.AddHours(1).ToString('o')
                }
            }
            $script:sentHeaders = $null
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*api/proxy*' } -MockWith {
                $script:sentHeaders = $Headers
                @{ response = 'PROXY-OK' }
            }

            $script:PSU_API_KEY = $null
            $script:PSU_API_KEY_EXPIRY = $null
            $script:PSU_API_HEADERS = $null

            Invoke-PSUPromptOnGeminiAi -Prompt 'hi' -ApiKey '' | Should -Be 'PROXY-OK'
            $script:sentHeaders['Authorization'] | Should -Be 'Bearer T'
            $script:sentHeaders['psu-clientusername'] | Should -Be 'u'
        }
    }

    It 'requests a new key when the cached headers are gone' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock New-PSUApiKey {
                $script:PSU_API_HEADERS = @{ Authorization = 'Bearer T'; 'psu-clientusername' = 'u'; 'psu-clientdevice' = 'd'; 'psu-clientip' = '1.2.3.4' }
                'K'
            }
            Mock Invoke-RestMethod { @{ response = 'ok' } }

            $script:PSU_API_KEY = 'STALE'
            $script:PSU_API_KEY_EXPIRY = [DateTime]::UtcNow.AddHours(5)
            $script:PSU_API_HEADERS = $null

            Invoke-PSUPromptOnGeminiAi -Prompt 'hi' -ApiKey '' | Should -Be 'ok'
            Should -Invoke New-PSUApiKey -Times 1 -Exactly
        }
    }

    It 'drops the cached headers when key generation fails' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock Write-Error {}
            Mock Invoke-RestMethod { throw 'issuer down' }

            $script:PSU_API_KEY = $null
            $script:PSU_API_KEY_EXPIRY = $null
            $script:PSU_API_HEADERS = @{ Authorization = 'Bearer OLD' }

            try { New-PSUApiKey -Confirm:$false -ErrorAction Stop } catch { }
            $script:PSU_API_HEADERS | Should -BeNullOrEmpty
        }
    }
}

Describe 'New-PSUApiKey issuer contract' {
    BeforeEach {
        InModuleScope OMG.PSUtilities.AI {
            $script:PSU_API_KEY = $null
            $script:PSU_API_KEY_EXPIRY = $null
            $script:PSU_API_HEADERS = $null
            $script:verboseMessages = @()
            $script:hostMessages = @()
            Mock Write-Verbose { $script:verboseMessages += [string]$Message }
            Mock Write-Host { $script:hostMessages += [string]$Object }
            Mock Write-Error {}
        }
    }

    It 'constructs headers locally from a valid data-only response without logging the token' {
        InModuleScope OMG.PSUtilities.AI {
            $script:testToken = 'SAFE-TOKEN-VALUE'
            Mock Invoke-RestMethod {
                @{
                    authorization  = "Bearer $script:testToken"
                    clientUsername = 'build-user'
                    clientDevice   = 'build-device'
                    clientIp       = '203.0.113.10'
                    expiresOn      = [DateTimeOffset]::UtcNow.AddHours(1).ToString('o')
                }
            }

            New-PSUApiKey -Confirm:$false | Should -Be $script:testToken
            $script:PSU_API_HEADERS.Authorization | Should -Be "Bearer $script:testToken"
            $script:PSU_API_HEADERS['psu-clientusername'] | Should -Be 'build-user'
            $script:PSU_API_HEADERS['psu-clientdevice'] | Should -Be 'build-device'
            $script:PSU_API_HEADERS['psu-clientip'] | Should -Be '203.0.113.10'
            $script:PSU_API_KEY_EXPIRY | Should -BeGreaterThan ([DateTime]::UtcNow)
            (($script:verboseMessages + $script:hostMessages) -join "`n") | Should -Not -Match ([regex]::Escape($script:testToken))
        }
    }

    It 'rejects executable issuer content without running it' {
        InModuleScope OMG.PSUtilities.AI {
            $script:issuerCodeRan = $false
            Mock Invoke-RestMethod {
                @{
                    authorization  = 'Bearer SAFE-TOKEN'
                    clientUsername = 'build-user'
                    clientDevice   = 'build-device'
                    clientIp       = '203.0.113.10'
                    expiresOn      = [DateTimeOffset]::UtcNow.AddHours(1).ToString('o')
                    HeaderScript   = '$script:issuerCodeRan = $true'
                }
            }

            { New-PSUApiKey -Confirm:$false -ErrorAction Stop } | Should -Throw '*executable*'
            $script:issuerCodeRan | Should -BeFalse
            $script:PSU_API_HEADERS | Should -BeNullOrEmpty
        }
    }

    It 'rejects a response with a missing required field' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Invoke-RestMethod {
                @{
                    authorization  = 'Bearer SAFE-TOKEN'
                    clientUsername = 'build-user'
                    clientDevice   = 'build-device'
                    expiresOn      = [DateTimeOffset]::UtcNow.AddHours(1).ToString('o')
                }
            }

            { New-PSUApiKey -Confirm:$false -ErrorAction Stop } | Should -Throw '*clientIp*'
            $script:PSU_API_HEADERS | Should -BeNullOrEmpty
        }
    }

    It 'rejects an expired token' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Invoke-RestMethod {
                @{
                    authorization  = 'Bearer SAFE-TOKEN'
                    clientUsername = 'build-user'
                    clientDevice   = 'build-device'
                    clientIp       = '203.0.113.10'
                    expiresOn      = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o')
                }
            }

            { New-PSUApiKey -Confirm:$false -ErrorAction Stop } | Should -Throw '*future*'
            $script:PSU_API_HEADERS | Should -BeNullOrEmpty
        }
    }
}

Describe 'Convert-PSUContext' {
    It 'returns the rephrased text' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock New-PSUApiKey {
                $script:PSU_API_HEADERS = @{ Authorization = 'Bearer T'; 'psu-clientusername' = 'u'; 'psu-clientdevice' = 'd'; 'psu-clientip' = '1.2.3.4' }
                'K'
            }
            Mock Invoke-RestMethod { @{ response = 'Please review this issue.' } }

            $script:PSU_API_KEY = $null
            $script:PSU_API_HEADERS = $null

            Convert-PSUContext -Text 'pls chk this' | Should -Be 'Please review this issue.'
        }
    }
}

Describe 'Invoke-OpenAIApi' {
    It 'does not forward a caller-scope $headers variable' {
        InModuleScope OMG.PSUtilities.AI {
            $script:sentHeaders = 'unset'
            Mock Invoke-RestMethod {
                $script:sentHeaders = $Headers
                @{ response = 'ok' }
            }

            $headers = @{ 'X-Leaked' = 'secret-bearer-token' }
            $null = Invoke-OpenAIApi -Prompt 'hi'

            $script:sentHeaders | Should -BeNullOrEmpty
        }
    }
}

Describe 'Invoke-PSUPromptOnGeminiAi -ReturnJsonResponse' {
    It 'returns a nested JSON array without truncating it' {
        InModuleScope OMG.PSUtilities.AI {
            $payload = '[{"File":"a.ps1","Tags":["x","y"]},{"File":"b.ps1","Tags":["z"]}]'
            Mock Write-Host {}
            Mock Invoke-RestMethod { @{ candidates = @(@{ content = @{ parts = @(@{ text = $payload }) } }) } }

            $result = Invoke-PSUPromptOnGeminiAi -Prompt 'hi' -ApiKey 'k' -ReturnJsonResponse
            $result | Should -Be $payload
            ($result | ConvertFrom-Json).Count | Should -Be 2
        }
    }

    It 'strips markdown code fences' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock Invoke-RestMethod { @{ candidates = @(@{ content = @{ parts = @(@{ text = "``````json`n{`"a`":1}`n``````" }) } }) } }

            (Invoke-PSUPromptOnGeminiAi -Prompt 'hi' -ApiKey 'k' -ReturnJsonResponse | ConvertFrom-Json).a | Should -Be 1
        }
    }

    It 'falls back to the raw text when the response holds no JSON' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock Write-Warning {}
            Mock Invoke-RestMethod { @{ candidates = @(@{ content = @{ parts = @(@{ text = 'sorry, no json here' }) } }) } }

            Invoke-PSUPromptOnGeminiAi -Prompt 'hi' -ApiKey 'k' -ReturnJsonResponse | Should -Be 'sorry, no json here'
        }
    }
}

Describe 'Update-PSUChangeLog' {
    It 'keeps going when an earlier module has no CHANGELOG.md' {
        InModuleScope OMG.PSUtilities.AI {
            $root = Join-Path $env:TEMP "psu-changelog-$(New-Guid)"
            $null = New-Item -ItemType Directory -Force -Path (Join-Path $root 'OMG.PSUtilities.A'), (Join-Path $root 'OMG.PSUtilities.B')
            Set-Content -Path (Join-Path $root 'OMG.PSUtilities.B\CHANGELOG.md') -Value '## [0.0.1] - old'

            Mock Write-Host {}
            Mock Write-Error {}
            Mock git { 'OMG.PSUtilities.B/Public/Foo.ps1' }
            Mock Invoke-PSUAiPrompt { '### Added' }
            Mock Get-PSUModule { [pscustomobject]@{ ManifestPath = 'x.psd1' } }
            Mock Import-PowerShellDataFile { @{ ModuleVersion = '9.9.9' } }
            $script:updatedB = $false
            Mock Set-Content -ParameterFilter { $Path -like '*OMG.PSUtilities.B*' } -MockWith { $script:updatedB = $true }

            Update-PSUChangeLog -ModuleName @('OMG.PSUtilities.A', 'OMG.PSUtilities.B') -RootPath $root -Confirm:$false -ErrorAction SilentlyContinue

            $script:updatedB | Should -BeTrue
            Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'reports the underlying failure reason' {
        InModuleScope OMG.PSUtilities.AI {
            $root = Join-Path $env:TEMP "psu-changelog-$(New-Guid)"
            $null = New-Item -ItemType Directory -Force -Path (Join-Path $root 'OMG.PSUtilities.A')
            Set-Content -Path (Join-Path $root 'OMG.PSUtilities.A\CHANGELOG.md') -Value '## [0.0.1] - old'

            Mock Write-Host {}
            Mock git { 'OMG.PSUtilities.A/Public/Foo.ps1' }
            Mock Invoke-PSUAiPrompt { throw 'AI engine exploded' }

            $err = $null
            try { Update-PSUChangeLog -ModuleName 'OMG.PSUtilities.A' -RootPath $root -Confirm:$false -ErrorAction Stop } catch { $err = $_ }

            $err.Exception.Message | Should -Match 'AI engine exploded'
            Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'New-PSUAiPoweredPullRequest prompt binding' {
    It 'accepts a supported Read-Host choice without a parameter-binding error' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock Write-Warning {}
            Mock Set-Location {}
            Mock Set-Clipboard {}
            Mock Convert-PSUPullRequestSummaryToHtml {}
            Mock Get-PSUAiPoweredGitChangeSummary {
                @([pscustomobject]@{
                        File         = 'reviewed.ps1'
                        TypeOfChange = 'Modified'
                        Summary      = 'Updated behavior'
                    })
            }
            Mock Invoke-PSUAiPrompt { '{"title":"Review update","description":"Updated behavior"}' }
            Mock git {
                $global:LASTEXITCODE = 0
                if ("$args" -eq 'rev-parse --show-toplevel') {
                    'C:/repos/fake'
                }
            }
            $script:promptAnswers = @('N', 'N')
            $script:promptIndex = 0
            Mock Read-Host {
                $answer = $script:promptAnswers[$script:promptIndex]
                $script:promptIndex++
                $answer
            }

            {
                New-PSUAiPoweredPullRequest `
                    -BaseBranch main `
                    -FeatureBranch feature/review `
                    -Confirm:$false
            } | Should -Not -Throw
            Should -Invoke Read-Host -Times 2 -Exactly
        }
    }
}

Describe 'Invoke-PSUGitCommit' {
    It 'stages only reviewed repository-relative paths' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock Set-Location {}
            Mock Popup-SensitiveContent { $true }
            Mock Invoke-PSUAiPrompt { 'chore: test message' }
            Mock Read-Host { '' }
            Mock Get-Item { [System.IO.FileInfo]'C:\repos\fake\reviewed.ps1' }
            $script:gitCalls = [System.Collections.Generic.List[string]]::new()
            Mock git {
                $call = "$args"
                $script:gitCalls.Add($call)
                $global:LASTEXITCODE = 0
                switch -Regex ($call) {
                    '^rev-parse --show-toplevel$' { 'C:/repos/fake' }
                    'status --porcelain' { ' M file1.ps1' }
                    '^diff --' { 'diff content' }
                    default { '' }
                }
            }

            Invoke-PSUGitCommit

            $script:gitCalls | Should -Contain 'add -- file1.ps1'
            $script:gitCalls | Should -Not -Contain 'add .'
        }
    }

    It 'aborts before prompting when no reviewed path remains' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock Set-Location {}
            Mock Popup-SensitiveContent { $true }
            Mock Invoke-PSUAiPrompt { 'chore: should not run' }
            Mock Read-Host { '' }
            $script:gitCalls = [System.Collections.Generic.List[string]]::new()
            Mock git {
                $call = "$args"
                $script:gitCalls.Add($call)
                $global:LASTEXITCODE = 0
                switch -Regex ($call) {
                    '^rev-parse --show-toplevel$' { 'C:/repos/fake' }
                    'status --porcelain' { '?? settings.env' }
                    default { '' }
                }
            }

            Invoke-PSUGitCommit

            Should -Invoke Invoke-PSUAiPrompt -Times 0 -Exactly
            @($script:gitCalls | Where-Object { $_ -match '^(add|commit|pull|push)( |$)' }) | Should -BeNullOrEmpty
        }
    }

    It 'rejects pre-staged paths outside the reviewed set' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock Write-Error {}
            Mock Set-Location {}
            Mock Popup-SensitiveContent { $true }
            Mock Invoke-PSUAiPrompt { 'chore: should not run' }
            Mock Get-Item { [System.IO.FileInfo]'C:\repos\fake\reviewed.ps1' }
            Mock git {
                $global:LASTEXITCODE = 0
                switch -Regex ("$args") {
                    '^rev-parse --show-toplevel$' { 'C:/repos/fake' }
                    'status --porcelain' { @('M  secrets.env', ' M reviewed.ps1') }
                    default { '' }
                }
            }

            { Invoke-PSUGitCommit } | Should -Throw '*pre-staged*secrets.env*'
            Should -Invoke Invoke-PSUAiPrompt -Times 0 -Exactly
        }
    }

    It 'regenerates in place and commits once' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock Set-Location {}
            Mock Popup-SensitiveContent { $true }
            Mock Get-Item { [System.IO.FileInfo]'C:\repos\fake\file1.ps1' }
            $script:promptCount = 0
            Mock Invoke-PSUAiPrompt { $script:promptCount++; 'chore: test message' }
            $script:commitCount = 0
            $script:rootCount = 0
            Mock git {
                $global:LASTEXITCODE = 0
                switch -Regex ("$args") {
                    '^rev-parse --show-toplevel$' { $script:rootCount++; 'C:/repos/fake' }
                    'status --porcelain' { ' M file1.ps1' }
                    '^diff --' { 'diff content' }
                    '^commit' { $script:commitCount++ }
                    default { '' }
                }
            }
            $script:answers = @('R', '')
            $script:answerIndex = 0
            Mock Read-Host {
                $answer = $script:answers[$script:answerIndex]
                $script:answerIndex++
                $answer
            }

            Invoke-PSUGitCommit

            $script:commitCount | Should -Be 1
            $script:promptCount | Should -Be 2
            $script:rootCount | Should -Be 1
        }
    }

    It 'stops at a failed native Git command' -ForEach @(
        @{ Command = 'status' }
        @{ Command = 'diff' }
        @{ Command = 'add' }
        @{ Command = 'commit' }
        @{ Command = 'pull' }
        @{ Command = 'push' }
    ) {
        InModuleScope OMG.PSUtilities.AI -Parameters @{ FailingCommand = $Command } {
            param ($FailingCommand)

            Mock Set-Location {}
            Mock Popup-SensitiveContent { $true }
            Mock Get-Item { [System.IO.FileInfo]'C:\repos\fake\file1.ps1' }
            Mock Invoke-PSUAiPrompt { 'chore: test message' }
            Mock Read-Host { '' }
            Mock Write-Error {}
            $script:hostMessages = @()
            Mock Write-Host { $script:hostMessages += [string]$Object }
            $script:failingCommand = $FailingCommand
            Mock git {
                $commandName = [string]$args[0]
                if ($commandName -eq $script:failingCommand) {
                    $global:LASTEXITCODE = 1
                    return 'native failure'
                }

                $global:LASTEXITCODE = 0
                switch -Regex ("$args") {
                    '^rev-parse --show-toplevel$' { 'C:/repos/fake' }
                    'status --porcelain' { ' M file1.ps1' }
                    '^diff --' { 'diff content' }
                    default { '' }
                }
            }

            { Invoke-PSUGitCommit } | Should -Throw "*git $FailingCommand failed*"
            ($script:hostMessages -join "`n") | Should -Not -Match 'Sync complete'
        }
    }
}

Describe 'OMG.PSUtilities.AI module loading' {
    It 'imports when the optional Private folder is absent' {
        $repositoryRoot = Split-Path -Parent $PSScriptRoot
        $sourceModule = if ($env:PSU_AI_TEST_MANIFEST) {
            Split-Path -Parent $env:PSU_AI_TEST_MANIFEST
        } else {
            Join-Path $repositoryRoot 'OMG.PSUtilities.AI'
        }
        $isolatedModule = Join-Path $TestDrive 'OMG.PSUtilities.AI'
        New-Item -Path $isolatedModule -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $sourceModule 'OMG.PSUtilities.AI.psd1') -Destination $isolatedModule
        Copy-Item -LiteralPath (Join-Path $sourceModule 'OMG.PSUtilities.AI.psm1') -Destination $isolatedModule
        Copy-Item -LiteralPath (Join-Path $sourceModule 'Public') -Destination $isolatedModule -Recurse

        try {
            Remove-Module OMG.PSUtilities.AI -Force -ErrorAction SilentlyContinue
            { Import-Module (Join-Path $isolatedModule 'OMG.PSUtilities.AI.psd1') -Force -ErrorAction Stop } |
                Should -Not -Throw
        } finally {
            Remove-Module OMG.PSUtilities.AI -Force -ErrorAction SilentlyContinue
            Import-Module (Join-Path $sourceModule 'OMG.PSUtilities.AI.psd1') -Force
        }
    }
}
