# Regression tests for OMG.PSUtilities.ActiveDirectory.

BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $env:PSModulePath = "$repositoryRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    $moduleManifestPath = if ($env:PSU_ACTIVEDIRECTORY_TEST_MANIFEST) {
        $env:PSU_ACTIVEDIRECTORY_TEST_MANIFEST
    } else {
        Join-Path $repositoryRoot 'OMG.PSUtilities.ActiveDirectory\OMG.PSUtilities.ActiveDirectory.psd1'
    }
    Remove-Module OMG.PSUtilities.ActiveDirectory -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifestPath -Force

    InModuleScope OMG.PSUtilities.ActiveDirectory {
        function script:Get-ADUser {
            param ($Filter, $Credential, $Properties)

            $script:lastAdQueryParameters = $PSBoundParameters
            @($script:testAdUsers)
        }

        function script:Get-WinEvent {
            param ($ComputerName, $Credential, $FilterHashtable, $ErrorAction)

            $script:lastEventQueryParameters = $PSBoundParameters
            if ($script:eventQueryError) {
                throw $script:eventQueryError
            }
            @($script:testLogonEvents)
        }

        function script:New-TestLogonEvent {
            param (
                [Parameter(Mandatory)]
                [string]$Username,

                [Parameter()]
                [int]$LogonType = 2
            )

            $properties = @(0..8 | ForEach-Object { [PSCustomObject]@{ Value = $null } })
            $properties[5].Value = $Username
            $properties[8].Value = $LogonType
            [PSCustomObject]@{ Properties = $properties }
        }
    }
}

Describe 'OMG.PSUtilities.ActiveDirectory module loading' {
    It 'loads the requested module manifest' {
        $loadedModule = Get-Module OMG.PSUtilities.ActiveDirectory
        $expectedPath = Join-Path `
            (Split-Path -Parent $moduleManifestPath) `
            'OMG.PSUtilities.ActiveDirectory.psm1'

        $loadedModule.Path | Should -Be $expectedPath
    }
}

Describe 'Find-PSUADServiceAccountMisuse queries' {
    BeforeEach {
        InModuleScope OMG.PSUtilities.ActiveDirectory {
            Mock Write-Host {}
            Mock Write-Progress {}
            $script:testAdUsers = @([PSCustomObject]@{
                    SamAccountName    = 'svc-reporting'
                    DisplayName       = 'Reporting Service'
                    Enabled           = $true
                    LastLogonDate     = [datetime]'2026-08-15'
                    Description       = 'Fixture account'
                    DistinguishedName = 'CN=svc-reporting,DC=example,DC=test'
                })
            $script:testLogonEvents = @()
            $script:eventQueryError = $null
            $script:lastAdQueryParameters = $null
            $script:lastEventQueryParameters = $null
        }
    }

    It 'returns scalar High risk values for ten interactive logons' {
        InModuleScope OMG.PSUtilities.ActiveDirectory {
            $script:testLogonEvents = @(1..10 | ForEach-Object {
                    New-TestLogonEvent -Username 'svc-reporting'
                })

            $result = Find-PSUADServiceAccountMisuse -Server 'dc01.example.test'

            @($result.RiskScore).Count | Should -Be 1
            $result.RiskScore | Should -Be 10
            @($result.RiskLevel).Count | Should -Be 1
            $result.RiskLevel | Should -Be 'High'
        }
    }

    It 'returns scalar Medium risk values for five interactive logons' {
        InModuleScope OMG.PSUtilities.ActiveDirectory {
            $script:testLogonEvents = @(1..5 | ForEach-Object {
                    New-TestLogonEvent -Username 'svc-reporting'
                })

            $result = Find-PSUADServiceAccountMisuse -Server 'dc01.example.test'

            @($result.RiskScore).Count | Should -Be 1
            $result.RiskScore | Should -Be 5
            @($result.RiskLevel).Count | Should -Be 1
            $result.RiskLevel | Should -Be 'Medium'
        }
    }

    It 'omits Credential from both queries when no credential is supplied' {
        InModuleScope OMG.PSUtilities.ActiveDirectory {
            Find-PSUADServiceAccountMisuse -Server 'dc01.example.test' | Out-Null

            $script:lastAdQueryParameters.ContainsKey('Credential') | Should -BeFalse
            $script:lastEventQueryParameters.ContainsKey('Credential') | Should -BeFalse
        }
    }

    It 'passes Credential to both queries when a credential is supplied' {
        $credential = [PSCredential]::new(
            'EXAMPLE\auditor',
            (ConvertTo-SecureString 'fixture-password' -AsPlainText -Force)
        )

        InModuleScope OMG.PSUtilities.ActiveDirectory -Parameters @{ Credential = $credential } {
            param ($Credential)

            Find-PSUADServiceAccountMisuse `
                -Server 'dc01.example.test' `
                -Credential $Credential | Out-Null

            $script:lastAdQueryParameters.ContainsKey('Credential') | Should -BeTrue
            $script:lastAdQueryParameters.Credential.UserName | Should -Be 'EXAMPLE\auditor'
            $script:lastEventQueryParameters.ContainsKey('Credential') | Should -BeTrue
            $script:lastEventQueryParameters.Credential.UserName | Should -Be 'EXAMPLE\auditor'
        }
    }

    It 'treats NoMatchingEventsFound as an empty event result' {
        InModuleScope OMG.PSUtilities.ActiveDirectory {
            $exception = [System.Exception]::new('No events were found.')
            $script:eventQueryError = [System.Management.Automation.ErrorRecord]::new(
                $exception,
                'NoMatchingEventsFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $null
            )

            { $script:result = Find-PSUADServiceAccountMisuse -Server 'dc01.example.test' } |
                Should -Not -Throw
            $script:result.LogonCount | Should -Be 0
            $script:result.RiskLevel | Should -Be 'None'
        }
    }

    It 'propagates event query failures instead of reporting no events' {
        InModuleScope OMG.PSUtilities.ActiveDirectory {
            $script:eventQueryError = 'Access denied while querying the security log.'

            { Find-PSUADServiceAccountMisuse -Server 'dc01.example.test' } |
                Should -Throw '*Access denied*'
        }
    }
}

AfterAll {
    Remove-Module OMG.PSUtilities.ActiveDirectory -Force -ErrorAction SilentlyContinue
}