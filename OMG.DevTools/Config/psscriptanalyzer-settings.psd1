@{
    # PSScriptAnalyzer settings for module validation

    # Include default rules
    IncludeDefaultRules = $true

    # Severity levels to report
    Severity = @('Error', 'Warning')

    # Rules to exclude
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'  # We use Write-Host for colored output
    )

    # Custom rules path
    # CustomRulePath = @()

    # Rules configuration
    Rules = @{
        PSUseCompatibleCommands = @{
            Enable = $true
            TargetProfiles = @(
                'win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'  # PS 5.1 on Win10
                'win-8_x64_10.0.17763.0_7.0.0_x64_3.1.2_core'  # PS 7 on Win10
            )
        }

        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('5.1', '7.0')
        }

        PSUseCompatibleTypes = @{
            Enable = $true
            TargetProfiles = @(
                'win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'
                'win-8_x64_10.0.17763.0_7.0.0_x64_3.1.2_core'
            )
        }

        PSAvoidUsingCmdletAliases = @{
            Enable = $true
            Whitelist = @()
        }

        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore = $false
        }

        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind = 'space'
        }

        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator = $true
            CheckParameter = $false
        }

        PSAlignAssignmentStatement = @{
            Enable = $true
            CheckHashtable = $true
        }
    }
}