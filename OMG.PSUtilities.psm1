# Load all Private functions
Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse | ForEach-Object {
    try {
        . $_.FullName
    } catch {
        Write-Error "Failed to load private function $($_.FullName): $_"
    }
}

# Load all Public functions
Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse | ForEach-Object {
    try {
        . $_.FullName
    } catch {
        Write-Error "Failed to load public function $($_.FullName): $_"
    }
}
