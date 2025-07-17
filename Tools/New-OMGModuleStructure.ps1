
# New-OMGModuleStructure.ps1
$basePath = "OMG.PSUtilities"
$companyName = "OMG IT Solutions"

$modules = @{
    "OMG.PSUtilities.ActiveDirectory" = "PowerShell utilities for managing Active Directory environments."
    "OMG.PSUtilities.VSphere"         = "PowerShell automation for VMware vSphere virtual environments."
    "OMG.PSUtilities.AI"              = "AI-powered scripting tools, including chat, summarization, and generation."
    "OMG.PSUtilities.AzureDevOps"     = "Interact with Azure DevOps APIs, pipelines, repos, and work items."
    "OMG.PSUtilities.AzureCore"       = "Core Azure-related scripting, including identity and subscription management."
    "OMG.PSUtilities.ServiceNow"      = "ServiceNow automation and integration using PowerShell and REST APIs."
    "OMG.PSUtilities.Core"            = "General purpose PowerShell utilities and system-level tools."
}

foreach ($module in $modules.GetEnumerator()) {
    $name = $module.Key
    $description = $module.Value
    $folderPath = Join-Path -Path $basePath -ChildPath $name

    # Create folders
    New-Item -ItemType Directory -Force -Path (Join-Path $folderPath 'Public') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $folderPath 'Private') | Out-Null

    # Create .psm1 file
    $psm1Path = Join-Path $folderPath "$name.psm1"
    Set-Content -Path $psm1Path -Value @"
# Auto-generated module file
Get-ChildItem -Path \$PSScriptRoot\Public\*.ps1 -Recurse | ForEach-Object { . \$_.FullName }
"@

    # Create .psd1 file
    $psd1Path = Join-Path $folderPath "$name.psd1"
    New-ModuleManifest -Path $psd1Path `
        -RootModule "$name.psm1" `
        -Author "Lakshmanachari Panuganti" `
        -CompanyName $companyName `
        -Description $description `
        -ModuleVersion "0.1.0" `
        -FunctionsToExport @() `
        -PowerShellVersion "5.1" `
        -ErrorAction SilentlyContinue

    # README.md
    Set-Content -Path (Join-Path $folderPath "README.md") -Value "# $name`n`n$description`n"

    # CHANGELOG.md
    Set-Content -Path (Join-Path $folderPath "CHANGELOG.md") -Value "## Changelog`n- Initial scaffolding for $name"

    # plasterManifest.xml
    $plasterContent = @"
<plasterManifest schemaVersion="1.1" xmlns="http://www.microsoft.com/plaster">
  <metadata>
    <name>$name</name>
    <id>$(New-Guid)</id>
    <version>0.1.0</version>
    <title>$name</title>
    <description>$description</description>
    <author>OMG IT Solutions</author>
  </metadata>
  <parameters>
    <parameter name="ModuleName" type="text" required="true" default="$name" />
    <parameter name="Description" type="text" prompt="Enter module description" default="$description" />
  </parameters>
</plasterManifest>
"@
    Set-Content -Path (Join-Path $folderPath "plasterManifest.xml") -Value $plasterContent
}

Write-Host "Folder structure, manifests, and base files created successfully with updated module names" -ForegroundColor Green
