# Load private functions
Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -Recurse | ForEach-Object {
    try {
        . $($_.FullName)
    } catch {
        Write-Error "Failed to load private function $($_.FullName): $($_)"
    }
}

# Load public functions
Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -Recurse | ForEach-Object {
    try {
        . $($_.FullName)
    } catch {
        Write-Error "Failed to load public function $($_.FullName): $($_)"
    }
}

# Export public functions
$PublicFunctions = @(
    'Find-PSUFilesContainingText'
    'Get-PSUConnectedWifiInfo'
    'Get-PSUFunctionHelpInfo'
    'Get-PSUGitRepositoryChanges'
    'Get-PSUInstalledSoftware'
    'Get-PSUUserSession'
    'New-PSUHTMLReport'
    'Remove-PSUUserSession'
    'Send-PSUHTMLReport'
    'Send-PSUTeamsMessage'
    'Set-PSUUserEnvironmentVariable'
    'Test-PSUInternetConnection'
    'Uninstall-PSUInstalledSoftware'
)

Export-ModuleMember -Function $PublicFunctions
