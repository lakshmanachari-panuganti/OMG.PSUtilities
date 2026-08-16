# Build

The build folder is the authoritative automation entry point for this repository.

## Validate

```powershell
.\build\Test-Repository.ps1
.\build\Test-Repository.ps1 -IncludeScriptAnalyzer
```

Validation covers PowerShell syntax, manifests, Public-to-manifest exports,
private boundaries, and comment-based help.

### PSScriptAnalyzer warning ratchet

The committed `psscriptanalyzer-baseline.json` was initialized from the 1,683
warnings measured after Phase 6 across 15 rules. The largest groups were 938
indentation, 362 `PSAvoidUsingWriteHost`, and 323 closing-brace findings. Its
`warningCount` records the current total as debt is removed.

The baseline is a per-finding multiset keyed by rule, repository-relative path,
and a SHA256 hash of normalized source context. Duplicate identities retain an
exact count. This is stricter than a per-rule total: a warning moved to a new
file or context cannot consume unrelated historical debt. Matching warnings
remain visible; any unmatched warning fails validation.

Regenerate the baseline only when intentionally recording warning removal or
reviewed debt:

```powershell
.\build\Test-Repository.ps1 -UpdateWarningBaseline
```

## Build artifacts

```powershell
.\build\Build-Modules.ps1 -Clean
```

Artifacts are written to `artifacts/modules`. Work-in-progress scripts,
`plasterManifest.xml`, and module `.github` folders are excluded from published
packages.

## Compare published packages

```powershell
.\build\Build-Modules.ps1 -Clean
.\build\Compare-PublishedModule.ps1
```

The comparison downloads each artifact's exact Gallery version and checks every
relative path and SHA256 hash. `Save-Module` extracts only the module payload, so
the comparison excludes no package-manager metadata.
