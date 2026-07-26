# Changelog

## [1.1.0] - 2025-07-03
### Added
- `Invoke-PSUAzureAppRegAudit` (Public): Comprehensive Azure App Registration cleanup and governance audit.
  Collects 13 signals per app, calculates Deletion Safety Score (0-100), assigns to 4 cleanup buckets,
  exports master audit CSV, per-bucket CSVs, owner notification files, Managed Identity report, and
  console summary. Supports -SkipAzureRBAC, -SkipSignInLogs, -DryRunLimit, -VerboseMode switches.
- `Invoke-PSUGraphWithRetry` (Private): Graph API retry handler with HTTP 429 throttle protection.
- `Get-PSUDeletionSafetyScore` (Private): Scoring engine (0-100) with Microsoft 1st-party override,
  signInActivity ALL-TIME dates, age factor, and multi-tier deduction system.
- `Get-PSUAppUsageStatus` (Private): Usage classification with High/Medium/Low confidence levels.
- `Get-PSUCleanupBucket` (Private): 4-bucket assignment (SafeToDisable, NeedsInvestigation, LikelyActive,
  BusinessCritical) based on score and overrides.
- `Get-PSUAppWhereUsed` (Private): Human-readable usage location summary builder.
- `Get-PSUExternalSystemType` (Private): Federated identity credential issuer classifier
  (GitHub Actions, AKS, Terraform Cloud, Azure DevOps, AWS, Google Cloud).
- `Scripts/Run-AzureAppRegAudit.ps1`: Orchestration script with Quick/Full/DryRun modes.
  Handles prerequisite module checks, Graph & Azure authentication, timestamped output
  directories, and post-processing (HTML report, auto-open folder).
- `Scripts/ConvertTo-AuditHtmlReport.ps1`: Self-contained HTML dashboard generator.
  Reads audit CSVs and produces a styled report with executive summary cards, risk flags,
  usage statistics, sortable bucket tables, and Managed Identity summary.

## [1.0.5] - 2025-08-19
### Changed
- Updated Get-PSUAzToken and Test-PSUAzConnection functions to comply with OMG.PSUtilities.StyleGuide.md standards
- Standardized comment-based help with ordinal date format (DDth month YYYY)
- Added comprehensive .OUTPUTS sections to all functions
- Corrected .LINK section ordering (GitHub → LinkedIn → PowerShell Gallery → Microsoft Docs)
- Enhanced documentation consistency and professional presentation

## [1.0.4] - 2025-08-16
### Changed
- Updated `Get-PSUAzToken` for improved logging.

# Changelog

## [1.0.3] - 2025-08-15
### Added
- `Get-PSUAzAccountAccessInSubscriptions`: Retrieves account access details across Azure subscriptions.
- `Get-PSUk8sPodLabel`: Gets labels for Kubernetes pods.
- `Get-PSUAssignmentPrincipalId`: Private. Resolves principal IDs for assignments.
- `Get-PSUBatchDirectoryObjects`: Private. Fetches directory objects in batches.
- `Get-PSUGraphUser`: Private. Retrieves user information from Microsoft Graph.
- `Get-PSURoleDefDetails`: Private. Gets details of role definitions.
- `Get-PSUTransitiveGroups`: Private. Finds all transitive group memberships.
- `Parse-PSUScopePath`: Private. Parses Azure scope paths.
- `Resolve-PSUPrincipalDisplayFromCache`: Private. Resolves principal display names from cache.
- `Test-AzCliLogin`: Private. Tests Azure CLI login status.
- `Get-PSUAzAccountAccessInSubscriptions2--wip`: Work in progress. Next-gen account access retrieval.
- `Update-AksKubeConfig--wip`: Work in progress. Updates AKS kubeconfig.

### Changed
- Improved error handling and bug fixes.
- Updated `Get-PSUAzToken` for improved logging.
- Updated README with comprehensive information.


## [1.0.2] - 2025-08-11
### Added
- Test-PSUAzConnection (Public): Tests Azure connection.
### Changed
- Improved error handling in Get-PSUAzToken.
### Fixed
- Minor bug fixes in Get-PSUAksWorkloadIdentityInventory.

## [1.0.1] - 2025-08-05
### Added
- Get-PSUAzToken (Public): Retrieves an Azure access token.

## [1.0.0] - 2025-07-30
### Added
- Initial release of OMG.PSUtilities.AzureCore module.
- Get-PSUAksWorkloadIdentityInventory (Public): Retrieves AKS workload identity inventory.
- test.ps1 (Private): Internal