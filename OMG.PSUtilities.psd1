@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'OMG.PSUtilities.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.14'

    # ID used to uniquely identify this module
    GUID              = 'c3c40910-89a9-4dc3-8d67-aaf88be74519'

    # Author of this module
    Author            = 'Lakshmanachari Panuganti'

    # Company or vendor of this module
    CompanyName       = 'Luckies'

    # Copyright statement for this module
    Copyright         = '(c) 2025 Lakshmanachari Panuganti. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'A PowerShell module providing reusable utility functions for file, text, Azure, reporting, environment operations and many utility functions to simplify common tasks in PowerShell scripting.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Dependency modules required by this module.
    RequiredModules = @(
        @{ ModuleName = 'ImportExcel'; RequiredVersion = '7.8.9' }
    )

    # Functions to export from this module
    FunctionsToExport = @(
        'Export-PSUExcel',
        'Find-PSUFilesContainingText',
        'Get-PSUAzToken',
        'Get-PSUConnectedWifiInfo',
        'Get-PSUInstalledSoftware',
        'Get-PSUUserSession',
        'Invoke-PSUPromptAI',
        'New-PSUHTMLReport',
        'Remove-PSUUserSession',
        'Send-PSUHTMLReport',
        'Send-PSUTeamsMessage',
        'Set-PSUUserEnvironmentVariable',
        'Test-PSUAzConnection',
        'Test-PSUInternetConnection',
        'Uninstall-PSUInstalledSoftware'
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
            Tags         = @('Utility', 'PowerShell', 'Functions', 'ActiveDirectory', 'Azure', 'ADO', 'Excel', 'Reporting', 'Email', 'Environment', 'Automation', 'Network', 'FileSystem')
            ProjectUri   = 'https://github.com/lakshmanachari-panuganti/OMG.PSUtilities'
            ReleaseNotes = @'
- Added new utility functions: Get-PSUUserSession, Get-PSUInstalledSoftware, Get-PSUConnectedWifiInfo, Remove-PSUUserSession.
- Enhanced Get-PSUConnectedWifiInfo to include PrivateIPv4Address and PublicIPAddress.
- Improved README.md and CHANGELOG.md to accurately reflect only the functions available in the Public folder.
- Added and documented Remove-PSUUserSession for logging off user sessions.
- Improved comment-based help and parameter documentation for all new functions.
- Updated emojis and descriptions for all functions in README and CHANGELOG.
'@
        }
    }
}


