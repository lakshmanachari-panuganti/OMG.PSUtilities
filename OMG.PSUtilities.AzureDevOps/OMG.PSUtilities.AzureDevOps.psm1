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
    'Get-PSUADOPipelineBuildDetails'
    'Get-PSUADOPipelineLatestRun'
    'Get-PSUADOProjectList'
    'Get-PSUADOPullRequestInventory'
    'Get-PSUADOPullRequests'
    'Get-PSUADORepoBranchList'
    'Get-PSUADORepositories'
    'Get-PSUADOVariableGroupInventory'
)

Export-ModuleMember -Function $PublicFunctions
