# Check environment variables if not exist ask for create
@(
    '$env:BASE_MODULE_PATH'
    '$env:API_KEY_GEMINI'
    '$env:API_KEY_CLAUDE'
    '$env:API_KEY_OPENAI'
    '$env:API_KEY_PERPLEXITY'
    '$env:API_KEY_PSGALLERY'
).foreach({
        $envVarName = $_
        $envVarValue = Invoke-Expression $envVarName

        if ([string]::IsNullOrEmpty($envVarValue) -or [string]::IsNullOrWhiteSpace($envVarValue)) {
            $readHost = $null
            $readHost = Read-Host "The variable $envVarName is not set or empty. Please enter a value or press Enter to skip."
        
            If (-not [string]::IsNullOrEmpty($readHost) -or -not [string]::IsNullOrWhiteSpace($readHost)) {
                Set-PSUUserEnvironmentVariable -Name $($envVarName.replace('$env:', '')) -Value $readHost
            }
        }
        else {
            Write-Host "The variable $envVarName is already set! skipping..." -ForegroundColor Green
        }
    })

# Initiate
. $($env:BASE_MODULE_PATH + '\Module Developer Tools\Set-ModuleEnvironmentVariables.ps1')

# importing all the Module Developer Tools functions
Write-Host "Importing Module Developer Tools functions..." -ForegroundColor Green
Get-ChildItem -Path ($env:BASE_MODULE_PATH + '\Module Developer Tools\functions') -Filter *.ps1 | ForEach-Object {
    try {
        . $_.FullName
    }
    catch {
        Write-Error "Failed to load $($_.FullName): $_"
    }
}

# Test-PSUCommentBasedHelp
Test-PSUCommentBasedHelp -ModulePath $env:BASE_MODULE_PATH | Where-Object { $_.HasHelpBlock -eq $false } | ForEach-Object {
    Write-Host "Missing help block in: $($_.File)" -ForegroundColor Red
    Write-Host "Missing tags: $($_.MissingTags)" -ForegroundColor Yellow
    Write-Host ""
}

function omgmod {
    Get-ChildItem -Path $env:BASE_MODULE_PATH -Directory | Where-Object {$_.Name -like "$($env:BASE_MODULE_PATH.Split('\')[-1])*"} | ForEach-Object{
        [PSCustomobject] @{
            ModuleName = $_.Name
            Path = $_.FullName
        }
    }
}


function omgpublishmodule {
    $ModulesUpdated = Get-PSUGitFileChangeMetadata | 
    Where-Object { 
        $_.file -like 'OMG.PSUtilities.*/*/*.ps1' -and
        $_.file -notlike 'OMG.PSUtilities.*/*/*--wip.ps1'  
    } |
    ForEach-Object { $_.file.split('/')[0] } | Sort-Object -Unique
    $ModulesUpdated | Update-OMGModuleVersion -Increment Patch
    $ModulesUpdated | Reset-OMGModuleManifests
    $updateChangeLog = Read-Host "Do you want to update the CHANGELOG.md for the updated modules? (Y/N)"
    if ($updateChangeLog -eq 'Y') {
        $ModulesUpdated | Update-PSUChangeLog -ErrorAction Continue
    }
    $publishModule = Read-Host "Do you want to publish the updated modules to PSGallery? (Y/N)"
    aigitcommit
    if ($publishModule -eq 'Y') {
        $ModulesUpdated | ForEach-Object { 
            $module = "$env:BASE_MODULE_PATH\$_"
            try {
                Publish-Module -Name $module -NuGetApiKey $env:apikey -ErrorAction Stop
                Write-Host "$module : Published successfully." -ForegroundColor Green
            }
            Catch {
                $Exception = $_.Exception.Message
                if ($Exception -like "* current version * is already available in the repository *") {
                    Write-Host "$module : The current version is already available in the repository." -ForegroundColor Green
                } else {
                    Write-Error "Failed to publish $module : $Exception"
                }
            }
        }
    }
}

function omgupdatemodule {
    omgmod | ForEach-Object {
        try {
            $localModule = Get-Module -ListAvailable -Name $_.ModuleName | Sort-Object Version -Descending | Select-Object -First 1
            $galleryModule = Find-Module -Name $_.ModuleName -Repository PSGallery -ErrorAction SilentlyContinue
            if ($localModule.Version -ne $galleryModule.Version) {
                Write-Host "[$($_.ModuleName)] Local module version: $($localModule.Version) | PSGallery version: $($galleryModule.Version)" -ForegroundColor Cyan
                Update-Module -Name $_.ModuleName -Verbose -Force
            }
            
        } catch {
            Write-Warning "Failed to update module $($_.ModuleName): $_"
        }
    }
}
function omgbuildmodule {
    omgmod | ForEach-Object {
        try {
            Build-OMGModuleLocally -ModuleName $_.ModuleName -SkipScriptAnalyzer -Verbose
        } catch {
            Write-Warning "Failed to build module $($_.ModuleName): $_"
        }
    }
}

# Build Module locally with Reset-OMGModuleManifests (Reset-OMGModuleManifests is built in Build-OMGModuleLocally)
#omgmod | Build-OMGModuleLocally -SkipScriptAnalyzer
# NOTE: Increment of the module version is required when it is publishing to PSGallery!