function Build-OMGModuleLocally {
    <#
    .SYNOPSIS
        Builds an OMG module locally.

    .DESCRIPTION
        Builds a specific OMG module by running script analysis, updating manifests,
        and importing the module for testing.

    .PARAMETER ModuleName
        The name of the module to build (e.g., OMG.PSUtilities.Core).

    .PARAMETER SkipUpdateManifests
        Skip updating the module manifest files.

    .PARAMETER SkipScriptAnalyzer
        Skip PSScriptAnalyzer validation during build.

    .EXAMPLE
        Build-OMGModuleLocally -ModuleName "OMG.PSUtilities.Core"
        Builds the Core module with full analysis and manifest updates.

    .EXAMPLE
        Build-OMGModuleLocally -ModuleName "OMG.PSUtilities.Core" -SkipScriptAnalyzer
        Builds the module without running PSScriptAnalyzer.

    .OUTPUTS
        None
    #>

    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,  # Example: OMG.PSUtilities.Core

        [Parameter()]
        [Switch]$SkipUpdateManifests,

        [Parameter()]
        [Switch]$SkipScriptAnalyzer
    )

    process {
        try {
            $modulePath = Join-Path $env:BASE_MODULE_PATH $ModuleName

            # Check $modulePath existance
            if (-not (Test-Path $modulePath)) {
                throw "Module path does not exist: $modulePath"
            }

            $psd1Path = Join-Path $modulePath "$ModuleName.psd1"

            Write-Verbose "Base path for module: $env:BASE_MODULE_PATH"
            Write-Verbose "Module path: $modulePath"
            Write-Verbose "Module manifest path: $psd1Path"

            if (-not (Test-Path $psd1Path)) {
                Write-Error "Module manifest not found: $psd1Path"
                return
            }

            if (-not $SkipScriptAnalyzer) {
                # Run PS Analyzer to Analyse the module
                $Rules = @(
                    'PSAvoidUsingWriteHost',
                    'PSAvoidTrailingWhitespace',
                    'PSUseConsistentIndentation',
                    'PSPlaceOpenBrace',
                    'PSPlaceCloseBrace',
                    'PSSpaceAroundOperators',
                    'PSAvoidGlobalVars',
                    'PSAvoidUsingCmdletAliases',
                    'PSAvoidUsingPositionalParameters',
                    'PSUseCorrectCasingForCmdlets',
                    'PSUseCorrectCasingForCommonCmdlets',
                    'PSUseCorrectCasingForCommonParameters',
                    'PSUseShouldProcessForStateChangingFunctions',
                    'PSAvoidLongLines'
                )

                $Settings = @{
                    ExcludeRules = @('PSUseBOMForUnicodeEncodedFile')
                }

                $ScriptAnalyzerParams = @{
                    Path          = $modulePath
                    Recurse       = $true
                    IncludeRule   = $Rules
                    Settings      = $Settings
                    Fix           = $true
                    Severity      = @('Warning', 'Error')
                    ReportSummary = $true
                }

                Invoke-ScriptAnalyzer @ScriptAnalyzerParams
            }

            if (-not $SkipUpdateManifests) {
                Reset-OMGModuleManifests -ModuleName $ModuleName
            }

            # Remove the module if already loaded
            $existingModule = Get-Module -Name $ModuleName -ListAvailable
            if ($existingModule) {
                Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
                Write-Host "REMOVED: Existed '$ModuleName' successfully removed." -ForegroundColor Green
            }

            # Import the module locally
            Import-Module $psd1Path -Force -Verbose -ErrorAction Stop
            $importMsg = "IMPORTD: Updated $ModuleName successfully imported"
            Write-Host $importMsg -ForegroundColor Green
            1..$importMsg.Length | ForEach-Object { Write-Host "-" -ForegroundColor Green -NoNewline }
            Write-Host ""
            Write-Host ""
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
