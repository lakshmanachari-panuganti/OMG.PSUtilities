# Regression tests for OMG.PSUtilities.AzureCore.

BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $env:PSModulePath = "$repositoryRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    $moduleManifestPath = if ($env:PSU_AZURECORE_TEST_MANIFEST) {
        $env:PSU_AZURECORE_TEST_MANIFEST
    } else {
        Join-Path $repositoryRoot 'OMG.PSUtilities.AzureCore\OMG.PSUtilities.AzureCore.psd1'
    }
    Remove-Module OMG.PSUtilities.AzureCore -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifestPath -Force
}

Describe 'OMG.PSUtilities.AzureCore module loading' {
    It 'imports when the optional Private folder is absent' {
        $sourceModule = Split-Path -Parent $moduleManifestPath
        $isolatedModule = Join-Path $TestDrive 'OMG.PSUtilities.AzureCore'
        New-Item -Path $isolatedModule -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $sourceModule 'OMG.PSUtilities.AzureCore.psd1') -Destination $isolatedModule
        Copy-Item -LiteralPath (Join-Path $sourceModule 'OMG.PSUtilities.AzureCore.psm1') -Destination $isolatedModule
        Copy-Item -LiteralPath (Join-Path $sourceModule 'Public') -Destination $isolatedModule -Recurse
        Join-Path $isolatedModule 'Private' | Should -Not -Exist

        try {
            Remove-Module OMG.PSUtilities.AzureCore -Force -ErrorAction SilentlyContinue
            $importOutput = Import-Module (Join-Path $isolatedModule 'OMG.PSUtilities.AzureCore.psd1') -Force -ErrorAction Stop 2>&1
            $importOutput | Should -BeNullOrEmpty
        } finally {
            Remove-Module OMG.PSUtilities.AzureCore -Force -ErrorAction SilentlyContinue
            Import-Module $moduleManifestPath -Force
        }
    }
}

Describe 'Invoke-PSUAzureAppRegAudit mutation guard' {
    It 'does not enumerate tenant data or mutate output under WhatIf' {
        InModuleScope OMG.PSUtilities.AzureCore {
            function Get-MgContext { }
            function Get-MgOrganization { }
            function Get-AzContext { }
            function Get-AzSubscription { }

            Mock Get-MgContext { throw 'Graph context must not be queried.' }
            Mock Get-MgOrganization { throw 'Graph organization must not be queried.' }
            Mock Get-AzContext { throw 'Azure context must not be queried.' }
            Mock Get-AzSubscription { throw 'Azure subscriptions must not be queried.' }
            Mock Add-Content { throw 'Audit logs must not be written.' }
            Mock New-Item { throw 'Output directories must not be created.' }
            Mock Export-Csv { throw 'Audit CSVs must not be written.' }

            Invoke-PSUAzureAppRegAudit -TenantId 'tenant-id' -WhatIf

            Should -Invoke Get-MgContext -Times 0 -Exactly
            Should -Invoke Get-MgOrganization -Times 0 -Exactly
            Should -Invoke Get-AzContext -Times 0 -Exactly
            Should -Invoke Get-AzSubscription -Times 0 -Exactly
            Should -Invoke Add-Content -Times 0 -Exactly
            Should -Invoke New-Item -Times 0 -Exactly
            Should -Invoke Export-Csv -Times 0 -Exactly
        }
    }
}