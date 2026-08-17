<#
.SYNOPSIS
    Unlocks a Terraform state lock for an AWS-backed Terraform project.

.DESCRIPTION
    Validates a Terraform working directory, initializes its backend, selects a
    workspace, and runs Terraform force-unlock for the supplied lock ID. AWS
    credentials can be supplied explicitly for an S3 backend or resolved by the
    Terraform and AWS tooling.

.PARAMETER Path
    The Terraform working directory. Defaults to the current directory.

.PARAMETER LockId
    The Terraform state lock identifier. The function prompts when omitted.

.PARAMETER AccessKey
    An optional AWS access key as a SecureString. For interactive use, acquire
    the value with Read-Host -AsSecureString.

.PARAMETER SecretKey
    An optional AWS secret key as a SecureString. For interactive use, acquire
    the value with Read-Host -AsSecureString.

.PARAMETER Region
    The AWS region used for an S3 backend. Defaults to us-east-2.

.PARAMETER Force
    Runs Terraform force-unlock without an additional confirmation prompt.

.EXAMPLE
    Unlock-PSUTerraformStateAWS -Path 'C:\Terraform\Project' -LockId 'abc123'

    Unlocks the specified Terraform state after confirming the operation.

.EXAMPLE
    $accessKey = Read-Host 'AWS access key' -AsSecureString
    $secretKey = Read-Host 'AWS secret key' -AsSecureString
    Unlock-PSUTerraformStateAWS -Path 'C:\Terraform\Project' -LockId 'abc123' -AccessKey $accessKey -SecretKey $secretKey

    Acquires AWS credentials securely before unlocking the specified state.

.OUTPUTS
    None. The function invokes Terraform and writes operation status to the console.

.NOTES
    Author: Lakshmanachari Panuganti
    Version: 1.0
    Requires the Terraform CLI. Force-unlock can corrupt state when another
    Terraform operation is still active.
    Explicit credentials are supplied as SecureString values. Use Read-Host
    -AsSecureString for interactive acquisition, or pass SecureString values
    returned by a secret provider. Credentials are converted only for temporary
    process environment variables and prior values are restored after execution.
#>
function Unlock-PSUTerraformStateAWS {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = (Get-Location).Path,
        
        [Parameter(Mandatory = $false)]
        [string]$LockId,
        
        [Parameter(Mandatory = $false)]
        [SecureString]$AccessKey,
        
        [Parameter(Mandatory = $false)]
        [SecureString]$SecretKey,
        
        [Parameter(Mandatory = $false)]
        [string]$Region = "us-east-2",
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    function Get-SanitizedTerraformOutput {
        param (
            [Parameter()]
            [object[]]$Output
        )

        $sanitizedOutput = ($Output | ForEach-Object { [string]$_ }) -join "`n"
        $sanitizedOutput = [regex]::Replace(
            $sanitizedOutput,
            '(?i)(-backend-config(?:=|\s+))(?:"[^"]*"|''[^'']*''|\S+)',
            '$1***'
        )
        $sensitiveValues = @($env:AWS_ACCESS_KEY_ID, $env:AWS_SECRET_ACCESS_KEY)
        foreach ($sensitiveValue in $sensitiveValues) {
            if (-not [string]::IsNullOrEmpty($sensitiveValue)) {
                $sanitizedOutput = $sanitizedOutput.Replace($sensitiveValue, '***')
            }
        }
        $sanitizedOutput
    }

    $originalLocation = Get-Location
    $locationChanged = $false
    $credentialsChanged = $false
    $hadAccessKey = Test-Path Env:\AWS_ACCESS_KEY_ID
    $hadSecretKey = Test-Path Env:\AWS_SECRET_ACCESS_KEY
    $originalAccessKey = $env:AWS_ACCESS_KEY_ID
    $originalSecretKey = $env:AWS_SECRET_ACCESS_KEY
    try {
        Write-Host "Validating Terraform directory..."
        if (-not (Test-Path $Path -PathType Container)) {
            throw "Directory does not exist: $Path"
        }

        $terraformFiles = @("*.tf", ".terraform")
        $hasTerraformContent = $false
        foreach ($pattern in $terraformFiles) {
            if (Get-ChildItem -Path $Path -Filter $pattern -ErrorAction SilentlyContinue) {
                $hasTerraformContent = $true
                break
            }
        }
        if (-not $hasTerraformContent) {
            throw "Path does not appear to be a Terraform directory (no .tf files or .terraform directory found): $Path"
        }

        # Detect backend type
        $tfFiles = Get-ChildItem -Path $Path -Filter "*.tf" -Recurse
        $backendType = ( $tfFiles | Get-Content | Select-String -Pattern 'backend\s+"(\w+)"' -AllMatches |
                        ForEach-Object { $_.Matches.Groups[1].Value } |
                        Select-Object -First 1)

        if (-not $backendType) {
            $backendType = "local"
        }
        Write-Host "Detected backend type: $backendType"

        if ($Force) {
            $ConfirmPreference = 'None'
        }
        if (-not $PSCmdlet.ShouldProcess($Path, 'Initialize Terraform and force-unlock remote state')) {
            return
        }

        if (-not $LockId) {
            do {
                $LockId = Read-Host "Enter the Terraform Lock ID"
                if ([string]::IsNullOrWhiteSpace($LockId)) {
                    Write-Host "Lock ID cannot be empty. Please try again."
                }
            } while ([string]::IsNullOrWhiteSpace($LockId))
        }
        Write-Host "Lock ID: $LockId"

        Set-Location -Path $Path
        $locationChanged = $true
        Write-Host "Working in Terraform directory: $Path"

        if ($AccessKey -and $AccessKey.Length -gt 0 -and $SecretKey -and $SecretKey.Length -gt 0) {
            $credentialsChanged = $true

            $accessKeyPointer = [IntPtr]::Zero
            try {
                $accessKeyPointer = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($AccessKey)
                $env:AWS_ACCESS_KEY_ID = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($accessKeyPointer)
            }
            finally {
                if ($accessKeyPointer -ne [IntPtr]::Zero) {
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($accessKeyPointer)
                    $accessKeyPointer = [IntPtr]::Zero
                }
            }

            $secretKeyPointer = [IntPtr]::Zero
            try {
                $secretKeyPointer = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecretKey)
                $env:AWS_SECRET_ACCESS_KEY = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($secretKeyPointer)
            }
            finally {
                if ($secretKeyPointer -ne [IntPtr]::Zero) {
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($secretKeyPointer)
                    $secretKeyPointer = [IntPtr]::Zero
                }
            }
        }

        Write-Host "Initializing Terraform backend..."
        if ($backendType -eq "s3") {
            if ($AccessKey -and $AccessKey.Length -gt 0 -and $SecretKey -and $SecretKey.Length -gt 0) {
                Write-Host "Using provided AWS credentials..."
                $initArgs = @(
                    "init",
                    "-backend-config=region=$Region"
                )
            } else {
                Write-Host "No AWS credentials provided, using default AWS profile or environment."
                $initArgs = @("init")
            }
        } else {
            Write-Host "Non-S3 backend detected, skipping AWS backend config..."
            $initArgs = @("init", "-get-plugins=false")
        }

        $initResult = & terraform $initArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed. Output: $(Get-SanitizedTerraformOutput -Output $initResult)"
        }
        Write-Host "Terraform backend initialized successfully"

        # Workspaces
        Write-Host "Retrieving available workspaces..."
        $workspaceOutput = terraform workspace list 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to list workspaces. Output: $(Get-SanitizedTerraformOutput -Output $workspaceOutput)"
        }

        $workspaces = @($workspaceOutput | Where-Object { $_ -match '\S' } | 
                     ForEach-Object { 
                         $workspace = $_.Trim()
                         if ($workspace.StartsWith('* ')) {
                             $workspace.Substring(2).Trim()
                         } else {
                             $workspace.Trim()
                         }
                     } | Where-Object { $_ -ne '' })

        if ($workspaces.Count -eq 0) {
            throw "No workspaces found"
        }

        Write-Host "Available Workspaces:"
        for ($i = 0; $i -lt $workspaces.Count; $i++) {
            Write-Host "  [$($i+1)] $(@($workspaces)[$i])"
        }

        $selectedWorkspace = $null
        if ($workspaces.Count -eq 1 -or $workspaces -contains "default") {
            $selectedWorkspace = $workspaces[0]
            Write-Host "Only one workspace or default detected, auto-selecting: $selectedWorkspace"
        } else {
            do {
                $choice = Read-Host "Enter the number of the workspace to select (1-$($workspaces.Count)) or press Enter for default"
                if ([string]::IsNullOrWhiteSpace($choice)) {
                    $selectedWorkspace = "default"
                    break
                }
                if ($choice -notmatch '^\d+$') {
                    Write-Host "Please enter a valid number."
                    continue
                }
                $choiceInt = [int]$choice
                if ($choiceInt -lt 1 -or $choiceInt -gt $workspaces.Count) {
                    Write-Host "Please enter a number between 1 and $($workspaces.Count)."
                    continue
                }
                $selectedWorkspace = @($workspaces)[$choiceInt-1]
                break
            } while ($true)
        }

        Write-Host "Selecting workspace: $selectedWorkspace"
        $selectResult = terraform workspace select $selectedWorkspace 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to select workspace '$selectedWorkspace'. Output: $(Get-SanitizedTerraformOutput -Output $selectResult)"
        }
        Write-Host "Workspace '$selectedWorkspace' selected successfully"

        # Only force-unlock if backend = s3
        if ($backendType -eq "s3") {
            Write-Host "Unlocking state with Lock ID: $LockId"
            $unlockResult = terraform force-unlock -force $LockId 2>&1
            if ($LASTEXITCODE -ne 0) {
                if ($unlockResult -match "lock.*not found" -or $unlockResult -match "no lock found") {
                    Write-Host "No lock found with ID '$LockId' - the state may already be unlocked"
                } else {
                    throw "Failed to unlock state. Output: $(Get-SanitizedTerraformOutput -Output $unlockResult)"
                }
            } else {
                Write-Host "State successfully unlocked!"
            }
        } else {
            Write-Host "Local backend detected - no remote lock to unlock."
        }

        Write-Host "Operation completed successfully!"
        Write-Host "Workspace: $selectedWorkspace"
        Write-Host "Directory: $Path"
    }
    catch {
        Write-Error "Operation failed: $($_.Exception.Message)"
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        if ($credentialsChanged) {
            if ($hadAccessKey) {
                $env:AWS_ACCESS_KEY_ID = $originalAccessKey
            } else {
                Remove-Item Env:\AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue
            }
            if ($hadSecretKey) {
                $env:AWS_SECRET_ACCESS_KEY = $originalSecretKey
            } else {
                Remove-Item Env:\AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
            }
        }
        if ($locationChanged) {
            Set-Location -Path $originalLocation
            Write-Host "Restored to original location: $originalLocation"
        }
    }
}
