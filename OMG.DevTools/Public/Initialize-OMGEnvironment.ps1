function Initialize-OMGEnvironment {
    <#
    .SYNOPSIS
        Initializes the OMG DevTools module path and API keys, keeping secrets out of
        environment variables.

    .DESCRIPTION
        Handles two different kinds of setting through two different paths, because they carry
        different risk:

          BASE_MODULE_PATH is not a secret. It is prompted as ordinary text and stored as a
          user environment variable, which is where the rest of the tooling reads it from.

          The five API keys are secrets. They are prompted with Read-Host -AsSecureString so
          the value is never echoed and never enters PSReadLine history, and they are stored in
          Windows Credential Manager through Set-PSUCredentialToManager. Get-PSUSecret reads
          them back from there, so nothing needs to hold them in the environment.

        Previously every value was prompted as plain text and written to a user environment
        variable, which echoed each key to the console, recorded it in command history, and
        left it readable in plaintext by any process running as that user.

        A secret value is never written to output, verbose output, errors, or the returned
        result. Only names are reported.

    .PARAMETER NonInteractive
        Reports what is missing without prompting. Nothing is written in this mode.

    .PARAMETER Force
        Re-prompts for values that are already configured, so an existing key can be replaced.

    .PARAMETER AllowEnvironmentVariableSecrets
        Compatibility escape hatch. Also writes each API key to a user environment variable,
        the way this command behaved before secure storage existed. This is insecure, warns
        every time it is used, and is scheduled for removal in OMG.DevTools 2.0.0. Use it only
        while migrating tooling that still reads these keys from the environment.

    .EXAMPLE
        Initialize-OMGEnvironment

        Prompts for anything missing. The module path is typed visibly; API keys are not
        echoed and are stored in Credential Manager.

    .EXAMPLE
        Initialize-OMGEnvironment -NonInteractive

        Reports what is missing and writes nothing. Suitable for automation and CI checks.

    .EXAMPLE
        Initialize-OMGEnvironment -Force

        Re-prompts for every value, including keys that are already stored, so they can be
        rotated.

    .OUTPUTS
        [hashtable] with Valid, Missing and Created lists. These contain setting names only,
        never values.

    .NOTES
        Author: Lakshmanachari Panuganti
        Version: 2.0

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.DevTools
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This command is an interactive setup wizard. Its prompts and progress lines are addressed to the operator at the console and are deliberately not part of the returned object, which carries setting names only.'
    )]
    [Alias('omgenv')]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [switch]$NonInteractive,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$AllowEnvironmentVariableSecrets
    )

    begin {
        # Not a secret: prompted visibly and kept in the environment, because the rest of the
        # tooling resolves the module path from there.
        $pathVariable = 'BASE_MODULE_PATH'

        # Secrets: never echoed, never placed in the environment by default.
        $secretNames = @(
            'GEMINI_API_KEY'
            'API_KEY_CLAUDE'
            'API_KEY_OPENAI'
            'API_KEY_PERPLEXITY'
            'API_KEY_PSGALLERY'
        )

        $results = @{
            Valid   = @()
            Missing = @()
            Created = @()
        }

        if ($AllowEnvironmentVariableSecrets) {
            Write-Warning "-AllowEnvironmentVariableSecrets also stores API keys as user environment variables. That is insecure: any process running as this user can read them, and they are commonly captured in logs and crash dumps. This switch is scheduled for removal in OMG.DevTools 2.0.0."
        }

        # Secret storage lives in OMG.PSUtilities.Core, which DevTools does not require, so
        # both commands are resolved before use rather than assumed. Only needed when there is
        # secret work to do; the module path alone does not depend on Core.
        $storeCommandExists = [bool](Get-Command -Name 'Set-PSUCredentialToManager' -ErrorAction SilentlyContinue)
        $readCommandExists = [bool](Get-Command -Name 'Get-PSUSecret' -ErrorAction SilentlyContinue)
        $secretSupportAvailable = $storeCommandExists -and $readCommandExists
    }

    process {
        # 1. The module path, handled as ordinary configuration.
        $currentPath = [Environment]::GetEnvironmentVariable($pathVariable, 'User')

        if ([string]::IsNullOrWhiteSpace($currentPath) -or $Force) {
            $results.Missing += $pathVariable

            if ($NonInteractive) {
                Write-Warning "Missing setting: $pathVariable"
            }
            else {
                Write-Host "Setting '$pathVariable' is not configured." -ForegroundColor Yellow
                $pathValue = Read-Host "Enter a value for $pathVariable (or press Enter to skip)"

                if (-not [string]::IsNullOrWhiteSpace($pathValue)) {
                    if ($PSCmdlet.ShouldProcess($pathVariable, 'Set user environment variable')) {
                        try {
                            [Environment]::SetEnvironmentVariable($pathVariable, $pathValue, 'User')
                            Set-Item -Path "env:$pathVariable" -Value $pathValue
                            $results.Created += $pathVariable
                            Write-Host "Set $pathVariable successfully" -ForegroundColor Green
                        }
                        catch {
                            Write-Error "Failed to set ${pathVariable}: $($_.Exception.Message)"
                        }
                    }
                }
            }
        }
        else {
            $results.Valid += $pathVariable
            Write-Verbose "$pathVariable is configured"
        }

        # 2. The API keys, handled as secrets.
        if (-not $secretSupportAvailable) {
            throw "Secret storage is unavailable because OMG.PSUtilities.Core is not loaded. Install it with: Install-Module OMG.PSUtilities.Core -Scope CurrentUser, then import it and run this command again."
        }

        foreach ($secretName in $secretNames) {
            $isStored = $false
            try {
                $existing = Get-PSUSecret -Name $secretName -Source CredentialManager -ErrorAction Stop
                $isStored = $null -ne $existing
            }
            catch {
                # Not stored yet, or the store is unreadable. Either way it needs prompting.
                Write-Verbose "No stored secret found for '$secretName'."
            }

            if ($isStored -and -not $Force) {
                $results.Valid += $secretName
                Write-Verbose "$secretName is stored in Credential Manager"
                continue
            }

            $results.Missing += $secretName

            if ($NonInteractive) {
                Write-Warning "Missing secret: $secretName"
                continue
            }

            Write-Host "Secret '$secretName' is not stored." -ForegroundColor Yellow

            # -AsSecureString keeps the value off the console and out of PSReadLine history.
            $secureValue = Read-Host "Enter a value for $secretName (input hidden, or press Enter to skip)" -AsSecureString

            if ($null -eq $secureValue -or $secureValue.Length -eq 0) {
                Write-Verbose "Skipped $secretName"
                continue
            }

            if (-not $PSCmdlet.ShouldProcess($secretName, 'Store secret in Windows Credential Manager')) {
                continue
            }

            try {
                $credential = [PSCredential]::new($secretName, $secureValue)
                Set-PSUCredentialToManager -Target $secretName -Credential $credential -Confirm:$false | Out-Null

                if ($AllowEnvironmentVariableSecrets) {
                    # Only unprotect at this explicit request, and free the buffer immediately.
                    $pointer = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
                    try {
                        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($pointer)
                        [Environment]::SetEnvironmentVariable($secretName, $plain, 'User')
                        Set-Item -Path "env:$secretName" -Value $plain
                    }
                    finally {
                        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
                    }
                }

                $results.Created += $secretName
                Write-Host "Stored $secretName in Credential Manager" -ForegroundColor Green
            }
            catch {
                # Report the name only. The exception must not carry the value into the log.
                Write-Error "Failed to store ${secretName}: $($_.Exception.Message)"
            }
        }

        if ($env:BASE_MODULE_PATH) {
            Initialize-ModuleDevTools
        }

        return $results
    }

    end {
        if ($results.Missing.Count -gt 0 -and $NonInteractive) {
            Write-Warning "Missing settings: $($results.Missing -join ', ')"
            Write-Host "Run 'Initialize-OMGEnvironment' interactively to configure them." -ForegroundColor Cyan
        } elseif ($results.Created.Count -gt 0) {
            Write-Host "`nConfigured $($results.Created.Count) setting(s)" -ForegroundColor Green
            Write-Host "API keys are read back with Get-PSUSecret; they are not stored in the environment." -ForegroundColor Cyan
        }
    }
}
