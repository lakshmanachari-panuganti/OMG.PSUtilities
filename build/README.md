# Build

The build folder is the authoritative automation entry point for this repository.

## Validate

```powershell
.\build\Test-Repository.ps1
.\build\Test-Repository.ps1 -IncludeScriptAnalyzer
```

Validation covers PowerShell syntax, manifests, Public-to-manifest exports,
private boundaries, and comment-based help.

## Build artifacts

```powershell
.\build\Build-Modules.ps1 -Clean
```

Artifacts are written to `artifacts/modules`. Work-in-progress scripts,
`plasterManifest.xml`, and module `.github` folders are excluded from published
packages.
