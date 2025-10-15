# Load private functions
Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -Recurse | Where-Object { $_.name -notlike "*--wip.ps1" } | ForEach-Object {
    try {
        . $($_.FullName)
    } catch {
        Write-Error "Failed to load private function $($_.FullName): $($_)"
    }
}

# Load public functions
Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -Recurse | Where-Object { $_.name -notlike "*--wip.ps1" } | ForEach-Object {
    try {
        . $($_.FullName)
    } catch {
        Write-Error "Failed to load public function $($_.FullName): $($_)"
    }
}

# Export public functions
$PublicFunctions = @(
    'Approve-PSUADOPullRequest',
    'Complete-PSUADOPullRequest',
    'Get-PSUADOPipeline',
    'Get-PSUADOPipelineBuild',
    'Get-PSUADOPipelineLatestRun',
    'Get-PSUADOProjectList',
    'Get-PSUADOPullRequest',
    'Get-PSUADOPullRequestInventory',
    'Get-PSUADORepoBranchList',
    'Get-PSUADORepositories',
    'Get-PSUADOVariableGroupInventory',
    'Get-PSUADOWorkItem',
    'Invoke-PSUADORepoClone',
    'New-PSUADOBug',
    'New-PSUADOPullRequest',
    'New-PSUADOSpike',
    'New-PSUADOTask',
    'New-PSUADOUserStory',
    'New-PSUADOVariable',
    'New-PSUADOVariableGroup',
    'Set-PSUADOBug',
    'Set-PSUADOSpike',
    'Set-PSUADOTask',
    'Set-PSUADOUserStory',
    'Set-PSUADOVariable',
    'Set-PSUADOVariableGroup'
)

$AliasesToExport = @(

)

Export-ModuleMember -Function $PublicFunctions -Alias $AliasesToExport
