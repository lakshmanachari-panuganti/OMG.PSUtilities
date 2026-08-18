@{
    RootModule           = 'OMG.PSUtilities.psm1'
    ModuleVersion        = '1.2.0'
    GUID                 = 'd9c7767a-1234-4c2d-ae6f-bdf00a0e0999'
    Author               = 'OMG IT Solutions'
    CompanyName          = 'OMG IT Solutions'
    Copyright            = '(c) 2025-2026 Lakshmanachari Panuganti'
    Description          = 'Meta-module that installs the supported OMG.PSUtilities modules.'
    PowerShellVersion    = '7.0'

    # Supported PSEditions.
    # Core only, because this is the intersection of the required modules' tested support:
    # AzureCore and AzureDevOps are Core-only, so the aggregate cannot claim Desktop even
    # though ActiveDirectory, AI and Core each support it individually.
    CompatiblePSEditions = @('Core')

    # ServiceNow and VSphere were removed in this release. Both are unimplemented stubs that
    # have been retired from publication, so requiring them would have forced users to install
    # modules whose only command throws NotImplementedException.
    RequiredModules      = @(
        @{ ModuleName = 'OMG.PSUtilities.ActiveDirectory'; ModuleVersion = '1.1.0' }
        @{ ModuleName = 'OMG.PSUtilities.AI'; ModuleVersion = '1.1.0' }
        @{ ModuleName = 'OMG.PSUtilities.AzureCore'; ModuleVersion = '1.2.0' }
        @{ ModuleName = 'OMG.PSUtilities.AzureDevOps'; ModuleVersion = '1.1.0' }
        @{ ModuleName = 'OMG.PSUtilities.Core'; ModuleVersion = '1.1.0' }
    )
    FunctionsToExport    = @()
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('DevOps', 'PowerShell', 'Automation', 'OMG')
            LicenseUri   = 'https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/lakshmanachari-panuganti/OMG.PSUtilities'
            ReleaseNotes = @'
1.2.0
- Removed OMG.PSUtilities.ServiceNow and OMG.PSUtilities.VSphere from RequiredModules. Both are
  unimplemented stubs retired from publication, so installing this meta-module no longer drags
  in modules whose only command throws NotImplementedException.
- Aligned the remaining required versions with the releases completed in Phase 8.
- Declared CompatiblePSEditions = Core, the intersection of the required modules' tested
  edition support rather than an assumption.
- Added the Copyright statement, which this manifest previously omitted entirely, and applied
  the MIT metadata approved in docs/decisions/0.5-licensing-selection.md. The LicenseUri now
  resolves, because the root LICENSE file exists.
'@
        }
    }
}
