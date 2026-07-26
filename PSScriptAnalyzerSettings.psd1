@{
    Severity     = @('Error')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
        'PSUseBOMForUnicodeEncodedFile'
    )
    Rules        = @{
        PSAvoidUsingCmdletAliases = @{
            Enable    = $true
            Whitelist = @()
        }
        PSPlaceOpenBrace          = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace         = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
        PSUseConsistentIndentation = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }
    }
}