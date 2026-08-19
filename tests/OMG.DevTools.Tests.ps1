# Regression tests for OMG.DevTools.
# Nothing here may write to the real Windows Credential Manager or to real environment
# variables; every storage call is mocked.

BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $env:PSModulePath = "$repositoryRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    $moduleManifestPath = if ($env:PSU_DEVTOOLS_TEST_MANIFEST) {
        $env:PSU_DEVTOOLS_TEST_MANIFEST
    } else {
        Join-Path $repositoryRoot 'OMG.DevTools\OMG.DevTools.psd1'
    }
    Remove-Module OMG.DevTools -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifestPath -Force
}

Describe 'Initialize-OMGEnvironment secret handling' {
    BeforeEach {
        InModuleScope OMG.DevTools {
            $script:apiKeyUnderTest = 'API-KEY-MUST-NOT-LEAK'
            $script:hostMessages = @()
            $script:storedTargets = @()

            Mock Write-Host { $script:hostMessages += [string]$Object }
            Mock Write-Warning {}
            Mock Initialize-ModuleDevTools {}

            # Core's storage and retrieval commands, resolved by the function via Get-Command.
            function Set-PSUCredentialToManager { }
            function Get-PSUSecret { }
        }
    }

    It 'reads API keys as SecureString so the value is never echoed' {
        InModuleScope OMG.DevTools {
            Mock Get-PSUSecret { throw 'not stored' }
            Mock Set-PSUCredentialToManager { $script:storedTargets += $Target }
            $script:secureStringPrompts = 0
            Mock Read-Host {
                if ($AsSecureString) {
                    $script:secureStringPrompts++
                    return (ConvertTo-SecureString $script:apiKeyUnderTest -AsPlainText -Force)
                }
                return 'C:\modules'
            }
            Mock Set-Item {}
            Mock Get-Command { [pscustomobject]@{ Name = 'stub' } }

            $null = Initialize-OMGEnvironment -Confirm:$false

            # One secure prompt per API key, and the path prompt is not one of them.
            $script:secureStringPrompts | Should -Be 5
        }
    }

    It 'stores every API key in Credential Manager rather than the environment' {
        InModuleScope OMG.DevTools {
            Mock Get-PSUSecret { throw 'not stored' }
            Mock Set-PSUCredentialToManager { $script:storedTargets += $Target }
            Mock Read-Host {
                if ($AsSecureString) { return (ConvertTo-SecureString $script:apiKeyUnderTest -AsPlainText -Force) }
                return 'C:\modules'
            }
            $script:environmentWrites = @()
            Mock Set-Item { $script:environmentWrites += [string]$Path }
            Mock Get-Command { [pscustomobject]@{ Name = 'stub' } }

            $null = Initialize-OMGEnvironment -Confirm:$false

            $script:storedTargets | Should -Contain 'GEMINI_API_KEY'
            $script:storedTargets.Count | Should -Be 5

            # Only the non-secret module path may be written to the environment.
            $script:environmentWrites | Should -Not -Contain 'env:GEMINI_API_KEY'
        }
    }

    It 'never writes an API key value to host output' {
        InModuleScope OMG.DevTools {
            Mock Get-PSUSecret { throw 'not stored' }
            Mock Set-PSUCredentialToManager {}
            Mock Read-Host {
                if ($AsSecureString) { return (ConvertTo-SecureString $script:apiKeyUnderTest -AsPlainText -Force) }
                return 'C:\modules'
            }
            Mock Set-Item {}
            Mock Get-Command { [pscustomobject]@{ Name = 'stub' } }

            $null = Initialize-OMGEnvironment -Confirm:$false

            ($script:hostMessages -join "`n") | Should -Not -Match ([regex]::Escape($script:apiKeyUnderTest))
        }
    }

    It 'returns only names, never values' {
        InModuleScope OMG.DevTools {
            Mock Get-PSUSecret { throw 'not stored' }
            Mock Set-PSUCredentialToManager {}
            Mock Read-Host {
                if ($AsSecureString) { return (ConvertTo-SecureString $script:apiKeyUnderTest -AsPlainText -Force) }
                return 'C:\modules'
            }
            Mock Set-Item {}
            Mock Get-Command { [pscustomobject]@{ Name = 'stub' } }

            $result = Initialize-OMGEnvironment -Confirm:$false

            ($result | ConvertTo-Json -Depth 5) | Should -Not -Match ([regex]::Escape($script:apiKeyUnderTest))
        }
    }

    It 'writes nothing in non-interactive mode' {
        InModuleScope OMG.DevTools {
            Mock Get-PSUSecret { throw 'not stored' }
            Mock Set-PSUCredentialToManager {}
            Mock Read-Host { throw 'Non-interactive mode must not prompt.' }
            Mock Set-Item {}
            Mock Get-Command { [pscustomobject]@{ Name = 'stub' } }

            $result = Initialize-OMGEnvironment -NonInteractive -Confirm:$false

            Should -Invoke Set-PSUCredentialToManager -Times 0 -Exactly
            Should -Invoke Read-Host -Times 0 -Exactly
            $result.Missing | Should -Contain 'GEMINI_API_KEY'
        }
    }

    It 'skips a secret when the prompt is left empty' {
        InModuleScope OMG.DevTools {
            Mock Get-PSUSecret { throw 'not stored' }
            Mock Set-PSUCredentialToManager {}
            Mock Read-Host {
                if ($AsSecureString) { return (New-Object System.Security.SecureString) }
                return ''
            }
            Mock Set-Item {}
            Mock Get-Command { [pscustomobject]@{ Name = 'stub' } }

            $result = Initialize-OMGEnvironment -Confirm:$false

            Should -Invoke Set-PSUCredentialToManager -Times 0 -Exactly
            $result.Created | Should -BeNullOrEmpty
        }
    }

    It 'leaves stored secrets alone unless -Force is supplied' {
        InModuleScope OMG.DevTools {
            Mock Get-PSUSecret { ConvertTo-SecureString 'already-stored' -AsPlainText -Force }
            Mock Set-PSUCredentialToManager {}
            Mock Read-Host { 'C:\modules' }
            Mock Set-Item {}
            Mock Get-Command { [pscustomobject]@{ Name = 'stub' } }

            $result = Initialize-OMGEnvironment -Confirm:$false

            Should -Invoke Set-PSUCredentialToManager -Times 0 -Exactly
            $result.Valid | Should -Contain 'GEMINI_API_KEY'
        }
    }

    It 'overwrites a stored secret when -Force is supplied' {
        InModuleScope OMG.DevTools {
            Mock Get-PSUSecret { ConvertTo-SecureString 'already-stored' -AsPlainText -Force }
            Mock Set-PSUCredentialToManager { $script:storedTargets += $Target }
            Mock Read-Host {
                if ($AsSecureString) { return (ConvertTo-SecureString $script:apiKeyUnderTest -AsPlainText -Force) }
                return 'C:\modules'
            }
            Mock Set-Item {}
            Mock Get-Command { [pscustomobject]@{ Name = 'stub' } }

            $null = Initialize-OMGEnvironment -Force -Confirm:$false

            $script:storedTargets.Count | Should -Be 5
        }
    }

    It 'reports the failure without disclosing the value when storage fails' {
        InModuleScope OMG.DevTools {
            Mock Get-PSUSecret { throw 'not stored' }
            Mock Set-PSUCredentialToManager { throw "credential store unavailable" }
            Mock Read-Host {
                if ($AsSecureString) { return (ConvertTo-SecureString $script:apiKeyUnderTest -AsPlainText -Force) }
                return 'C:\modules'
            }
            Mock Set-Item {}
            Mock Get-Command { [pscustomobject]@{ Name = 'stub' } }
            $script:errors = @()
            Mock Write-Error { $script:errors += [string]$Message }

            $null = Initialize-OMGEnvironment -Confirm:$false

            ($script:errors -join "`n") | Should -Match 'GEMINI_API_KEY'
            ($script:errors -join "`n") | Should -Not -Match ([regex]::Escape($script:apiKeyUnderTest))
        }
    }

    It 'directs the user to install Core when secret storage is unavailable' {
        InModuleScope OMG.DevTools {
            Mock Read-Host { 'C:\modules' }
            Mock Set-Item {}
            Mock Get-Command { $null }

            { Initialize-OMGEnvironment -Confirm:$false } | Should -Throw '*Install-Module OMG.PSUtilities.Core*'
        }
    }
}
