@{
    RootModule = 'OMG.PSUtilities.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'c3c40910-89a9-4dc3-8d67-aaf88be74519'
    Author = 'Lakshmanachari Panuganti'
    Description = 'A utility module with reusable PowerShell functions.'
    FunctionsToExport = @('Get-Hello')  # Only public functions
    PrivateData = @{
        PSData = @{
            Tags = @('utility', 'powershell', 'OMG')
            ProjectUri = 'https://github.com/yourusername/OMG.PSUtilities'
        }
    }
}
