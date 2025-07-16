
@{
    RootModule = 'OMG.PSUtilities.psm1'
    ModuleVersion = '1.0.19'
    GUID = 'd9c7767a-1234-4c2d-ae6f-bdf00a0e0999'
    Author = 'OMG IT Solutions'
    CompanyName = 'OMG IT Solutions'
    Description = 'Meta module that includes all OMG.PSUtilities.* submodules.'
    PowerShellVersion = '5.1'
    NestedModules = @(
        'OMG.PSUtilities.ActiveDirectory',
        'OMG.PSUtilities.VSphere',
        'OMG.PSUtilities.AI',
        'OMG.PSUtilities.AzureCore',
        'OMG.PSUtilities.AzureDevOps',
        'OMG.PSUtilities.ServiceNow',
        'OMG.PSUtilities.Core'
    )
    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData = @{
        PSData = @{
            Tags = @('DevOps', 'Modules', 'Automation', 'OMG')
            ProjectUri = 'https://github.com/lakshmanachari-panuganti/OMG.PSUtilities'
        }
    }
}
