function Build-OMGModuleLocally {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function'
    )]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,  # Example: OMG.PSUtilities.Core

        [Parameter()]
        [Switch]$SkipUpdateManifests
    )
    process {
        try {
            $modulePath = Join-Path $env:BASE_MODULE_PATH $ModuleName
            $psd1Path = Join-Path $modulePath "$ModuleName.psd1"

            Write-Verbose "Base path for module: $env:BASE_MODULE_PATH"
            Write-Verbose "Module path: $modulePath"
            Write-Verbose "Module manifest path: $psd1Path"

            if (-not (Test-Path $psd1Path)) {
                Write-Error "Module manifest not found: $psd1Path"
                return
            }

            # Run PS Analyzer to Analyse the module
            $Rules = @('PSAvoidTrailingWhitespace',
                'PSUseConsistentIndentation',
                'PSPlaceOpenBrace',
                'PSPlaceCloseBrace',
                'PSSpaceAroundOperators',
                'PSUseCorrectCasingForCommonCmdlets',
                'PSUseCorrectCasingForCommonParameters'
            )

            Invoke-ScriptAnalyzer -Path $modulePath -Recurse -Fix -IncludeRule $Rules

            if (-not $SkipUpdateManifests) {
                Reset-OMGModuleManifests -ModuleName $ModuleName
            }

            # Remove the module if already loaded
            $existingModule = Get-Module -Name $ModuleName -ListAvailable
            if ($existingModule) {
                $existingModule | Remove-Module -Force -ErrorAction SilentlyContinue
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
            Write-Error "Failed to import module: $_"
        }
    }
}
