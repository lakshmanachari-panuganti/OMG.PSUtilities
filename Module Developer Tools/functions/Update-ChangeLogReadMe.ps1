function Update-ChangeLogReadMe {
    [CmdletBinding()]
    param (
        [string]$ModuleName,
        [string]$RootPath = $env:BASE_MODULE_PATH,
        [switch]$DryRun,
        [switch]$passThru
    )

    $ErrorActionPreference = 'Stop'

    Write-Host "Scanning for modified modules..." -ForegroundColor Cyan

    # Get list of modified files via Git and then filtering for Module private and public functions
    $changedFiles = Get-PSUGitRepositoryChanges -RootPath $RootPath | Where-Object {
        $_.Path -like "$env:BASE_MODULE_PATH\OMG.PSUtilities.*\Public\*.ps1" -or
        $_.Path -like "$env:BASE_MODULE_PATH\OMG.PSUtilities.*\Private\*.ps1"
    }


    # Get unique list of modified modules (based on folder name)
    $ChangedModulesHash = $changedFiles | ForEach-Object {
        $changedFile = $_

        # Regex pattern: Extract OMG.PSUtilities.<submoduleName>
        $regex = 'OMG\.PSUtilities\.[^\\]+'
        if ($changedFile.Path -match $regex) {
            $File = [PSCustomobject] @{
                Name       = $changedFile.Name
                Path       = $changedFile.Path
                ChangeType = $changedFile.ChangeType
                ItemType   = $changedFile.ItemType
            }
            [PSCustomobject] @{
                ModuleName = $matches[0]
                File       = $File
            }
        }
    
    } | Group-Object ModuleName -AsHashTable

    $ChangedModuleNames = if ($ModuleName) {
        $ChangedModulesHash.Keys | Where-Object { $_ -eq $ModuleName }
    }
    else {
        $ChangedModulesHash.Keys
    }

    if (-not $ChangedModuleNames) {
        Write-Host "No changes detected, exiting..." -ForegroundColor Green
        return
    }

    foreach ($thismoduleName in $ChangedModuleNames) {
        $thisModuleRoot = Join-Path $RootPath $thismoduleName
        $thisModuleReadmePath = Join-Path $thisModuleRoot 'README.md'
        $thisModuleChangelogPath = Join-Path $thisModuleRoot 'CHANGELOG.md'
    
        Write-Host ""
        Write-Host "Working on the module: $thismoduleName" -ForegroundColor Yellow
    
        # Prompt for changelog per function
        $changeDetails = @()

        foreach ($thisModuleFileObj in $ChangedModulesHash.$thismoduleName) {
            $msg = $null
            $Synopsis = $null
        
            if ($thisModuleFileObj.File.ChangeType -like 'New' -and $thisModuleFileObj.File.ItemType -like 'File') {
                # For the Newly added file, we can get the synopsis from the function help
                # TODO: Test this!
                
                $Synopsis = Get-PSUFunctionCommentBasedHelp -FunctionPath $thisModuleFileObj.File.Path -HelpType SYNOPSIS
                Write-Host "Hit Enter to update the description as " -ForegroundColor Cyan -NoNewline
                Write-Host "[$Synopsis]" -foregroundColor Green -NoNewline
                Write-Host "for $($thisModuleFileObj.File.Name)" -ForegroundColor Cyan
            }
        
            $msg = Read-Host "[CHANGELOG] [$($thisModuleFileObj.File.ChangeType) $($thisModuleFileObj.File.ItemType)] [$($thisModuleFileObj.File.Name)] → Enter change description"

            if ( $null -ne $Synopsis -and ([string]::IsNullOrEmpty($msg) -or [string]::IsNullOrWhiteSpace($msg))) {
                $msg = $Synopsis
            }

            if ([string]::IsNullOrEmpty($msg) -or [string]::IsNullOrWhiteSpace($msg)) {
                # Skipping this file from updating in CHANGELOG
            }
            else {
                $changeDetails += "- [$($thisModuleFileObj.File.ChangeType) $($thisModuleFileObj.File.ItemType)] [$($thisModuleFileObj.File.Name)] : $msg"
            }
        }

        # TODO: Convert '$changeDetails' to natural language summary and update to Git commit message - Should achieve via Google Gemini.
        # $GitCommitMessage += $changeDetails
        # at the end $GitCommitMessage = $changeDetails -join "`n"
        # Set as environment variable Set-PSUUserEnvironmentVariable -Name AutoGitCommitMessage -Value $GitCommitMessage
        # While committing, use: git commit -m $env:AutoGitCommitMessage
        #Write-Host "Changes to commit: $($changeDetails.Count) items" -ForegroundColor Cyan
        #if ($DryRun) {
        #    Write-Host "[DryRun] Would commit changes with message: $($changeDetails -join "`n")"
        #    continue
        #}
        #else {
        #    Write-Host "Committing changes to Git..." -ForegroundColor Green
        #    $gitCommitMessage = $changeDetails -join "`n"
        #    Set-PSUGitRepositoryChanges -RootPath $thisModuleRoot -Message $gitCommitMessage
        #}

        # Bump module version and get new version
        $date = (Get-Date).ToString('yyyy-MM-dd')
        $newVersion = Update-OMGModuleVersion -ModuleName $thismoduleName -Increment Patch

        # Update CHANGELOG
        if (-not $DryRun) {
            Add-Content -Path $thisModuleChangelogPath -Value ""
            Add-Content -Path $thisModuleChangelogPath -Value "## [$newVersion] - $date"
            $changeDetails | ForEach-Object {
                Add-Content -Path $thisModuleChangelogPath -Value $_
            }
            Write-Host "CHANGELOG updated." -ForegroundColor Green
        }
        else {
            Write-Host "[DryRun][$thismoduleName][CHANGELOG] will be Updated as following changes:"
            Write-Host "## [$newVersion] - $date" -ForegroundColor Cyan
            $changeDetails | ForEach-Object {
                Write-Host $_
            }
        }

        # Update README
        
        $readmeLines = Get-Content $thisModuleReadmePath
        $metaLine = "> Module version: $newVersion | Last updated: $(Get-Date -Format 'yyyy-MM-dd')"

        # Remove previous metadata line
        $readmeLines = $readmeLines | Where-Object { $_ -notmatch '^> Module version:' }

        # Append updated metadata and function list
        $readmeLines += ""
        $readmeLines += $metaLine
        $readmeLines += "### 🚀 Recently Updated Functions"
        $readmeLines += ($changeDetails | ForEach-Object { "- $_" })

        if (-not $DryRun) {
            Set-Content -Path $thisModuleReadmePath -Value $readmeLines
            Write-Host "README updated." -ForegroundColor Green
        }
        else {
            Write-Host "[DryRun][$thismoduleName][README.md] will be Updated as following changes:"
            $readmeLines | ForEach-Object {
                Write-Host $_
            }
        }

        # Update Manifest + Build
        if (-not $DryRun) {
            Reset-OMGModuleManifests.ps1 -ModuleName "$thismodule"
            Build-OMGModuleLocally -ModuleName "$thismodule"
        }
        else {
            Write-Host "[DryRun] Would update manifest and build module."
        }
    
    }
    if($passThru) {
        $changeDetails
    }
    
}