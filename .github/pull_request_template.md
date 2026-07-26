## Summary

Describe the problem and the solution.

## Validation

- [ ] `.\build\Test-Repository.ps1 -IncludeScriptAnalyzer`
- [ ] `Invoke-Pester -Path .\tests -Output Detailed`
- [ ] `.\build\Build-Modules.ps1 -Clean`

## Module release

- [ ] Public behavior changes are documented in the module CHANGELOG.
- [ ] The module version is increased when a Gallery release is required.
- [ ] No credentials, generated reports, or local artifacts are included.