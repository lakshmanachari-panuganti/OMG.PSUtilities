@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'OMG.DevTools.psm1'

    # Version number of this module.
    ModuleVersion = '1.2.0'

    # Supported PSEditions
    # Tested: both Windows PowerShell 5.1 and PowerShell 7 import the module and resolve all
    # five exports with no load errors. Before the BOM fix in this release, four of the five
    # failed to parse under 5.1, so this claim was previously false.
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = '43926de6-8ba6-4200-a2b5-d7a3c4df31c7'

    # Author of this module
    Author = 'Lakshmanachari Panuganti'

    # Company or vendor of this module
    CompanyName = ''

    # Copyright statement for this module
    Copyright = '(c) 2025-2026 Lakshmanachari Panuganti'

    # Description of the functionality provided by this module
    Description = 'Development tools for building, publishing, and managing OMG PowerShell modules. Provides streamlined workflows for module development, version management, and PSGallery publishing.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry
    FunctionsToExport = @(
        'Get-OMGModule'
        'Initialize-OMGEnvironment'
        'Invoke-OMGPublishModule'
        'Invoke-OMGUpdateModule'
        'Invoke-OMGBuildModule'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry
    AliasesToExport = @(
        'omgmod'
        'omgenv'
        'omgpublish'
        'omgupdate'
        'omgbuild'
    )

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @(
                'Development'
                'DevOps'
                'Tools'
                'Module'
                'Build'
                'Publish'
                'PSGallery'
                'OMG'
                'Utilities'
                'Automation'
                'CI'
                'CD'
            )

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/lakshmanachari-panuganti/OMG.PSUtilities'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## 1.2.0

### Security
- Initialize-OMGEnvironment no longer prompts for API keys as plain text and no longer writes
  them to user environment variables. Keys are read with Read-Host -AsSecureString, so they are
  never echoed and do not enter PSReadLine history, and are stored in Windows Credential
  Manager through Set-PSUCredentialToManager. Get-PSUSecret reads them back.
- The non-secret BASE_MODULE_PATH is handled separately and is still stored in the environment,
  because the rest of the tooling resolves the module path from there.
- -AllowEnvironmentVariableSecrets retains the previous insecure behaviour for migration only.
  It warns on every use and is scheduled for removal in OMG.DevTools 2.0.0.
- Secret values never reach output, errors, or the returned result, which carries names only.

## 1.1.0

### Fixed
- Added a UTF-8 BOM to the source files containing non-ASCII characters. Windows PowerShell
  5.1 reads BOM-less files as ANSI, which corrupted those characters and broke string
  terminators, so four of the five exported commands failed to parse and only Get-OMGModule
  loaded. Both editions now import the module and resolve all five exports with no errors.

### Changed
- CompatiblePSEditions = Desktop, Core is now backed by tested imports rather than assumed.
- Applied the MIT license metadata approved in docs/decisions/0.5-licensing-selection.md.
- OMG.DevTools remains deliberately outside the PowerShell Gallery publish workflow and the
  meta-module, both verified as part of this change.

## 1.0.0 - Initial Release

### Features
- **Get-OMGModule**: List all OMG modules with intelligent caching
- **Initialize-OMGEnvironment**: Setup and validate environment variables
- **Invoke-OMGPublishModule**: Automated module publishing workflow to PSGallery
- **Invoke-OMGUpdateModule**: Update modules from PSGallery
- **Invoke-OMGBuildModule**: Build modules locally with optional script analysis

### Aliases
- omgmod → Get-OMGModule
- omgenv → Initialize-OMGEnvironment
- omgpublish → Invoke-OMGPublishModule
- omgupdate → Invoke-OMGUpdateModule
- omgbuild → Invoke-OMGBuildModule

### Performance
- Lazy loading of Module Developer Tools
- 5-minute caching for module lists
- Background environment validation
- Optimized for fast startup times

### Requirements
- PowerShell 5.1 or higher
- BASE_MODULE_PATH environment variable
- API_KEY_PSGALLERY for publishing operations
'@

            # Prerelease string of this module
            # Prerelease = 'beta'

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        } # End of PSData hashtable
    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}