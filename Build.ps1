$psd1Path = ".\OMG.PSUtilities.psd1"

# Build the function list from .\Public\*.ps1
$functions = (Get-ChildItem -Path .\Public\*.ps1 | ForEach-Object {
    "'$($_.BaseName)'"
} )-join ",`n    "

# Read content as text
$psd1Content = Get-Content -Path $psd1Path -Raw

# Regex to safely replace the entire FunctionsToExport block
$pattern = '(?s)(FunctionsToExport\s*=\s*@\()[^\)]*(\))'

# Compose new replacement block
$replacement = "FunctionsToExport = @(`n    $functions`n)"

# Perform the replacement
$updatedContent = [regex]::Replace($psd1Content, $pattern, $replacement)

# Save the updated .psd1
Set-Content -Path $psd1Path -Value $updatedContent -Encoding UTF8

Write-Host "✅ FunctionsToExport successfully updated in $psd1Path"
