# Tests

The automated test suite validates the architecture shared by every module.

```powershell
Invoke-Pester -Path .\tests -Output Detailed
```

Tests that call external systems belong in module-specific integration suites and
must use mocks in pull-request validation. Live integration checks should run only
from explicitly triggered workflows with repository secrets.