@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'OMG.PSUtilities.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.10'

    # ID used to uniquely identify this module
    GUID              = 'c3c40910-89a9-4dc3-8d67-aaf88be74519'

    # Author of this module
    Author            = 'Lakshmanachari Panuganti'

    # Company or vendor of this module
    CompanyName       = 'Unknown'

    # Copyright statement for this module
    Copyright         = '(c) 2025 Lakshmanachari Panuganti. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'A utility module with reusable PowerShell functions.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'ConvertTo-PSUExcelFile',
        'Get-PSUAzToken',
        'New-PSUHTMLReport',
        'Send-PSUHTMLReport',
        'Set-PSUUserEnvironmentVariable',
        'Test-PSUAzConnection',
        'Test-PSUInternetConnection'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData       = @{
        PSData = @{
            Tags       = @('Utility', 'PowerShell', 'Functions', 'ActiveDirectory', 'Azure', 'ADO')
            ProjectUri = 'https://github.com/lakshmanachari-panuganti/OMG.PSUtilities'
        }
    }
}




