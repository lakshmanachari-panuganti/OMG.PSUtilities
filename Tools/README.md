# 🛠 OMG.PSUtilities - Internal Tools

These scripts are used for developing, building, and maintaining the OMG.PSUtilities module family.

## Scripts

- `New-OMGModuleStructure.ps1` – Creates a new module folder layout with Plaster, readme, changelog.
- `Update-OMGModuleManifests.ps1` – Auto-updates .psm1 & .psd1 exports for each submodule.
- `Build-OMGModuleLocally.ps1` – Imports and tests modules with `_temp` prefix.
- `Bump-ModuleVersion.ps1` – (Optional) Increments version in `.psd1`.
- `Git-AutoTagAndPush.ps1` – (Optional) Git version tagging & push automation.
