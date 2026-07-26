# Contributing

## Development workflow

1. Create a feature branch from `main`.
2. Keep each public command in one file under the owning module's `Public/` folder.
3. Keep internal helpers under `Private/` and document their inputs and outputs.
4. Update the module manifest exports and CHANGELOG when public behavior changes.
5. Run the complete local quality gate.

```powershell
.\build\Test-Repository.ps1 -IncludeScriptAnalyzer
Invoke-Pester -Path .\tests -Output Detailed
.\build\Build-Modules.ps1 -Clean
```

## Coding style

- Use approved PowerShell verbs.
- Use K&R braces and four-space indentation.
- Put each parameter attribute and type declaration on its own line.
- Use a blank line between parameters.
- Put setup and runtime validation in `begin` for pipeline functions.
- Prefer clear code over new abstractions.
- Do not expose private helpers without a public use case.
- Do not commit secrets, generated reports, or build artifacts.

## Pull requests

Keep changes focused. Describe the behavior change and the validation performed.
The validation workflow must pass before merge. A release requires an appropriate
module version increase; otherwise CI deliberately skips Gallery publication.
