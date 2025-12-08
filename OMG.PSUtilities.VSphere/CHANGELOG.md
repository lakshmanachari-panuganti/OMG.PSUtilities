## [1.0.2] - 9th December 2025

## [1.0.1] - 21st November 2025
### Added
- New file `Deploy-Config.ps1` in `Public/Sensitive-Test-Pack` providing deployment configuration steps.

### Security
- Hard-coded credentials (`$UserName`, `$Password`, `$ClientSecret`, `$ApiKey`) introduced in `Deploy-Config.ps1`, exposing sensitive information.
## [1.0.0] - 21st November 2025
### Added
- `Deploy-Config.ps1` (Public): VSphere configuration deployment script for sensitive test pack environments.

### Security
- **CRITICAL**: This file contains hardcoded credentials and sensitive API keys embedded in plaintext, including usernames, passwords, client secrets, and API keys. This is a severe security vulnerability and must be immediately remediated.
- Remove all hardcoded secrets from the codebase and migrate to secure credential management systems (e.g., Azure Key Vault, HashiCorp Vault, or environment variables).
- Rotate all exposed credentials immediately.
- Implement pre-commit hooks to prevent secrets from being committed to version control.
- Consider using tools like `git-secrets` or `TruffleHog` to scan for and prevent credential leaks.
## Changelog
- Initial scaffolding for OMG.PSUtilities.VSphere

## [1.0.0] - 2025-07-16
- OMG.PSUtilities.VSphere.psd1 : Added dummy function ('New-OMGPSUtilitiesVSphere') for testing.
- OMG.PSUtilities.VSphere.psm1 : Added the code to load the private and public functions into the session, and further export public functions.
