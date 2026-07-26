# Architecture

## Design goals

OMG.PSUtilities is a portfolio of independently versioned PowerShell modules.
Each module is directly publishable to PowerShell Gallery and follows the same
simple internal structure:

```text
OMG.PSUtilities.ModuleName/
|-- Public/                 Exported commands, one command per file
|-- Private/                Internal helpers, never exported
|-- ModuleName.psm1         Loader and explicit exports
|-- ModuleName.psd1         Package metadata and dependencies
|-- README.md
`-- CHANGELOG.md
```

Module folders remain at the repository root intentionally. PowerShell Gallery
expects the manifest and module file at the package root, so this structure keeps
local development and published artifacts aligned without path translation.

## Repository layers

| Layer | Responsibility |
| --- | --- |
| Module folders | Runtime code and module-specific documentation |
| `OMG.PSUtilities/` | Meta-module with explicit dependencies on every portfolio module |
| `build/` | Validation and deterministic artifact construction |
| `tests/` | Pester architecture and behavior tests |
| `.github/workflows/` | Pull-request validation and Gallery release automation |
| `docs/` | Architecture, release, and integration-test documentation |

## Public API rules

- Public commands live in `Public/` and are explicitly listed in the manifest.
- Private helpers live in `Private/` and are never exported.
- Files ending in `--wip.ps1` are excluded from loading and release artifacts.
- Existing public command names are preserved unless a documented breaking release is planned.
- Every public command includes comment-based help and clear output documentation.

## Versioning

Each module uses semantic versioning independently:

- Patch: bug fix or documentation correction with no public contract change.
- Minor: backward-compatible command or parameter addition.
- Major: breaking public API or behavior change.

The meta-module version changes when its dependency set or minimum dependency
versions change. CI publishes only versions newer than PowerShell Gallery.

## Compatibility

Compatibility is declared per module rather than forcing the whole portfolio to
claim the same runtime. AzureCore and AzureDevOps require PowerShell 7. The
meta-module therefore requires PowerShell 7 because it installs both modules.

## Security boundaries

- Credentials are accepted as `SecureString` or `PSCredential` where practical.
- Secrets are never committed to the repository or embedded in workflow files.
- PowerShell Gallery publishing uses the `PSGALLERY_API_KEY` GitHub Actions secret.
- Azure integration tests should use GitHub OIDC federation instead of client secrets.
