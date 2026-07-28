
## Executive Summary

The project demonstrates strong **structural discipline** — consistent module layout, uniform dot-source loaders, comprehensive comment-based help, and proper use of `CmdletBinding`, `ShouldProcess`, and `Write-Log`. You've clearly internalized PowerShell best practices at the function level.


---

## 🔴 CRITICAL — Fix Before Anyone Uses This

### 1. Credentials Stored as Plain Strings

This is the **single most dangerous issue** in the project.

| Module | Parameter | Type | Should Be |
|--------|-----------|------|-----------|
| AzureCore | `$ClientSecret` | `[string]` | `[SecureString]` or `[PSCredential]` |
| AzureDevOps | `$PersonalAccessToken` | `[string]` | `[SecureString]` |
| ServiceNow | `$Username` / `$Password` | `[string]` | `[PSCredential]` |

Only `Connect-VSphereEnvironment` uses `[PSCredential]` correctly. The rest expose secrets in:
- PowerShell transcript logs
- Process memory (as clear-text .NET strings)
- Command history (`Get-History`)
- PSReadLine history file (`~\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\`)

> [!CAUTION]
> Anyone who types `Connect-AzDevOps -PersonalAccessToken "my-pat"` has that PAT permanently saved in their shell history. This is a **credential leak vector**.

**Fix**: Use `[PSCredential]` or `[SecureString]` everywhere. Provide a `-Credential` parameter following the PowerShell standard pattern.

---

### 2. Zero Tests for 5 Out of 8 Modules

| Module | Test File | Verdict |
|--------|-----------|---------|
| OMG.PSUtilities | ✅ Exists | Partial coverage |
| OMG.PSUtilities.Core | ✅ Exists | Partial coverage |
| OMG.PSUtilities.AI | ✅ Exists | **All tests skip** (requires live Ollama) |
| OMG.PSUtilities.ActiveDirectory | ❌ None | **Untested** |
| OMG.PSUtilities.AzureCore | ❌ None | **Untested** |
| OMG.PSUtilities.AzureDevOps | ❌ None | **Untested** |
| OMG.PSUtilities.ServiceNow | ❌ None | **Untested** |
| OMG.PSUtilities.VSphere | ❌ None | **Untested** |
| OMG.DevTools | ❌ None | **Untested** |
| Additional Tools | ❌ None | **Untested** |
| Tools scripts | ❌ None | **Untested** |

The modules that **talk to production systems** (AD, Azure, DevOps, ServiceNow, vSphere) — i.e., the ones where bugs cause real damage — have **zero automated tests**.

Even the modules with test files have significant gaps:
- `Install-RequiredModules` and `New-ModuleProject` — the two most complex and risky functions in the base module — are **untested**.
- No negative/failure test cases anywhere.
- No pipeline integration tests.
- No mocking whatsoever — everything is an integration test.

> [!WARNING]
> The AI module tests are structured so that they **always skip** in CI because they require a live Ollama instance. Effectively, the AI module has zero CI test coverage.

---

## 🟠 HIGH — Significant Design Gaps

### 3. You Built `New-RetryOperation` and Then Never Used It

`New-RetryOperation` in `OMG.PSUtilities.Core` implements retry with exponential backoff. It's well-written. It's also **completely unused**.

Every `Invoke-*API` function across the project makes raw HTTP calls with **no retries**:
- `Invoke-OllamaAPI` — no retries
- `Invoke-AzDevOpsAPI` — no retries
- `Invoke-ServiceNowAPI` — no retries
- Azure calls via `Invoke-AzRestMethod` — no retries

These are network calls to external services. They **will** fail intermittently. You already solved this problem — you just forgot to use the solution.

---

### 4. API Pagination is Completely Missing

Every API-consuming module fetches page 1 and calls it done:

| Module | Issue |
|--------|-------|
| AzureDevOps | No continuation token handling. `Get-AzDevOpsProject` may return only the first page of projects. |
| ServiceNow | `sysparm_limit=100` hardcoded. Incidents 101+ are silently dropped. |
| AzureCore | `Get-AzResource` returns all, but `Get-AzureCostReport` via REST API doesn't paginate. |

Users will silently receive **incomplete data** and have no way to know. No warning, no `Write-Warning`, nothing.

> [!IMPORTANT]
> Silent data truncation is worse than an error. Users make decisions on incomplete data believing it's complete.

---

### 5. No Disconnect / Cleanup Functions

| Module | `Connect-*` | `Disconnect-*` |
|--------|------------|----------------|
| AzureCore | ✅ | ❌ |
| AzureDevOps | ✅ | ❌ |
| ServiceNow | ✅ | ❌ |
| VSphere | ✅ | ❌ |

Connection state lives in module-scoped variables (`$script:*Config`) that never get cleaned up. There's no way to:
- Switch connections (e.g., dev → prod)
- Clear cached credentials from memory
- Gracefully close connections

The VSphere module is especially problematic — `Connect-VIServer` creates a persistent session that should be explicitly disconnected.

---

### 6. Hardcoded Certificate Bypass in VSphere

```powershell
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
```

This is **hardcoded** — every user of this module automatically ignores invalid TLS certificates. Fine for a lab, dangerous in production, and gives the user **no choice**.

**Fix**: Add a `-SkipCertificateCheck` switch that defaults to `$false`.

---

## 🟡 MEDIUM — Code Smells & Inconsistencies

### 7. Three Competing Module Scaffolding Tools

You have **three** different ways to create a new module:

1. `New-ModuleProject` — function in the base module
2. `plasterManifest.xml` — Plaster template at project root
3. `New-ModuleFromTemplate.ps1` — standalone script in `Module Developer Tools/`

Which one should a developer use? They each produce slightly different scaffolds. `New-ModuleProject` hardcodes an MIT license. The Plaster template has different parameters. The standalone script has its own opinions.

**Fix**: Pick one. Delete the others. Document the chosen approach.

---

### 8. Duplicate Functionality Across Boundaries

| Capability | Location 1 | Location 2 |
|-----------|-----------|-----------|
| Module installation | `Install-RequiredModules` (base module) | `Install-Dependencies.ps1` (Tools/) |
| Environment reporting | `Get-EnvironmentInfo` (base module) | `Export-EnvironmentReport.ps1` (Additional Tools/) |
| Test execution | `build.ps1` (build/) | `Run-AllTests.ps1` (Tools/) |
| Code analysis | `Invoke-CodeAnalysis` (DevTools) | `build.ps1` PSScriptAnalyzer step |
| Test scaffolding | `New-TestScaffold` (DevTools) | `New-ModuleProject` (base module) |

Each pair solves the same problem slightly differently. This creates confusion about which is the "right" way.

---

### 9. Non-Approved PowerShell Verbs

```
Run-AllTests.ps1      → should be Invoke-AllTests
Generate-Report.ps1   → should be New-Report
```

`Get-Verb` exists for a reason. Non-approved verbs generate import warnings and confuse PowerShell users who rely on verb conventions to discover functionality.

---

### 10. `Write-Log` Thread Safety

`Write-Log` uses `Add-Content` for file output with no file locking or mutex. If two runspaces/jobs write to the same log file simultaneously:
- Lines will interleave
- Writes may fail with access denied
- Data corruption is possible

If you're promoting `Write-Log` as the universal logging function, it needs to handle concurrent use.

---

### 11. No Backoff Jitter in `New-RetryOperation`

```powershell
$DelaySeconds * [math]::Pow(2, $attempt - 1)
```

Pure exponential backoff without jitter. When 100 clients retry simultaneously after a service outage, they all retry at the same exponentially-spaced intervals — causing **thundering herd** spikes instead of smooth load distribution.

**Fix**: Add random jitter: `$delay * (0.5 + (Get-Random -Minimum 0 -Maximum 100) / 100)`

---

### 12. Circular Reference Bomb in `ConvertTo-HashTable`

```powershell
# This will cause infinite recursion:
$obj = [PSCustomObject]@{ Name = "test" }
$obj | Add-Member -NotePropertyName Self -NotePropertyValue $obj
$obj | ConvertTo-HashTable  # 💥 StackOverflowException
```

No depth tracking, no circular reference detection.

---

## 🔵 LOW — Polish & Best Practices

### 13. No Code Coverage Metrics

- No Pester code coverage configuration
- No coverage thresholds in CI
- No coverage badge in README
- You literally cannot answer "what percentage of our code is tested?"

### 14. CI/CD Pipeline Gaps

- ✅ CI runs on push/PR (good)
- ❌ No test result publishing as artifacts
- ❌ No coverage reporting
- ❌ No automated publishing (CD)
- ❌ No version bump automation
- ❌ No branch protection rules
- ❌ `publish.ps1` doesn't verify tests passed before publishing

### 15. No `about_` Help Files

PowerShell modules should provide `about_<ModuleName>.help.txt` files. These show up when users run `Get-Help about_OMG.PSUtilities` and are the standard way to document module-level concepts, configuration, and getting-started guides.

### 16. No Auto-Generated Cmdlet Docs

`Build-ModuleDocumentation` exists in DevTools but doesn't use [PlatyPS](https://github.com/PowerShell/platyPS) — the standard in the PowerShell ecosystem. PlatyPS generates MAML-based help that integrates with `Get-Help` and produces consistent markdown docs.

### 17. CHANGELOG is Too Vague

```markdown
## [1.3.0] - 2024-XX-XX
### Added
- Added new utility functions
```

"Added new utility functions" tells the reader nothing. What functions? What do they do? Why were they added?

### 18. Config Files Have No Schema Validation

Every `Initialize-*Configuration.ps1` loads a JSON file and trusts whatever's in it. Malformed JSON, missing keys, wrong types — none of these are caught. A corrupted config file will cause cryptic errors deep in function execution instead of a clear "your config file is invalid" message at module load.

### 19. `.gitignore` Missing Common Patterns

```
*.log        # Write-Log output files
.env         # Environment files with secrets
*.pfx        # Certificate files
*.key        # Private keys
```

If someone accidentally drops a `.env` file or a log with sensitive data in the repo, it'll get committed.

### 20. `Get-FolderSize` Defaults `$Recurse` to `$true`

Most PowerShell commands default to non-recursive. A user who runs `Get-FolderSize -Path C:\` expecting a quick surface-level check will accidentally scan the entire filesystem.

---

## 📊 Scoring Summary

| Category | Score | Notes |
|----------|-------|-------|
| **Module Structure** | 9/10 | Consistent, clean, follows conventions |
| **Function Quality** | 8/10 | Good help, validation, error handling |
| **Security** | 3/10 | Plain-text credentials across 3 modules |
| **Test Coverage** | 2/10 | 5+ modules completely untested |
| **API Robustness** | 3/10 | No pagination, no retries, no rate limiting |
| **Documentation** | 5/10 | Good function help, weak module/project docs |
| **Build & CI/CD** | 5/10 | CI exists, no CD, no coverage, no gates |
| **DRY / Cohesion** | 4/10 | Duplicate tools, triple scaffolding |
| **Production Readiness** | 3/10 | Would not recommend for production use as-is |

**Overall: 4.7 / 10** — Good bones, but not ready to ship.

---

## 🛣️ Recommended Prioritized Roadmap

### Phase 1 — Security & Safety (Week 1)
1. Replace all `[string]` credential parameters with `[PSCredential]` or `[SecureString]`
2. Add `Disconnect-*` functions for all connection modules
3. Make VSphere certificate bypass opt-in, not default
4. Add `.env`, `*.log`, `*.pfx`, `*.key` to `.gitignore`

### Phase 2 — Testing (Week 2-3)
5. Add Pester tests for all 5 untested modules (use mocks for external dependencies)
6. Add negative/failure test cases to existing tests
7. Mock `Invoke-RestMethod` in AI module tests so they run in CI
8. Add tests for `Install-RequiredModules` and `New-ModuleProject`
9. Configure Pester code coverage and set a minimum threshold (aim for 70%+)

### Phase 3 — API Robustness (Week 3-4)
10. Add pagination support to all `Invoke-*API` and `Get-*` functions
11. Wire up `New-RetryOperation` in all `Invoke-*API` functions
12. Add jitter to retry backoff
13. Add circular reference detection to `ConvertTo-HashTable`
14. Add thread-safe file locking to `Write-Log`

### Phase 4 — Cleanup & Polish (Week 4-5)
15. Consolidate scaffolding tools — pick one, delete the rest
16. Move standalone scripts into modules or document as "extras"
17. Fix non-approved verbs
18. Add config file schema validation
19. Improve CHANGELOG specificity
20. Generate PlatyPS docs and `about_` help files
21. Add code coverage reporting and badges to CI
22. Add CD pipeline for PSGallery publishing

---

> [!NOTE]
> This review is intentionally harsh — the structural consistency, logging discipline, and comment-based help coverage across this project are genuinely impressive for a PowerShell module suite. Most PowerShell projects in the wild don't come close to this level of discipline.
>
> The issues above are real, but they're the kind of issues that emerge when a project grows from a personal toolkit into something others depend on. The foundation is strong. The gaps are fillable.

## 📊 Code Quality Audit

A detailed code‑quality audit for the core functions has been generated. See the full report:

[CodeQualityAudit.md](file:///C:/Users/E092721/.gemini/antigravity/brain/ff730ec3-7501-4b38-8ac8-4576eadb1e65/CodeQualityAudit.md)

## Full Code Quality Audit

# Executive Summary Matrix

| # | File Name | Size (Bytes / Lines) | Help | Param Validation | Try/Catch | Pipeline | Security Concerns | Key Code Smells / Issues | ShouldProcess | Hardcoded URLs/Paths |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `Export-PSUExcel.ps1` | 7,053 B / 188 L | ✅ Complete | ✅ `ValidateScript` | ✅ Yes | ✅ Yes | None | `+=` array accumulation; `Write-Host` for backup logging; logic bug in default `WorksheetName` check | ❌ No | Help links only |
| 2 | `Send-PSUTeamsMessage.ps1` | 2,033 B / 58 L | ⚠️ Incomplete ("TODO") | ⚠️ Basic mandatory | ⚠️ `Write-Error` only | ❌ No | Webhook URL contains secret tokens | Missing `[CmdletBinding()]`; Help says `.OUTPUTS None` but returns `$response`; deprecated Teams webhook format | ❌ No | Help example URL |
| 3 | `Get-PSUCredentialFromManager.ps1` | 2,770 B / 79 L | ✅ Complete | ✅ `ValidateNotNullOrEmpty` | ✅ Yes | ❌ No | `-Clipboard` exposes plain text pwd to Clipboard; RAM string copies | Unchecked dependency on `[CredentialManager.CredMan]` without loading check | N/A (Read) | Help links only |
| 4 | `Unlock-PSUTerraformStateAWS.ps1` | 8,995 B / 232 L | ✅ Complete | ❌ Weak | ❌ **`exit 1` in catch** | ❌ No | Plain text AWS SecretKey parameter | **`exit 1` terminates caller PS process**; heavy `Read-Host` interactive prompts; 20+ `Write-Host` calls | ❌ Custom prompt | Hardcoded AWS region "us-east-2" |
| 5 | `Invoke-PSUAiPrompt.ps1` | 3,239 B / 90 L | ✅ Complete | ✅ `ValidateSet` | ❌ No try/catch | ❌ No | Persistently modifies `$env:DEFAULT_AI_ENGINE` | Unexpected side-effect of setting user environment variable; case mismatch in switch vs `ValidateSet` | N/A (Read) | None |
| 6 | `Start-PSUGeminiChat.ps1` | 3,701 B / 104 L | ✅ Complete | ⚠️ Manual check | ✅ Yes | ❌ No | API Key passed in URL query string | `SupportsShouldProcess` used on read-only interactive session; `+=` array accumulation | ✅ Yes | Google API endpoint URL |
| 7 | `Set-PSUAzureOpenAIEnvironment.ps1` | 16,272 B / 342 L | ✅ Complete | ✅ `ValidateSet` | ✅ Yes | ❌ No | Returns plain text `ApiKey` in output object | Relies on external non-standard helpers; mixes `Az` module with `az` CLI; interactive `Read-Host` |
| 8 | `New-PSUAiPoweredPullRequest.ps1` | 13,396 B / 297 L | ✅ Complete | ✅ `ValidateScript` | ✅ Yes | ❌ No | Copies PR body to Clipboard; uses PAT/token | Param doc mismatch (`PullRequestTemplate` vs `PullRequestTemplatePath`); interactive `Read-Host` prompts |
| 9 | `Get-PSUADOVariableGroupInventory.ps1` | 31,673 B / 588 L | ✅ Complete | ✅ `ValidateRange` / `ValidateScript` | ✅ Yes | ❌ No (Help claims pipeline support) | Masks PAT & secret variables | High complexity (588 lines); heavy code duplication between parallel/sequential paths; `Write-Host` logging; `.xlsx` validation flaw |
| 10 | `New-PSUADOPPullRequest.ps1` | 15,248 B / 338 L | ✅ Complete | ✅ `ParameterSetName` | ✅ Yes | ❌ No | Masks PAT in verbose logs | `begin` block throws error if branch isn't local or if run outside local repo; **missing `SupportsShouldProcess`** |
| 11 | `Invoke-PSUAzureAppRegAudit.ps1` | 61,694 B / 1,111 L | ✅ Complete | ❌ Weak | ✅ Yes | ❌ No | Scans sensitive Entra ID security data | **Monolithic function (1,111 lines)**; 50-line ASCII table via `Write-Host`; **ShouldProcess declared but NEVER called**; default output dirs write to `$PSScriptRoot` |
| 12 | `Find-PSUADServiceAccountMisuse.ps1` | 5,834 B / 147 L | ✅ Complete | ❌ Weak | ❌ **No try/catch** | ❌ No | Scans event logs across DCs | Default `$Server = $env:COMPUTERNAME` fails on workstations; `Format-Table` inside function pollutes pipeline; `ExportPath` mismatch |
| 13 | `New-PSUOutlookMeeting.ps1` | 11,235 B / 293 L | ✅ Complete | ✅ `ValidateSet` | ✅ Yes | ❌ No | None | **Missing `SupportsShouldProcess`** on state-changing cmdlet; `+=` array accumulation; string date formatting assumptions |
| 14 | `New-PSUGithubPullRequest.ps1` | 12,036 B / 279 L | ✅ Complete | ✅ `ValidateNotNullOrEmpty` | ✅ Yes | ❌ No | GitHub token in param/env | **Dead/Incomplete Auto-Merge code** (builds payload but never calls `Invoke-RestMethod`); **missing `SupportsShouldProcess`** |

---

# Detailed File-by-File Analysis

### 1. `Export-PSUExcel.ps1`
- **File size & Line count**: 7,053 Bytes | 188 Lines
- **Comment-based help**: ✅ Complete (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER` for all params, `.EXAMPLE` (4 examples), `.OUTPUTS`, `.NOTES`, `.LINK`).
- **Parameter validation**: ✅ `[Parameter(Mandatory, ValueFromPipeline = $true)]` for `$DataObject`, and `[ValidateScript({...})]` on `$ExcelPath` verifying parent directory existence and `.xlsx` file extension.
- **Error handling**: ✅ `try ... catch` block in the `end` block using `$PSCmdlet.ThrowTerminatingError($_)`.
- **Pipeline support**: ✅ Supported (`ValueFromPipeline = $true` on `$DataObject`), accumulating items in `process` block.
- **Security concerns**: None.
- **Code smells**: 
  1. `$allData += $DataObject` in `process` block causes array re-allocation per item (performance concern for large pipelines).
  2. Uses `Write-Host` (line 131) instead of `Write-Verbose` or `Write-Information`.
  3. Logic bug on line 140: `-not $PSBoundParameters.ContainsKey('WorksheetName')` checks parameter bound status, but `$WorksheetName` has a default value `"Sheet1"`. If a caller does not pass `-WorksheetName` explicitly, it deletes existing files even when `-KeepBackup` is not specified.
- **ShouldProcess**: ❌ Not implemented, despite executing file deletion (`Remove-Item -Force`) and moving files (`Move-Item`).
- **Hardcoded URLs/Paths**: Documentation URLs in comment help.
- **Other Notable**: Depends on the `ImportExcel` module (`Export-Excel`, `Set-ExcelRange`, `Close-ExcelPackage`). Formats header row with black background and bold white text.

---

### 2. `Send-PSUTeamsMessage.ps1`
- **File size & Line count**: 2,033 Bytes | 58 Lines
- **Comment-based help**: ⚠️ Present but contains unfinished documentation notice: "TODO: Still in testing phrase!".
- **Parameter validation**: ⚠️ Minimal `[Parameter(Mandatory)]` only. Missing `[ValidateNotNullOrEmpty()]` or URI format validation for `$WebhookUrl`.
- **Error handling**: ⚠️ Uses `try/catch`, but in `catch` it invokes `Write-Error` (non-terminating) instead of throwing or using `$PSCmdlet.ThrowTerminatingError($_)`.
- **Pipeline support**: ❌ No pipeline support.
- **Security concerns**: Incoming Webhook URLs function as bearer tokens; passing them in plain text without secure handling should be noted.
- **Code smells**:
  1. Missing `[CmdletBinding()]` attribute.
  2. Mismatch: Help states `.OUTPUTS None`, but the code returns `$response`.
  3. Uses Office 365 Incoming Webhooks which are deprecated/being retired by Microsoft Teams in favor of Workflows.
- **ShouldProcess**: ❌ Not implemented.
- **Hardcoded URLs/Paths**: Help example includes `'https://outlook.office.com/webhook/...'`.
- **Other Notable**: Draft/incomplete function ("TODO: Still in testing phrase!").

---

### 3. `Get-PSUCredentialFromManager.ps1`
- **File size & Line count**: 2,770 Bytes | 79 Lines
- **Comment-based help**: ✅ Complete (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`, `.NOTES`, `.LINK`).
- **Parameter validation**: ✅ `[Parameter(Mandatory)]` and `[ValidateNotNullOrEmpty()]` on `$Target`.
- **Error handling**: ✅ `try ... catch` using `$PSCmdlet.ThrowTerminatingError($_)`.
- **Pipeline support**: ❌ No pipeline support.
- **Security concerns**:
  1. `-Clipboard` switch parameter copies plain text password (`$CredentialManager.Password | Set-Clipboard`) to Windows clipboard. While documented in help, this risks exposing credentials to clipboard loggers.
  2. Converts password string to `SecureString` using `.ToCharArray()`, creating intermediate plain text copies in RAM.
- **Code smells**: Unchecked dependency on `[CredentialManager.CredMan]` .NET type without checking if the assembly/module is loaded.
- **ShouldProcess**: N/A (Read operation).
- **Hardcoded URLs/Paths**: Documentation links in help.
- **Other Notable**: Assigns custom PSTypeName `PSU.CredentialManager.Credential` and alias `fetchcred`.

---

### 4. `Unlock-PSUTerraformStateAWS.ps1`
- **File size & Line count**: 8,995 Bytes | 232 Lines
- **Comment-based help**: ✅ Complete (placed above `function` keyword).
- **Parameter validation**: ❌ Weak (no `[ValidateNotNullOrEmpty()]` or regex validation on parameters).
- **Error handling**: ❌ **CRITICAL BUG**: In the catch block (line 225), it calls `exit 1`! In PowerShell, calling `exit` inside a script function terminates the entire host process / user session!
- **Pipeline support**: ❌ No pipeline support.
- **Security concerns**: Accepts AWS secret keys via plain text `[string]$SecretKey` parameter instead of `[SecureString]` or standard AWS credential profiles.
- **Code smells**:
  1. **`exit 1` in catch block**.
  2. Heavy reliance on interactive `Read-Host` prompts (lines 86, 165, 196), preventing automated/non-interactive execution.
  3. Excessive `Write-Host` calls (over 20 instances).
  4. Implements custom interactive `Read-Host` confirmation prompt instead of using `SupportsShouldProcess`.
- **ShouldProcess**: ❌ Not implemented (uses custom `Read-Host` prompt instead).
- **Hardcoded URLs/Paths**: Default region "us-east-2".
- **Other Notable**: Properly restores location using `Get-Location` and `Set-Location` in a `finally` block.

---

### 5. `Invoke-PSUAiPrompt.ps1`
- **File size & Line count**: 3,239 Bytes | 90 Lines
- **Comment-based help**: ✅ Complete.
- **Parameter validation**: ✅ `[Parameter(Mandatory, Position = 0)]` for `$Prompt`, `[ValidateSet("AzureOpenAi", "GeminiAi", "PerplexityAi")]` for `$DefaultAiEngine`.
- **Error handling**: ❌ No `try/catch` block (throws raw exceptions directly).
- **Pipeline support**: ❌ No pipeline support.
- **Security concerns**: Modifies user environment variables persistently via `Set-PSUUserEnvironmentVariable` as a side effect if `$env:DEFAULT_AI_ENGINE` is not set.
- **Code smells**:
  1. Side effect: Modifies user environment variables permanently when `$env:DEFAULT_AI_ENGINE` is missing.
  2. Case sensitivity mismatch: `ValidateSet` uses CamelCase (`AzureOpenAi`), while `switch` statement converts string to lower case (`azureopenai`).
- **ShouldProcess**: N/A (Dispatch query).
- **Hardcoded URLs/Paths**: None.
- **Other Notable**: Central router function for AI prompts. Alias `askai`.

---

### 6. `Start-PSUGeminiChat.ps1`
- **File size & Line count**: 3,701 Bytes | 104 Lines
- **Comment-based help**: ✅ Complete.
- **Parameter validation**: ⚠️ Manual check `if (-not $ApiKey)`. Lacks `[ValidateNotNullOrEmpty()]`.
- **Error handling**: ✅ `try/catch` inside `while` loop around `Invoke-RestMethod`.
- **Pipeline support**: ❌ No pipeline support.
- **Security concerns**: Passes Gemini API key as a URL query parameter (`?key=$ApiKey`), which can be exposed in proxy logs or HTTP request traces.
- **Code smells**:
  1. Uses `SupportsShouldProcess` for starting a read-only interactive CLI chat session (inappropriate use of `ShouldProcess`).
  2. Array accumulation `$chatHistory += ...` inside while loop.
  3. Commented-out line of code (line 92).
- **ShouldProcess**: ✅ Implemented (`[CmdletBinding(SupportsShouldProcess)]`), though unnecessary for read-only CLI chat.
- **Hardcoded URLs/Paths**: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$ApiKey`
- **Other Notable**: Interactive CLI chat session with `PSAvoidUsingWriteHost` suppression rule.

---

### 7. `Set-PSUAzureOpenAIEnvironment.ps1`
- **File size & Line count**: 16,272 Bytes | 342 Lines
- **Comment-based help**: ✅ Complete.
- **Parameter validation**: ✅ `[ValidateSet('eastus', 'eastus2', 'westus', 'westus2')]` for Location, `[ValidateSet('gpt-4', 'gpt-35-turbo', 'gpt-4-turbo', 'gpt-4o')]` for ModelName.
- **Error handling**: ✅ `try ... catch` with `$PSCmdlet.ThrowTerminatingError($_)` and internal try/catches.
- **Pipeline support**: ❌ No pipeline support.
- **Security concerns**: Returns a `PSCustomObject` containing the raw API key (`ApiKey = $apiKey`) in plain text. Automatically installs missing modules (`Install-Module -Force -AllowClobber`) without confirmation.
- **Code smells**:
  1. Relies on custom non-standard helper logging functions (`Write-Step`, `Write-Info`, `Write-Success`, `Write-ErrorMsg`).
  2. Tooling mismatch: Mixes `Az` PowerShell cmdlets with Azure CLI (`az`) commands, requiring both prerequisites.
  3. Interactive `Read-Host` selection menus inside `process` block.
- **ShouldProcess**: ✅ Implemented (`[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`).
- **Hardcoded URLs/Paths**: `https://aka.ms/oai/access` and `https://portal.azure.com`.
- **Other Notable**: Attaches custom PSTypeName `PSU.AzureOpenAI.Configuration`.

---

### 8. `New-PSUAiPoweredPullRequest.ps1`
- **File size & Line count**: 13,396 Bytes | 297 Lines
- **Comment-based help**: ✅ Complete (minor parameter name discrepancy in help `.PARAMETER PullRequestTemplate` vs code `$PullRequestTemplatePath`).
- **Parameter validation**: ✅ `[ValidateNotNullOrEmpty()]` and `[ValidateScript({...})]`.
- **Error handling**: ✅ `try ... catch ... finally` block (restores location in `finally`).
- **Pipeline support**: ❌ No pipeline support.
- **Security concerns**: Copies PR title and body to clipboard (`Set-Clipboard`).
- **Code smells**:
  1. Help parameter mismatch (`PullRequestTemplate` vs `PullRequestTemplatePath`).
  2. Interactive `Read-Host` prompts interrupt automated CI/CD execution.
  3. Duplicated PR creation logic between `'Y'` and `'D'` switch branches.
- **ShouldProcess**: ✅ Implemented (`[CmdletBinding(SupportsShouldProcess)]`).
- **Hardcoded URLs/Paths**: Help example references `"C:\Temp\PRTemplate.txt"`.
- **Other Notable**: Orchestrates Git change detection, AI prompt formatting, HTML summary preview, and PR creation across GitHub and Azure DevOps.

---

### 9. `Get-PSUADOVariableGroupInventory.ps1`
- **File size & Line count**: 31,673 Bytes (31.7 KB) | 588 Lines
- **Comment-based help**: ✅ Complete (syntax flaw: `.PARAMETER $project` has a leading `$`).
- **Parameter validation**: ✅ `[ValidateNotNullOrEmpty()]`, `[ValidateScript()]`, and `[ValidateRange(1, 20)]`.
- **Error handling**: ✅ Extensive `try/catch` blocks across API requests, job handling, and export operations.
- **Pipeline support**: ❌ No pipeline support (Param block lacks `ValueFromPipeline = $true`, contradicting help text).
- **Security concerns**: Masks PAT in console output; replaces secret variable values with `'********'` when `-IncludeVariableDetails` is specified.
- **Code smells \& Complexity**:
  1. Overly long function (588 lines) with high cyclomatic complexity.
  2. **Major Code Duplication**: Variable group collection logic is duplicated almost line-for-line between parallel `ThreadJob` scriptblock (lines 253-349) and sequential fallback loop (lines 428-508).
  3. Excessive `Write-Host` logging instead of `Write-Verbose` / `Write-Information`.
  4. `ValidateScript` for `$OutputFilePath` allows `.xlsx` extension, but export logic only supports `.csv`, `.json`, `.xml`. Passing `.xlsx` causes silent export failure.
  5. Unimplemented comment on line 521: `# TODO: Integrate $Filter parameter...`.
- **ShouldProcess**: N/A (Read operation).
- **Hardcoded URLs/Paths**: Azure DevOps REST API endpoints (`https://dev.azure.com/...`).
- **Other Notable**: Multi-threaded parallel processing using `Start-ThreadJob`. Custom PSTypeName `PSU.ADO.VariableGroupInventory`.

---

### 10. `New-PSUADOPullRequest.ps1`
- **File size & Line count**: 15,248 Bytes | 338 Lines
- **Comment-based help**: ✅ Complete.
- **Parameter validation**: ✅ `[ValidateNotNullOrEmpty()]` and `ParameterSetName` ('ByRepoId', 'ByRepoName').
- **Error handling**: ✅ `try ... catch` calling `$PSCmdlet.ThrowTerminatingError($_)`.
- **Pipeline support**: 0 No pipeline support.
- **Security concerns**: Masks PAT token in verbose log outputs.
- **Code smells**:
  1. Branch validation flaw in `begin` block: Runs `git branch --list` to validate `$SourceBranch` and `$TargetBranch`. If the branch is remote-only or the command is executed outside a git repo, it throws an error.
  2. **MISSING `SupportsShouldProcess`**: State-changing `New-` function makes POST/PATCH API calls without `ShouldProcess`.
- **ShouldProcess**: ❌ **Not implemented**.
- **Hardcoded URLs/Paths**: Azure DevOps REST API endpoints.
- **Other Notable**: Supports setting auto-completion options on PR creation via PATCH API request. Custom PSTypeName `PSU.ADO.PullRequest`.

---

### 11. `Invoke-PSUAzureAppRegAudit.ps1`
- **File size & Line count**: 61,694 Bytes (61.7 KB) | 1,111 Lines
- **Comment-based help**: ✅ Complete.
- **Parameter validation**: ❌ Weak (lacks `[ValidateNotNullOrEmpty()]` or `[ValidateScript()]`).
- **Error handling**: ✅ `try ... catch` with `$PSCmdlet.ThrowTerminatingError($_)` and internal try/catches.
- **Pipeline support**: ❌ No pipeline support.
- **Security concerns**: Audits sensitive tenant security configurations (expired secrets, RBAC, privileges, legacy auth).
- **Code smells \& Architecture Concerns**:
  1. **MONOLITHIC SCRIPT (1,111 lines, 61.7 KB)**: Extremely high complexity combining pre-flight checks, 8 bulk Graph/Az loads, 13 signal evaluations per app, deletion safety scoring, bucket classification, managed identity sweep, 8+ CSV exports, owner notification generation, and 50+ lines of ASCII table formatting via `Write-Host`.
  2. **Unused `ShouldProcess`**: Function header includes `[CmdletBinding(SupportsShouldProcess)]`, but `$PSCmdlet.ShouldProcess()` is **NEVER called anywhere** in the body.
  3. Missing internal helper functions in module file: Calls internal functions `Invoke-PSUGraphWithRetry`, `Get-PSUExternalSystemType`, `Get-PSUDeletionSafetyScore`, `Get-PSUAppUsageStatus`, `Get-PSUCleanupBucket`, `Get-PSUAppWhereUsed` which must be exported/loaded separately.
  4. Script-scoped state (`$script:LogFile`).
  5. Default `$OutputDirectory = $PSScriptRoot` and `$LogDirectory = $PSScriptRoot` write report CSVs directly into the module source code directory when run interactively.
- **ShouldProcess**: ⚠️ Declared on attribute, but **NEVER checked/invoked in code**.
- **Hardcoded URLs/Paths**: Microsoft Graph App ID `00000003-0000-0000-c000-000000000000` and Microsoft Tenant ID `f8cdef31-a31e-4b4a-93e4-5f571e91255a`.
- **Other Notable**: Highly comprehensive Entra ID App Registration audit engine with deletion safety scoring algorithms.

---

### 12. `Find-PSUADServiceAccountMisuse.ps1`
- **File size & Line count**: 5,834 Bytes | 147 Lines
- **Comment-based help**: ✅ Complete (minor gaps in parameter descriptions).
- **Parameter validation**: ❌ Weak (no `[ValidateNotNullOrEmpty()]` or range checks).
- **Error handling**: ❌ **NO try/catch block anywhere in the function**.
- **Pipeline support**: ❌ No pipeline support.
- **Security concerns**: Queries Security Event log ID 4624 across DCs.
- **Code smells**:
  1. Default `$Server = $env:COMPUTERNAME`: Running this on a workstation will fail to retrieve domain interactive logon events (must query a Domain Controller).
  2. Pipeline pollution: Calls `Format-Table` directly inside the function body (line 136) before returning `$Results`, pushing formatting objects into the pipeline.
  3. Array accumulation `$Results += $Object` in loop.
  4. Parameter name mismatch: Parameter `$ExportPath` is described in help as a CSV file path, but code treats it as a directory and appends `\\ADServiceAccountMisuse.xlsx` and `\\ADServiceAccountMisuse.Json`.
- **ShouldProcess**: N/A (Analysis operation).
- **Hardcoded URLs/Paths**: Output filenames `ADServiceAccountMisuse.xlsx` and `ADServiceAccountMisuse.Json`.
- **Other Notable**: Combines Active Directory user search with `Get-WinEvent` log analysis and exports via `Export-PSUExcel`.

---

### 13. `New-PSUOutlookMeeting.ps1`
- **File size & Line count**: 11,235 Bytes | 293 Lines
- **Comment-based help**: ✅ Complete.
- **Parameter validation**: ✅ `[Parameter(Mandatory = $true)]` and `[ValidateSet(...)]`.
- **Error handling**: ✅ `try ... catch` in `process` block (uses `Write-Error` before `throw`).
- **Pipeline support**: ❌ No pipeline support.
- **Security concerns**: None.
- **Code smells**:
  1. **MISSING `SupportsShouldProcess`**: State-changing `New-` cmdlet creates Outlook calendar events via Graph API without `ShouldProcess`.
  2. Array accumulation `$attendeeList += ...` in foreach loop.
  3. String date concatenation `${StartTime}T00:00:00.0000000` assumes `$StartTime` is formatted as "yyyy-MM-dd".
- **ShouldProcess**: ❌ **Not implemented**.
- **Hardcoded URLs/Paths**: None.
- **Other Notable**: Integrates with `Microsoft.Graph.Calendar` for creating timed and all-day meetings with HTML body support.

---

### 14. `New-PSUGithubPullRequest.ps1`
- **File size & Line count**: 12,036 Bytes | 279 Lines
- **Comment-based help**: ✅ Complete.
- **Parameter validation**: ✅ `[ValidateNotNullOrEmpty()]` on Title, Description, Token.
- **Error handling**: ✅ `try ... catch` calling `$PSCmdlet.ThrowTerminatingError($_)`.
- **Pipeline support**: ❌ No pipeline support.
- **Security concerns**: Token parameter / `$env:GITHUB_TOKEN`.
- **Code smells**:
  1. **Dead / Incomplete Auto-Merge Logic**: The `-CompleteOnApproval` block (lines 222-247) constructs headers/URIs and prints `Write-Host` messages, but **never invokes `Invoke-RestMethod`** to actually trigger auto-merge on GitHub.
  2. **MISSING `SupportsShouldProcess`**: State-changing `New-` cmdlet creates GitHub PRs without `ShouldProcess`.
- **ShouldProcess**: ❌ **Not implemented**.
- **Hardcoded URLs/Paths**: GitHub REST API endpoints (`https://api.github.com/...`).
- **Other Notable**: Returns structured PSCustomObject with custom PSTypeName `PSU.GitHub.PullRequest`.

---

# Key Recommendations Summary

1. **Critical Bug Fixes**:
   - `Unlock-PSUTerraformStateAWS.ps1`: Replace `exit 1` in catch block with `$PSCmdlet.ThrowTerminatingError($_)` or `throw`.
   - `New-PSUGithubPullRequest.ps1`: Fix incomplete `-CompleteOnApproval` block to actually execute the REST call.
   - `Find-PSUADServiceAccountMisuse.ps1`: Remove `Format-Table` call from function pipeline output; add `try/catch`.

2. **ShouldProcess Compliance**:
   - Add `[CmdletBinding(SupportsShouldProcess)]` and `$PSCmdlet.ShouldProcess()` checks to all state-modifying cmdlets: `New-PSUADOPPullRequest`, `New-PSUGithubPullRequest`, `New-PSUOutlookMeeting`, and `Export-PSUExcel`.
   - Implement actual `$PSCmdlet.ShouldProcess()` checks in `Invoke-PSUAzureAppRegAudit.ps1` where it's declared but ignored.

3. **Code Refactoring \& Cleanup**:
   - `Invoke-PSUAzureAppRegAudit.ps1` (1,111 lines) and `Get-PSUADOVariableGroupInventory.ps1` (588 lines) should be modularized into smaller helper functions to reduce complexity and remove duplicate logic.
   - Replace `Write-Host` logging with `Write-Verbose` / `Write-Information` across all functions (except interactive CLI chats).
   - Replace `+=` array accumulation in loops with `[System.Collections.Generic.List[object]]`.

4. **Pipeline Support \& Automation**:
   - Enable pipeline input (`ValueFromPipeline = $true`) where documented (e.g. `Get-PSUADOVariableGroupInventory`).
   - Remove interactive `Read-Host` prompts or provide explicit non-interactive bypass switches for CI/CD compatibility.

---

*End of Report*
