# OMG.PSUtilities — Comprehensive Coding Style & Standards (LLM-Ready)

This document is the **authoritative style guide** for writing, reviewing, and maintaining PowerShell functions across the `OMG.PSUtilities` module family.  
It is designed to be fed directly to Large Language Models (LLMs) so they can **analyze**, **grade**, **suggest improvements**, and **generate** code that conforms to Lakshmanachari Panuganti’s standards.

---

## 0) Who This Is For
- **Human contributors** building or reviewing functions for any `OMG.PSUtilities.*` module.
- **LLMs** acting as code auditors or code generators for the modules.

> **No emojis** must appear in **any** public or private function code or comment-based help.
    Except : [Write-Host "🧠 Thinking..." -ForegroundColor Cyan] 

---

## 1) Golden Rules (Applies to All Modules)
1. **Consistency over cleverness.** All functions should look and feel alike.
2. **Professional presentation.** Complete comment-based help, clear messages, strict naming.
3. **Automation-first outputs.** Return **structured** `[PSCustomObject]` only. Avoid strings or mixed types.
4. **Least surprise defaults.** Prefer auto-detection (git remote) with environment variable fallback when defined (see §4.2).
5. **Deterministic behavior.** Validation errors must explain what to fix. Fail fast on fatal conditions.
6. **No emojis** in function code or help blocks.

---

## 2) Comment-Based Help — Required Structure & Conventions
Each function **must** include comment-based help with the following sections in this order.  
Where examples show indentation, **8 spaces** are used for content lines under each tag:

```
<#
.SYNOPSIS
        One-line summary of the function’s purpose.

.DESCRIPTION
        Multi-paragraph explanation of what the function does, when to use it,
        preconditions, and integration points (e.g., ADO, git, env vars).

        Requires: Azure DevOps PAT with appropriate scopes (when applicable)

.PARAMETER Organization
        (Optional) The Azure DevOps organization name.
        Auto-detected from git remote origin URL, or uses $env:ORGANIZATION when set.

.PARAMETER Project
        (Optional) The Azure DevOps project name. Auto-detected from git remote origin URL.

.PARAMETER Repository
        (Optional) The repository name. Auto-detected from git remote origin URL.

.PARAMETER PAT
        (Optional) Personal Access Token.
        Default is $env:PAT. Set via:
        Set-PSUUserEnvironmentVariable -Name "PAT" -Value "<value>"

.EXAMPLE
        Verb-PSUADOThing -Organization "myorg" -Project "myproject" -Repository "myrepo"

        Demonstrates explicit parameters.

.EXAMPLE
        Verb-PSUADOThing -ParameterX "Value"

        Demonstrates auto-detected Organization/Project/Repository.

.OUTPUTS
        [PSCustomObject]
        Properties include: Id, Name, Organization, Project, Repository, WebUrl, PSTypeName

.NOTES
        Author: Lakshmanachari Panuganti
        Date: DD month YYYY  (Example 22 July 2025)

.LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.<ModuleName>
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.<ModuleName>
        https://learn.microsoft.com/en-us/rest/api/azure/devops (ADO functions only)
#>
```

**Help quality requirements**
- Document **every** parameter with `(Optional)` / `(Mandatory)` prefix and default behavior.
- Document environment variables used (`$env:PAT`, etc.) and how to set them using `Set-PSUUserEnvironmentVariable`.
- Provide at least **two examples** (explicit + auto-detect) with progressive complexity.
- Use **8-space indentation** for content lines inside help tags.
- No emojis anywhere.

---

## 3) Naming Conventions
- Use approved PowerShell verbs (`Get-Verb`).  
- Pattern: **`Verb-PSUADONoun`** for Azure DevOps module functions.  
- Use singular nouns when appropriate.  
  - ✅ `Get-PSUADOProject`  
  - ❌ `Get-PSUADOProjectList`

> Other modules follow `Verb-PSU<Noun>` with their module namespace implied by the module they live in (e.g., `OMG.PSUtilities.Core`).

---

## 4) Parameters — Definition, Order, Defaults, Validation

### 4.1 Parameter Definition & Order
- Attribute order:
  1) `[Parameter(...)]`
  2) Validation attributes (e.g., `[ValidateNotNullOrEmpty()]`, `[ValidateSet()]`, `[ValidateRange()]`, `[ValidateScript({})]`)
  3) Type (e.g., `[string]`, `[int]`, `[switch]`)
  4) Name (e.g., `$Project`)

- **Ordering inside `param` block:**
  1) **Mandatory parameters first**
  2) **Optional parameters next**
  3) **Switches last**

- Use `[switch]` for boolean toggles (never `[bool]`).

### 4.2 Default Value Strategy (Auto-Detection + Env Fallback)
For Azure DevOps functions, adopt this exact pattern for Organization, Project, Repository.  
**Use environment variable if present; otherwise parse git remote.**

```powershell
[Parameter()]
[ValidateNotNullOrEmpty()]
[string]$Organization = $(if ($env:ORGANIZATION) { $env:ORGANIZATION } else {
    git remote get-url origin 2>$null | ForEach-Object {
        if ($_ -match 'dev\.azure\.com/([^/]+)/') { $matches[1] }
    }
}),

[Parameter()]
[ValidateNotNullOrEmpty()]
[string]$Project = $(git remote get-url origin 2>$null | ForEach-Object {
    if ($_ -match 'dev\.azure\.com/[^/]+/([^/]+)/_git/') { $matches[1] }
}),

[Parameter()]
[ValidateNotNullOrEmpty()]
[string]$Repository = $(git remote get-url origin 2>$null | ForEach-Object {
    if ($_ -match '/_git/([^/]+?)(?:\.git)?/?$') { $matches[1] }
})
```

> Notes:  
> - Suppress git errors: `2>$null`.  
> - Regex extracts: **Organization**, **Project**, **Repository** from an ADO remote.  
> - If auto-detection fails, provide a **clear terminating error** in `process {}` with actionable guidance.

### 4.3 Validation Attributes
- Use `[ValidateNotNullOrEmpty()]` for required strings.
- Use `[ValidateSet()]` for constrained values (e.g., `Vote` in ADO approvals).
- Use `[ValidateRange(min, max)]` for bounded numerics.
- Use `[ValidateScript({ ... })]` for complex business rules (e.g., branch naming).
- Use `[Parameter()]` instead of `[Parameter(Mandatory = $false)]`
- Use `[Parameter(mandatory)]` instead of `[Parameter(Mandatory = $true)]`

### 4.4 Type Safety
- Always specify exact types (`[string]`, `[int]`, `[switch]`, `[string[]]`, `[hashtable]`, `[pscustomobject]`).
- Avoid `[object]` unless justified and documented.
- Use `[switch]` for toggles.

---

## 5) Function Structure & Formatting
- Start with `[CmdletBinding()]`.
- Use `begin {}`, `process {}`, `end {}` blocks when there’s pipeline or staged logic; otherwise, use `process {}` only.
- Indentation: **4 spaces** (no tabs).
- Opening braces on the **same line**: `function Name {`, `if ($condition) {`.
- Consistent spacing around operators and assignments.
- Separate logical sections with blank lines.

### Write-Host / Output Policy
- **Primary telemetry**: `Write-Verbose` (for diagnostics), `Write-Warning` (non-fatal issues).
- **User-facing notifications**: `Write-Host` **is allowed** with color coding when console UX is intended.  
  When used, add:
  ```powershell
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console UX: formatted status output for user')]
  ```
- Color scheme (when using `Write-Host`):
  - Green: success
  - Yellow: warnings
  - Cyan: progress or links

---

## 6) Error Handling & Termination
- Wrap external operations in `try { } catch { }`.
- On fatal errors, use:
  ```powershell
  $PSCmdlet.ThrowTerminatingError($_)
  ```
- For validation failures detected after auto-detection attempts, `throw` with a clear message:
  - include **Organization/Project/Repository** when relevant
  - include **how to set env var** or **what repo state is required**

- Prefer attribute-based validation over ad-hoc runtime checks where possible.

---

## 7) Output Objects — Shape, Naming & Consistency
- Functions must **return** `[PSCustomObject]` (implicit output). Do not mix with strings, writes, or raw API responses.
- Use **PascalCase** property names, consistent across the module suite.
- Common ADO properties:
  - `Id`, `Name`, `Organization`, `Project`, `Repository`, `WebUrl`, `PSTypeName`

- Include a `PSTypeName` for downstream formatting/typing.
- Provide **rich but predictable** object structures (avoid breaking changes).

> **Module-wide property naming consistency** is required.  
> E.g., always use `Repository` (not `RepoName`), always use `Project` (not `ProjectName`).

---

## 8) Security Standards
- Never hardcode secrets or tokens.
- Use environment variables for sensitive inputs (`$env:PAT`, `$env:API_KEY_GEMINI`).
- Build auth headers via helper (e.g., `Get-PSUAdoAuthHeader`) and never log secrets.
- Sanitize inputs: use `[uri]::EscapeDataString()` for URL parts.
- Validate file paths and existence where relevant.
- Document required scopes/permissions in `.NOTES`.
- Avoid leaking identifiers in errors unless necessary.

---

## 9) Performance Practices
- Minimize duplicate REST calls; cache intermediate values when reasonable.
- For git integration, avoid repeated `git remote get-url origin`; store its result in a variable if used multiple times.
- Use efficient JSON serialization (`ConvertTo-Json -Depth 10` only when needed).
- Stream or page large responses.
- Suppress noisy stderr (`2>$null`) for git commands used in auto-detection.

---

## 10) Module Integration & Links (Per-Module `.LINK` Rules)
Always include `.LINK` entries in this order, and make them **module-aware**:

1. **GitHub** — specific module folder:  
   `https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.<ModuleName>`  
2. **LinkedIn** — author profile:  
   `https://www.linkedin.com/in/lakshmanachari-panuganti/`  
3. **PowerShell Gallery** — module page:  
   `https://www.powershellgallery.com/packages/OMG.PSUtilities.<ModuleName>`  
4. **Microsoft Docs** — ADO API reference (ADO functions only):  
   `https://learn.microsoft.com/en-us/rest/api/azure/devops`

**Examples**
- `OMG.PSUtilities.AzureDevOps`
- `OMG.PSUtilities.Core`
- `OMG.PSUtilities.Xyz` (future module)

---

## 11) Testing & Mockability
- Functions should have a single, clear responsibility.
- External dependencies must be mockable (HTTP calls, `git`, ADO).  
- Return values must be stable and testable.
- Include predictable failure cases (auth failures, missing repo remotes, invalid IDs).

---

## 12) LLM Auditor Prompt (Use for Reviews)
> **Instruction for LLM:** You are a PowerShell code quality auditor for the OMG.PSUtilities module suite. Review the provided PowerShell function(s) against Lakshmanachari Panuganti’s standards defined in this document. Provide a detailed report identifying inconsistencies and concrete recommendations.

### Required Output Format
**Summary**
- Overall Compliance Score: X/10  
- Critical Issues: [Number]  
- Recommendations: [Number]  
- OMG.PSUtilities Patterns: [Compliant/Non-Compliant]

**Critical Issues**
1. [Category]: [Description]  
   - Impact: [High/Medium/Low]  
   - Standard: [What the standard requires]  
   - Current: [What exists]  
   - Recommendation: [Specific fix aligned with these patterns]

**Recommendations**
1. [Category]: [Description]  
   - Current: [What exists]  
   - Standard: [Required change]  
   - Rationale: [Why it improves consistency]

**Positive Aspects**
- [List elements that follow the established patterns]

**Corrected Snippets (Optional)**
- Provide minimal, focused code blocks to demonstrate fixes, following the exact templates in §13.

---

## 13) Canonical Function Templates

### 13.A Azure DevOps Function Template
```powershell
function Verb-PSUADONoun {
    <#
    .SYNOPSIS
        Brief description of function purpose.

    .DESCRIPTION
        Detailed explanation of what the function does, how it works,
        and when to use it. Explain auto-detection behavior and integration points.

    .PARAMETER PullRequestId
        (Mandatory) Description of the required identifier.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization.
        Auto-detected from git remote origin URL, or uses $env:ORGANIZATION when set.

    .PARAMETER Project
        (Optional) The Azure DevOps project.
        Auto-detected from git remote origin URL.

    .PARAMETER Repository
        (Optional) The repository name.
        Auto-detected from git remote origin URL.

    .PARAMETER PAT
        (Optional) Personal Access Token for Azure DevOps authentication.
        Default is $env:PAT. Set using:
        Set-PSUUserEnvironmentVariable -Name "PAT" -Value "<value>"

    .EXAMPLE
        Verb-PSUADONoun -PullRequestId 123

        Uses auto-detected Organization/Project/Repository.

    .EXAMPLE
        Verb-PSUADONoun -Organization "myorg" -Project "myproj" -Repository "myrepo" -PullRequestId 123

        Uses fully explicit parameters.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: DD month YYYY
        Requires: Azure DevOps PAT with appropriate permissions

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://learn.microsoft.com/en-us/rest/api/azure/devops
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'Console UX: colorized status for user-facing output'
    )]
    param (
        # --- Mandatory first ---
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]$PullRequestId,

        # --- Optional next ---
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $(if ($env:ORGANIZATION) { $env:ORGANIZATION } else {
            git remote get-url origin 2>$null | ForEach-Object {
                if ($_ -match 'dev\.azure\.com/([^/]+)/') { $matches[1] }
            }
        }),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Project = $(git remote get-url origin 2>$null | ForEach-Object {
            if ($_ -match 'dev\.azure\.com/[^/]+/([^/]+)/_git/') { $matches[1] }
        }),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Repository = $(git remote get-url origin 2>$null | ForEach-Object {
            if ($_ -match '/_git/([^/]+?)(?:\.git)?/?$') { $matches[1] }
        }),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT

        # --- Switches last ---
        # [Parameter()] [switch]$WhatIf
    )

    process {
        try {
            if (-not $Organization) {
                throw "Organization is required. Set env var: Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<org>' or ensure git remote is an Azure DevOps URL."
            }
            if (-not $Project) {
                throw "Project is required. Provide -Project or ensure the git remote contains the project segment."
            }
            if (-not $Repository) {
                throw "Repository is required. Provide -Repository or ensure the git remote contains the repo segment."
            }

            $headers = Get-PSUAdoAuthHeader -PAT $PAT

            # IMPLEMENTATION GOES HERE ...
            Write-Verbose "Org: $Organization Project: $Project Repo: $Repository PR: $PullRequestId"

            # Construct a canonical, stable result
            [PSCustomObject]@{
                Id           = $PullRequestId
                Organization = $Organization
                Project      = $Project
                Repository   = $Repository
                WebUrl       = "https://dev.azure.com/$Organization/$([uri]::EscapeDataString($Project))/_git/$Repository"
                PSTypeName   = 'PSU.ADO.SampleResult'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
```

### 13.B Utility Function Template
```powershell
function Verb-PSUUtilityNoun {
    <#
    .SYNOPSIS
        Brief description of the utility’s purpose.

    .DESCRIPTION
        Detailed explanation of the utility function.

    .PARAMETER Input
        (Optional) Input object or string.

    .EXAMPLE
        Verb-PSUUtilityNoun -Input "MyValue"

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: DD month YYYY

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.Core
    #>
    [CmdletBinding()]
    param (
        # --- Optional params ---
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Input
    )

    process {
        try {
            Write-Verbose "Processing input: $Input"

            [PSCustomObject]@{
                Input      = $Input
                Timestamp  = (Get-Date)
                PSTypeName = 'PSU.Utility.SampleResult'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
```

---

## 14) Scoring Rubric (for LLMs)
- **10/10** — Fully compliant: help, params, validation, auto-detect, errors, outputs, links, formatting.
- **8–9/10** — Minor deviations: small doc gaps or formatting blemishes.
- **6–7/10** — Noticeable issues: missing examples, inconsistent properties, weak validation.
- **≤5/10** — Significant non-compliance: missing help, mixed output types, wrong naming, missing auto-detect.

---

## 15) Migration Guidance (Existing Functions)
1. Ensure naming follows **`Verb-PSUADONoun`** (or module-specific pattern).
2. Add/repair full comment-based help with **8-space indentation** and correct `.LINK` ordering.
3. Reorder parameters: **mandatory → optional → switches**.
4. Apply **auto-detection defaults** for Organization/Project/Repository (§4.2).
5. Add validation attributes; replace `[bool]` with `[switch]` where appropriate.
6. Implement `try/catch` with `$PSCmdlet.ThrowTerminatingError($_)` on fatal paths.
7. Normalize output to `[PSCustomObject]` with **PascalCase** property names and a `PSTypeName`.
8. Replace repeated `git` calls with a single captured remote when performance matters.
9. Add examples for explicit and auto-detected usage.
10. Verify module-aware `.LINK` targets the **module folder** and **Gallery** page.

---

## 16) Final Notes
- This style guide reflects **actual patterns** in `OMG.PSUtilities.AzureDevOps` and other modules, including ADO-specific auto-detection and output shapes.
- When in doubt, prefer **clarity**, **consistency**, and **predictability**.
- LLMs should propose **minimal, surgical diffs** that bring a function into compliance without altering behavior unnecessarily.
