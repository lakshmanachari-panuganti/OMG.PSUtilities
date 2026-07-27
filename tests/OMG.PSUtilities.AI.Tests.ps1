# Regression tests for OMG.PSUtilities.AI.
# Every HTTP call is mocked - these must never touch a real AI endpoint.

BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $env:PSModulePath = "$repositoryRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    Import-Module (Join-Path $repositoryRoot 'OMG.PSUtilities.AI\OMG.PSUtilities.AI.psd1') -Force
}

Describe 'Invoke-GeminiAIApi authentication headers' {
    It 'sends the headers produced by New-PSUApiKey to the proxy' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock Invoke-RestMethod { throw "Unexpected request to $Uri" }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*issuetoken*' } -MockWith {
                @{ HeaderScript = "`$Headers = @{ 'Authorization' = 'Bearer T'; 'psu-clientusername' = 'u'; 'psu-clientdevice' = 'd'; 'psu-clientip' = '1.2.3.4' }" }
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

Describe 'Invoke-PSUGitCommit' {
    It 'commits once when the user regenerates the message' {
        InModuleScope OMG.PSUtilities.AI {
            Mock Write-Host {}
            Mock Set-Location {}
            Mock Popup-SensitiveContent { $true }
            Mock Invoke-PSUAiPrompt { 'chore: test message' }
            $script:commitCount = 0
            Mock git {
                switch -Regex ("$args") {
                    'rev-parse --show-toplevel' { $global:LASTEXITCODE = 0; 'C:/repos/fake' }
                    'status --porcelain' { ' M file1.ps1' }
                    '^commit' { $script:commitCount++ }
                    default { '' }
                }
            }
            # First prompt answers R, the nested call accepts with Enter
            $script:answers = @('R', '')
            $script:answerIndex = 0
            Mock Read-Host {
                $answer = $script:answers[$script:answerIndex]
                $script:answerIndex++
                $answer
            }

            Invoke-PSUGitCommit

            $script:commitCount | Should -Be 1
        }
    }
}
