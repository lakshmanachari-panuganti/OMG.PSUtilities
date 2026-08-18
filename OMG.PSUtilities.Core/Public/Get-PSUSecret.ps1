function Get-PSUSecret {
    <#
    .SYNOPSIS
        Retrieves a secret as a SecureString from the first available secure source.

    .DESCRIPTION
        Resolves a named secret from three sources, in this order, and stops at the first hit:

          1. Windows Credential Manager, via the credential store this module already uses.
          2. Microsoft.PowerShell.SecretManagement, when that module is installed.
          3. An environment variable of the same name.

        The environment-variable tier exists only for backward compatibility with the way
        these commands were configured before secure storage was available. It is the least
        secure option, because environment variables are readable by any process in the
        session and are commonly captured in logs and crash dumps, so it warns when used.
        It is deliberately retained rather than removed, so existing automation keeps working.

        A SecureString is always returned. Callers that must hand a secret to a native
        executable or an HTTP header should convert it at that boundary and not before, so
        the plaintext lives for as short a time as possible.

        The secret value is never written to output, verbose, warning, or error text. Failures
        report only the secret's name and which sources were tried.

    .PARAMETER Name
        Name of the secret. Used as the Credential Manager target, the SecretManagement
        secret name, and the environment variable name.

    .PARAMETER Source
        Restricts resolution to a single source instead of trying all three in order.
        Useful when a caller must guarantee a secret is not being read from an environment
        variable.

    .PARAMETER AsPlainText
        Returns the secret as plain text instead of a SecureString. Use this only at an
        unavoidable native or HTTP boundary, and do not store the result.

    .EXAMPLE
        $token = Get-PSUSecret -Name 'GITHUB_TOKEN'

        Resolves GITHUB_TOKEN from Credential Manager, then SecretManagement, then the
        environment variable, and returns it as a SecureString.

    .EXAMPLE
        Get-PSUSecret -Name 'GITHUB_TOKEN' -Source CredentialManager

        Resolves only from Windows Credential Manager, and throws if it is not stored there.

    .OUTPUTS
        [System.Security.SecureString], or [System.String] when -AsPlainText is supplied.

    .NOTES
        Author: Lakshmanachari Panuganti
        Created: 18th August 2026

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.Core
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        '',
        Justification = 'The sources this command reads from - Windows Credential Manager and environment variables - hand back plaintext. Converting that plaintext into a SecureString is the protective step, not a leak; it is what allows callers to receive a SecureString rather than a bare string. The plaintext is not persisted, and it is only returned when the caller explicitly asks with -AsPlainText for a native or HTTP boundary.'
    )]
    [OutputType([System.Security.SecureString])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('CredentialManager', 'SecretManagement', 'EnvironmentVariable')]
        [string]$Source,

        [Parameter()]
        [switch]$AsPlainText
    )

    begin {
        # Ordered so the most secure source wins. EnvironmentVariable is last and only exists
        # for compatibility with pre-existing configuration.
        $resolutionOrder = if ($PSBoundParameters.ContainsKey('Source')) {
            @($Source)
        }
        else {
            @('CredentialManager', 'SecretManagement', 'EnvironmentVariable')
        }
    }

    process {
        $attempted = [System.Collections.Generic.List[string]]::new()

        foreach ($tier in $resolutionOrder) {
            $attempted.Add($tier)
            $plain = $null

            switch ($tier) {
                'CredentialManager' {
                    try {
                        $plain = [CredentialManager.CredMan]::GetPassword($Name)
                    }
                    catch {
                        # An unreadable store must not mask the remaining tiers.
                        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Credential Manager lookup for '$Name' failed: $($_.Exception.Message)"
                    }
                }

                'SecretManagement' {
                    $getSecret = Get-Command -Name 'Get-Secret' -Module 'Microsoft.PowerShell.SecretManagement' -ErrorAction SilentlyContinue
                    if (-not $getSecret) {
                        Write-Verbose "[$($MyInvocation.MyCommand.Name)] SecretManagement is not installed; skipping."
                        break
                    }

                    try {
                        $secureValue = & $getSecret -Name $Name -ErrorAction Stop
                        if ($secureValue -is [System.Security.SecureString]) {
                            if (-not $AsPlainText) {
                                return $secureValue
                            }

                            # Only unprotect at the caller's explicit request, and free the
                            # unmanaged buffer immediately afterwards.
                            $pointer = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
                            try {
                                return [System.Runtime.InteropServices.Marshal]::PtrToStringUni($pointer)
                            }
                            finally {
                                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
                            }
                        }

                        $plain = [string]$secureValue
                    }
                    catch {
                        Write-Verbose "[$($MyInvocation.MyCommand.Name)] SecretManagement lookup for '$Name' failed: $($_.Exception.Message)"
                    }
                }

                'EnvironmentVariable' {
                    $plain = [Environment]::GetEnvironmentVariable($Name)

                    if (-not [string]::IsNullOrWhiteSpace($plain)) {
                        Write-Warning "Secret '$Name' was read from an environment variable. Environment variables are readable by any process in this session and are often captured in logs. Store it with Set-PSUCredentialToManager instead."
                    }
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($plain)) {
                Write-Verbose "[$($MyInvocation.MyCommand.Name)] Resolved '$Name' from $tier."

                if ($AsPlainText) {
                    return $plain
                }

                return (ConvertTo-SecureString -String $plain -AsPlainText -Force)
            }
        }

        throw "Secret '$Name' was not found. Tried: $($attempted -join ', '). Store it with: Set-PSUCredentialToManager -Target '$Name'"
    }
}
