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
    'Export-PSUExcel'
    'Find-PSUFilesContainingText'
    'Get-PSUConnectedWifiInfo'
    'Get-PSUFunctionCommentBasedHelp'
    'Get-PSUGitFileChangeMetadata'
    'Get-PSUInstalledSoftware'
    'Get-PSUUserEnvironmentVariable'
    'Get-PSUUserSession'
    'New-PSUHTMLReport'
    'Remove-PSUUserEnvironmentVariable'
    'Remove-PSUUserSession'
    'Send-PSUHTMLReport'
    'Send-PSUTeamsMessage'
    'Set-PSUUserEnvironmentVariable'
    'Test-PSUInternetConnection'
    'Uninstall-PSUInstalledSoftware'
)

$AliasesToExport = @(
    Get-WifiInfo
    Remove-PSUInstalledSoftware
    Uninstall-Software
)

Export-ModuleMember -Function $PublicFunctions -Alias $AliasesToExport
