@{
    RootModule        = 'OMG.PSUtilities.psm1'
    ModuleVersion     = '1.1.0'
    GUID              = 'd9c7767a-1234-4c2d-ae6f-bdf00a0e0999'
    Author            = 'OMG IT Solutions'
    CompanyName       = 'OMG IT Solutions'
    Description       = 'Meta-module that installs the complete OMG.PSUtilities portfolio.'
    PowerShellVersion = '7.0'
    RequiredModules   = @(
        @{ ModuleName = 'OMG.PSUtilities.ActiveDirectory'; ModuleVersion = '1.0.4' }
        @{ ModuleName = 'OMG.PSUtilities.AI'; ModuleVersion = '1.0.42' }
        @{ ModuleName = 'OMG.PSUtilities.AzureCore'; ModuleVersion = '1.1.0' }
        @{ ModuleName = 'OMG.PSUtilities.AzureDevOps'; ModuleVersion = '1.0.19' }
        @{ ModuleName = 'OMG.PSUtilities.Core'; ModuleVersion = '1.0.20' }
        @{ ModuleName = 'OMG.PSUtilities.ServiceNow'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'OMG.PSUtilities.VSphere'; ModuleVersion = '1.0.2' }
    )
    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('DevOps', 'PowerShell', 'Automation', 'OMG')
            LicenseUri = 'https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/blob/main/LICENSE'
            ProjectUri = 'https://github.com/lakshmanachari-panuganti/OMG.PSUtilities'
        }
    }
}