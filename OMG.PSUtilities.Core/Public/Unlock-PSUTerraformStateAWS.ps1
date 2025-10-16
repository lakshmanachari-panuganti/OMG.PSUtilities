function Unlock-PSUTerraformStateAWS {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = (Get-Location).Path,
        
        [Parameter(Mandatory = $false)]
        [string]$LockId,
        
        [Parameter(Mandatory = $false)]
        [string]$AccessKey,
        
        [Parameter(Mandatory = $false)]
        [string]$SecretKey,
        
        [Parameter(Mandatory = $false)]
        [string]$Region = "us-east-2",
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    $originalLocation = Get-Location
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
        Write-Host "Working in Terraform directory: $Path"

        # Detect backend type
        $tfFiles = Get-ChildItem -Path $Path -Filter "*.tf" -Recurse
        $backendType = ( $tfFiles | Get-Content | Select-String -Pattern 'backend\s+"(\w+)"' -AllMatches |
                        ForEach-Object { $_.Matches.Groups[1].Value } |
                        Select-Object -First 1)

        if (-not $backendType) {
            $backendType = "local"
        }
        Write-Host "Detected backend type: $backendType"

        Write-Host "Initializing Terraform backend..."
        if ($backendType -eq "s3") {
            if ($AccessKey -and $SecretKey) {
                Write-Host "Using provided AWS credentials..."
                $initArgs = @(
                    "init",
                    "-backend-config=access_key=$AccessKey",
                    "-backend-config=secret_key=$SecretKey",
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
            throw "Terraform init failed. Output: $($initResult -join "`n")"
        }
        Write-Host "Terraform backend initialized successfully"

        # Workspaces
        Write-Host "Retrieving available workspaces..."
        $workspaceOutput = terraform workspace list 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to list workspaces. Output: $($workspaceOutput -join "`n")"
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
            throw "Failed to select workspace '$selectedWorkspace'. Output: $($selectResult -join "`n")"
        }
        Write-Host "Workspace '$selectedWorkspace' selected successfully"

        # Only force-unlock if backend = s3
        if ($backendType -eq "s3") {
            if (-not $Force) {
                Write-Host "WARNING: Force unlocking may cause state corruption if another operation is running."
                do {
                    $confirm = Read-Host "Are you sure you want to force unlock the state? (yes/no)"
                    if ($confirm -eq 'yes') { break }
                    elseif ($confirm -eq 'no') { Write-Host "Operation cancelled by user"; return }
                    else { Write-Host "Please type 'yes' or 'no'" }
                } while ($true)
            }

            Write-Host "Unlocking state with Lock ID: $LockId"
            $unlockResult = terraform force-unlock -force $LockId 2>&1
            if ($LASTEXITCODE -ne 0) {
                if ($unlockResult -match "lock.*not found" -or $unlockResult -match "no lock found") {
                    Write-Host "No lock found with ID '$LockId' - the state may already be unlocked"
                } else {
                    throw "Failed to unlock state. Output: $($unlockResult -join "`n")"
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
        Write-Host "Error: $($_.Exception.Message)"
        Write-Host "Operation failed"
        exit 1
    }
    finally {
        Set-Location -Path $originalLocation
        Write-Host "Restored to original location: $originalLocation"
    }
}
