function Invoke-OMGBuild {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$ModuleRoot =  (Split-Path -Path $PSScriptRoot -Parent)
    )

    try {
        $psd1Path = Join-Path $ModuleRoot "OMG.PSUtilities.psd1"
        $publicFolder = Join-Path $ModuleRoot "Public"

        if (-not (Test-Path $psd1Path)) {
            throw "⚠️ .psd1 file not found at: $psd1Path"
        }

        # Collect all exported function names
        $functions = (Get-ChildItem -Path "$publicFolder\*.ps1" | ForEach-Object {
            "'$($_.BaseName)'"
        } | Sort-Object) -join ",`n        "

        $replacement = "FunctionsToExport = @(`n        $functions`n    )"

        # Read existing content
        $psd1Content = Get-Content $psd1Path -Raw

        # Replace FunctionsToExport block
        $updatedContent = $psd1Content -replace "(?s)FunctionsToExport\s*=\s*@\([^\)]*\)", $replacement
        Write-Host "✅ FunctionsToExport block updated."

        # Version bump
        if ($updatedContent -match "ModuleVersion\s*=\s*'(\d+)\.(\d+)\.(\d+)'") {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            $patch = [int]$matches[3] + 1
            $newVersion = "$major.$minor.$patch"

            $updatedContent = $updatedContent -replace "ModuleVersion\s*=\s*'\d+\.\d+\.\d+'", "ModuleVersion     = '$newVersion'"
            Write-Host "✅ ModuleVersion bumped to $newVersion"
        }

        # Save the updated .psd1
        Set-Content -Path $psd1Path -Value $updatedContent -Encoding UTF8
        Write-Host "✅ Manifest saved to $psd1Path"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
