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
    'Get-PSUAzToken',
    'Get-PSUk8sPodLabel',
    'Test-PSUAzConnection'
)

$AliasesToExport = @(

)

Export-ModuleMember -Function $PublicFunctions -Alias $AliasesToExport
