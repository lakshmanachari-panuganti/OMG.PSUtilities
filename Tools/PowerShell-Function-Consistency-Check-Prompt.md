# PowerShell Function Consistency Check - LLM Prompt
## OMG.PSUtilities Module Suite Standards

## Instructions for LLM
You are a PowerShell code quality auditor for the OMG.PSUtilities module suite. Review the provided PowerShell function(s) against Lakshmanachari Panuganti's established coding standards. Provide a detailed report identifying any inconsistencies and recommendations for improvement.

## Function Analysis Checklist

### 1. Comment-Based Help Documentation
**Required Elements (Lakshmanachari's Actual Standard):**
- [ ] `.SYNOPSIS` - Single line with clear function purpose (NO consistent indentation requirement)
- [ ] `.DESCRIPTION` - Multi-paragraph detailed explanation describing what the function does and its purpose
- [ ] `.PARAMETER` - Each parameter documented with:
  - Clear description of purpose and expected values
  - Default behavior explained when applicable
  - Optional/Mandatory nature may be indicated but not consistently
  - Validation rules explained where relevant
- [ ] `.EXAMPLE` - Multiple realistic examples showing different usage patterns
- [ ] `.OUTPUTS` - Simple format: `[PSCustomObject]` 
- [ ] `.NOTES` - Varied formats observed:
  - `Author: Lakshmanachari Panuganti`
  - `Date: YYYY-MM-DD` (creation date)
  - `Updated: YYYY-MM-DD - Description` (if applicable)
  - `Requires: [Dependencies]` (if applicable)
- [ ] `.LINK` - Standard links in order:
  - GitHub repository link (https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.XXXX)
  - LinkedIn profile (https://www.linkedin.com/in/lakshmanachari-panuganti/)
  - PowerShell Gallery package (https://www.powershellgallery.com/packages/OMG.PSUtilities.XXXX)
  - Microsoft documentation (if applicable) or any documentation that supports the current function.

**Documentation Quality Standards:**
- [ ] Parameters documented with default value explanations
- [ ] Auto-detection logic clearly explained for optional parameters
- [ ] Environment variable usage documented with Set-PSUUserEnvironmentVariable examples
- [ ] Parameter sets clearly explained when used
- [ ] Examples show progressive complexity from simple to advanced usage

### 2. Function Signature Standards
**Naming Convention (OMG.PSUtilities Standard):**
- [ ] Function uses approved PowerShell verb (Get-Verb compliant)
- [ ] Follows Verb-PSUNoun pattern with PSU prefix
- [ ] CamelCase for multi-word components
- [ ] Descriptive noun that clearly indicates function purpose

**Parameter Standards (Lakshmanachari's Actual Patterns):**
- [ ] Mixed parameter declaration styles:
  - `[Parameter(Mandatory)]` 
  - `[Parameter()]` for optional parameters
- [ ] Environment variable defaults: `$env:ORGANIZATION`, `$env:PAT`, etc.
- [ ] Simple default values preferred over complex expressions
- [ ] Auto-detection patterns mainly in AzureDevOps module (git-based)
- [ ] Validation attributes properly applied
- [ ] Switch parameters for optional behavior modifications

**Advanced Auto-Detection Pattern (AzureDevOps Module Specialty):**
- [ ] Complex default value expressions with git command integration and regex parsing:
  ```powershell
  [string]$Organization = $(if ($env:ORGANIZATION) { $env:ORGANIZATION } else {
      git remote get-url origin 2>$null | ForEach-Object {
          if ($_ -match 'dev\.azure\.com/([^/]+)/') { $matches[1] }
      }
  }),
  [string]$Project = $(git remote get-url origin 2>$null | ForEach-Object {
      if ($_ -match 'dev\.azure\.com/[^/]+/([^/]+)/_git/') { 
          $matches[1]
      }
  }),
  [string]$Repository = $(git remote get-url origin 2>$null | ForEach-Object {
      if ($_ -match '/_git/([^/]+?)(?:\.git)?/?$') { $matches[1] }
  })
  ```
- [ ] Environment variable fallback with git remote URL parsing
- [ ] Azure DevOps URL pattern matching for auto-detection
- [ ] Error suppression in auto-detection: `2>$null`
- [ ] Regex-based extraction of organization, project, and repository names

**Parameter Organization:**
- [ ] Mandatory parameters typically listed first
- [ ] Optional parameters follow logical grouping
- [ ] Authentication parameters (Organization, PAT) commonly at end
- [ ] Switch parameters mixed throughout based on logical grouping

### 3. Parameter Validation (OMG.PSUtilities Actual Patterns)
**Validation Attributes (Lakshmanachari's Actual Style):**
- [ ] `[ValidateNotNullOrEmpty()]` for required string parameters
- [ ] `[ValidateRange(min, max)]` for numeric parameters with boundaries
- [ ] `[ValidateSet()]` occasionally used for limited valid values
- [ ] `[ValidateScript({})]` used in AzureDevOps module for complex validation (git/branch patterns)
- [ ] Simple validation preferred in AzureCore module
- [ ] Custom business logic validation when needed

**Type Safety (OMG.PSUtilities Actual Standard):**
- [ ] Appropriate .NET types specified: `[string]`, `[int]`, `[switch]`
- [ ] String arrays properly typed: `[string[]]` when needed
- [ ] Switch parameters use `[switch]` type exclusively
- [ ] Complex objects typed when possible
- [ ] No generic `[object]` types without justification

### 4. Error Handling Standards (Lakshmanachari's Actual Approach)
**Exception Management:**
- [ ] Try-catch blocks around external operations (API calls, cmdlets)
- [ ] `$PSCmdlet.ThrowTerminatingError($_)` used for fatal errors
- [ ] Simple `throw` statements for validation failures
- [ ] `Write-Error` for specific error conditions
- [ ] `Write-Warning` for non-fatal issues
- [ ] `Write-Host` with color coding for user notifications

**Module-Specific Error Handling:**
- [ ] AzureCore: Simple error handling, often with basic try-catch
- [ ] AzureDevOps: More complex error handling for API operations
- [ ] API-specific error validation and meaningful user guidance
- [ ] Authentication failure handling where applicable

**Validation Logic:**
- [ ] Parameter validation through attributes rather than explicit checks
- [ ] Module availability checks where dependencies exist
- [ ] Authentication context validation (e.g., Get-AzContext)
- [ ] Clear error messages that guide user action

### 5. Output Standards (OMG.PSUtilities Actual Style)
**Return Values:**
- [ ] Functions return objects (PSCustomObject) or simple values
- [ ] Implicit return preferred - no explicit `Write-Output` typically
- [ ] Complex objects with meaningful property names
- [ ] Consistent object structure within related functions
- [ ] Rich object properties providing comprehensive information

**Console Output (Lakshmanachari's Actual Pattern):**
- [ ] `Write-Host` used for user notifications with color coding
- [ ] `Write-Verbose` for detailed operational information
- [ ] `Write-Warning` for non-fatal issues (sometimes with emoji ⚠️)
- [ ] Progress indication in long-running operations (percentage, color-coded)
- [ ] Color patterns: Green for success, Yellow for warnings, Cyan for progress

**Output Suppression:**
- [ ] External command output suppressed: `2>$null` for error suppression
- [ ] API responses processed and returned as objects
- [ ] `| Out-Null` for suppressing unwanted output

### 6. Code Style Consistency (Lakshmanachari's Actual Standards)
**Formatting:**
- [ ] 4-space indentation consistently applied
- [ ] Opening braces on same line: `function Name {`, `if ($condition) {`
- [ ] Consistent spacing around operators and assignments
- [ ] Blank lines to separate logical sections
- [ ] Proper indentation in comment-based help (8 spaces for content)

**Variable Naming:**
- [ ] CamelCase for variable names: `$repositoryIdentifier`
- [ ] Descriptive variable names that indicate purpose
- [ ] Standard patterns: `$headers`, `$body`, `$response` in API functions
- [ ] Simple, clear variable names without unnecessary prefixes

**PowerShell Best Practices (OMG.PSUtilities Style):**
- [ ] Full cmdlet names in functions (no aliases like `%` for `ForEach-Object`)
- [ ] Splatting used for complex parameter sets when appropriate
- [ ] Proper variable scoping
- [ ] `[CmdletBinding()]` attribute on all functions
- [ ] Full cmdlet names preferred over aliases
- [ ] `process {}` blocks used in some complex functions
- [ ] Proper error handling with try-catch where needed
- [ ] No consistent use of `[Diagnostics.CodeAnalysis.SuppressMessageAttribute]`

**OMG.PSUtilities Specific Patterns:**
- [ ] Auto-detection logic using git commands and regex patterns
- [ ] Environment variable integration with fallback logic
- [ ] Consistent API authentication patterns
- [ ] Standardized URI construction and escaping

### 7. Performance Considerations (OMG.PSUtilities Focus)
**API Efficiency:**
- [ ] Minimize REST API calls through intelligent caching
- [ ] Proper HTTP request construction with appropriate headers
- [ ] Efficient JSON serialization/deserialization
- [ ] Batch operations where supported by APIs

**Git Integration Performance:**
- [ ] Git commands optimized with appropriate flags
- [ ] Error output suppression: `2>$null` to prevent noise
- [ ] Branch operations use current context when possible
- [ ] Repository auto-detection cached when used multiple times

**Memory Management:**
- [ ] Large API responses processed incrementally when possible
- [ ] Temporary variables cleared when appropriate
- [ ] Stream processing for file operations

### 8. Security Considerations (OMG.PSUtilities Standards)
**Credential Handling:**
- [ ] No hardcoded credentials or API keys
- [ ] Environment variable usage for sensitive data: `$env:PAT`, `$env:API_KEY_GEMINI`
- [ ] Clear documentation of required environment variables
- [ ] Secure string handling where appropriate
- [ ] Authentication headers properly constructed and secured

**Input Sanitization:**
- [ ] URL encoding for API parameters: `[uri]::EscapeDataString()`
- [ ] File path validation with existence checks
- [ ] Git command parameter sanitization
- [ ] API parameter validation before transmission

**Access Control:**
- [ ] Proper permission requirements documented
- [ ] Scope-appropriate API token usage
- [ ] Clear indication of required access levels

### 9. Module Integration (OMG.PSUtilities Ecosystem)
**Dependencies:**
- [ ] Required modules properly imported and documented
- [ ] Cross-module function calls use full function names
- [ ] External dependencies documented with version requirements
- [ ] PowerShell version compatibility specified

**Function Relationships:**
- [ ] Consistent parameter naming across related functions
- [ ] Shared functionality properly abstracted to private functions
- [ ] Error handling patterns consistent across module suite
- [ ] Auto-detection logic reused appropriately

**OMG.PSUtilities Patterns:**
- [ ] Private helper functions follow module naming conventions
- [ ] Shared authentication patterns (Get-PSUAdoAuthHeader, etc.)
- [ ] Consistent git integration across all modules
- [ ] Environment variable patterns standardized

### 10. Testing Considerations (OMG.PSUtilities Approach)
**Testability:**
- [ ] Functions have single, well-defined responsibility
- [ ] External dependencies (APIs, Git) can be mocked
- [ ] Return values are consistent and testable
- [ ] Error conditions are predictable and documented
- [ ] Auto-detection logic can be overridden for testing

**Validation Points:**
- [ ] Parameter validation logic is comprehensive
- [ ] API response handling covers error scenarios
- [ ] Git command integration handles various repository states
- [ ] Authentication failure scenarios are handled gracefully

## Report Format

Please provide your analysis in the following format:

### Summary
- **Overall Compliance Score**: X/10 (Based on OMG.PSUtilities standards)
- **Critical Issues**: [Number]
- **Recommendations**: [Number]
- **OMG.PSUtilities Patterns**: [Compliant/Non-Compliant]

### Critical Issues Found
1. **[Category]**: [Description]
   - **Impact**: [High/Medium/Low]
   - **OMG.PSUtilities Standard**: [What the standard requires]
   - **Current Implementation**: [What currently exists]
   - **Recommendation**: [Specific fix aligned with Lakshmanachari's patterns]

### Recommendations for Improvement
1. **[Category]**: [Description]
   - **Current**: [What exists now]
   - **OMG.PSUtilities Standard**: [What should be changed to match Lakshmanachari's style]
   - **Rationale**: [Why this change improves consistency with the module suite]

### Positive Aspects (OMG.PSUtilities Compliant)
- [List elements that follow Lakshmanachari's established patterns]
- [Highlight auto-detection implementations]
- [Note proper parameter validation patterns]
- [Acknowledge consistent documentation style]

### Code Examples
If providing corrected code, ensure it matches OMG.PSUtilities patterns:
- Auto-detection default values with git commands
- Proper comment-based help with 8-space indentation
- Lakshmanachari's parameter validation style
- Consistent error handling and output patterns

## Quality Standards Reference - OMG.PSUtilities Style

### Acceptable Documentation Template (Lakshmanachari's Actual Standard)
```powershell
function Verb-PSUNoun {
    <#
    .SYNOPSIS
        Brief description of function purpose.

    .DESCRIPTION
        Detailed explanation of what the function does, how it works,
        and when to use it. Explain auto-detection behavior and integration points.

    .PARAMETER Organization
        (Optional) Description of the parameter with default behavior.
        Default value is auto-detected from git remote origin URL or $env:ORGANIZATION.

    .PARAMETER ParameterName
        Description of the parameter, including expected values and behavior.
        Default behavior explained when applicable.

    .PARAMETER Organization
        The Azure DevOps organization. If not provided, defaults to the ORGANIZATION environment variable.

    .EXAMPLE
        Verb-PSUNoun -ParameterName "Value"
        
        Description of what this example does and expected output.

    .EXAMPLE
        Verb-PSUNoun -Organization "myorg" -ParameterName "Value"

        Example showing explicit parameter usage.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: YYYY-MM-DD
        (OR: Date: DD Month YYYY: Description)
        (OR: File Creation Date: YYYY-MM-DD)

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/ModuleName
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/ModuleName
        https://learn.microsoft.com/relevant-documentation-link
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $(if ($env:ORGANIZATION) { $env:ORGANIZATION } else {
            git remote get-url origin 2>$null | ForEach-Object {
                if ($_ -match 'pattern') { $matches[1] }
            }
        }),

        [Parameter(Mandatory)]
        [ValidateScript({
            if ($_ -match 'validation_pattern') { $true }
            else { throw "Descriptive error message with expected format." }
        })]
        [string]$ParameterName
    )

    process {
        try {
            # Function implementation
            Write-Verbose "Processing operation..."
            
            # API or other operations
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
```

## Additional OMG.PSUtilities Compliance Notes

- **Module Variation**: Different modules have different styles:
  - AzureCore: Simpler, more straightforward approach
  - AzureDevOps: More complex with auto-detection and git integration
- **Environment variables**: Consistent use of `$env:ORGANIZATION`, `$env:PAT`, etc.
- **API integration**: REST API calls with proper header construction
- **Parameter flexibility**: Mixed use of `[Parameter(Mandatory = $true)]` and `[Parameter(Mandatory)]`
- **Documentation flexibility**: Date formats and structure vary between functions
- **Error handling**: Ranges from simple to complex based on function complexity
- **Cross-platform considerations**: Basic PowerShell compatibility

Use this prompt with any PowerShell function to ensure it meets Lakshmanachari Panuganti's actual established standards for the OMG.PSUtilities module suite, acknowledging the variation between modules and the evolution of coding style over time.
