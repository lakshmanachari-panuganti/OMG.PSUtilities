# Load private functions
Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -Recurse | Where-Object{$_.name -notlike "*--wip.ps1"} | ForEach-Object {
    try {
        . $($_.FullName)
    } catch {
        Write-Error "Failed to load private function $($_.FullName): $($_)"
    }
}

# Load public functions
Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -Recurse | Where-Object{$_.name -notlike "*--wip.ps1"} | ForEach-Object {
    try {
        . $($_.FullName)
    } catch {
        Write-Error "Failed to load public function $($_.FullName): $($_)"
    }
}

# Export public functions
$PublicFunctions = @(
    'Approve-PSUGithubPullRequest',
    'Approve-PSUPullRequest',
    'Complete-PSUPullRequest',
    'Export-PSUExcel',
    'Find-PSUFilesContainingText',
    'Get-PSUConnectedWifiInfo',
    'Get-PSUFunctionCommentBasedHelp',
    'Get-PSUGitFileChangeMetadata',
    'Get-PSUInstalledSoftware',
    'Get-PSUModule',
    'Get-PSUUserEnvironmentVariable',
    'Get-PSUUserSession',
    'New-PSUGithubPullRequest',
    'New-PSUHTMLReport',
    'New-PSUOutlookMeeting',
    'Remove-PSUUserEnvironmentVariable',
    'Remove-PSUUserSession',
    'Send-PSUHTMLReport',
    'Send-PSUTeamsMessage',
    'Set-PSUUserEnvironmentVariable',
    'Test-PSUInternetConnection',
    'Uninstall-PSUInstalledSoftware',
    'Unlock-PSUTerraformStateAWS',
    'Update-PSUModuleVersion'
)

$AliasesToExport = @(
    'Get-WifiInfo',
    'Remove-PSUInstalledSoftware',
    'Uninstall-Software'
)

Export-ModuleMember -Function $PublicFunctions -Alias $AliasesToExport
