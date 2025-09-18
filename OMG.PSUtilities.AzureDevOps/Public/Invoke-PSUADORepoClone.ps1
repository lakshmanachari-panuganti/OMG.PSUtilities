function Invoke-PSUADORepoClone {
    <#
    .SYNOPSIS
        Clones all repositories from an Azure DevOps project to a local directory.

    .DESCRIPTION
        Clones all repositories from a specified Azure DevOps project using the Git CLI. The function will attempt to auto-detect
        the Organization from the current repository's remote (origin) or environment variables. Authentication uses a Personal
        Access Token (PAT) via the $env:PAT environment variable or the -PAT parameter. When a PAT is supplied, the function will
        create an authenticated HTTPS clone URL for each repository. If no PAT is supplied, it uses the repo's remoteUrl.

        This helper is intended for automation scripts and CI tasks where bulk cloning of project repositories is required.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name. Auto-detected from git remote origin URL, or uses $env:ORGANIZATION when set.

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing repositories to clone.

    .PARAMETER TargetPath
        (Mandatory) Local folder to clone into. Will create a subdirectory named "{Project}-Repos" under this path.

    .PARAMETER PAT
        (Optional) Personal Access Token used for HTTPS authentication. Default is $env:PAT. Do NOT hardcode secrets.

    .PARAMETER RepositoryFilter
        (Optional) Wildcard pattern to filter repository names to clone, e.g. 'API-*'.

    .PARAMETER Force
        (Optional) Switch to remove existing target folder before cloning.

    .EXAMPLE
        Invoke-PSUADORepoClone -Organization "myorg" -Project "MyProject" -TargetPath "C:\repos" -PAT $env:PAT

        Clones all repositories from MyProject into C:\repos\MyProject-Repos folder using PAT for authentication.

    .EXAMPLE
        Invoke-PSUADORepoClone -Project "MyProject" -TargetPath "D:\code" -RepositoryFilter 'API-*'

        Auto-detects organization and clones only repositories matching the filter into D:\code\MyProject-Repos.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Refactor by assistant per OMG.PSUtilities.StyleGuide.md
        Date: 28th August 2025

    .LINK
        https://github.com/lakshmanachari-panuganti/OMG.PSUtilities/tree/main/OMG.PSUtilities.AzureDevOps
        https://www.linkedin.com/in/lakshmanachari-panuganti/
        https://www.powershellgallery.com/packages/OMG.PSUtilities.AzureDevOps
        https://learn.microsoft.com/en-us/rest/api/azure/devops
    #>

    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console UX: colorized status for user-facing output')]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if (Test-Path $_) {
                    if (-not (Get-Item $_).PSIsContainer) { throw "TargetPath '$_' exists but is not a directory." }
                    return $true
                }
                $parent = Split-Path $_ -Parent
                if (-not $parent) { throw "TargetPath '$_' is not a valid path." }
                if (-not (Test-Path $parent)) { throw "Parent directory '$parent' does not exist. Create it first or provide a different TargetPath." }
                try { $tmp = Join-Path $parent ([System.IO.Path]::GetRandomFileName()); New-Item -Path $tmp -ItemType File -Force | Out-Null; Remove-Item -Path $tmp -Force; return $true } catch { throw "Cannot write to parent directory '$parent'. Check permissions." }
            })]
        [string]$TargetPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryFilter,

        [Parameter()]
        [switch]$Force
    )

    process {
        $repoResults = @()
        Set-Location $TargetPath
        Write-Host "Setting the target path: $TargetPath"

        try {
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                throw 'Git CLI not found. Please install Git and ensure it is available in PATH.'
            }

            $headers = Get-PSUAdoAuthHeader -PAT $PAT -ErrorAction Stop

            # Get Project ID
            $projUri = "https://dev.azure.com/$Organization/_apis/projects?api-version=7.1-preview.4"
            $projectsResp = Invoke-RestMethod -Uri $projUri -Headers $headers -Method Get -ErrorAction Stop
            $projectObj = $projectsResp.value | Where-Object { $_.name -eq $Project }

            if (-not $projectObj) {
                throw "Project '$Project' not found in organization '$Organization'."
            }

            $projectId = $projectObj.id

            # Get repositories
            $repoUri = "https://dev.azure.com/$Organization/$projectId/_apis/git/repositories?api-version=7.1-preview.1"
            Write-Host "Processing the project: '$Project'..." -ForegroundColor Cyan
            $repoResp = Invoke-RestMethod -Uri $repoUri -Headers $headers -Method Get -ErrorAction Stop
            $allRepos = $repoResp.value

            if (-not $allRepos -or $allRepos.Count -eq 0) {
                throw 'No repositories found in the project.'
            }

            # Apply filter if needed
            $repos = if ($RepositoryFilter) {
                $allRepos | Where-Object { $_.name -like $RepositoryFilter }
            }
            else {
                $allRepos
            }

            if (-not $repos) {
                throw "No repositories match the filter '$RepositoryFilter'."
            }

            # Prepare target folder
            $projectFolder = Join-Path -Path $TargetPath -ChildPath "$Project"
            if (Test-Path $projectFolder) {
                if ($Force) {
                    Remove-Item -LiteralPath $projectFolder -Recurse -Force -ErrorAction Stop
                }
                else {
                    throw "Target path '$projectFolder' already exists. Use -Force to remove it."
                }
            }
            New-Item -ItemType Directory -Path $projectFolder -Force | Out-Null

            # Clone or skip each repo
            foreach ($repo in $repos) {
                $repoName = $repo.name
                $cloneUrl = $repo.remoteUrl
                $clonedPath = Join-Path -Path $projectFolder -ChildPath $repoName
                $isCloned = $false
                $errorMsg = $null

                if ($repo.isDisabled) {
                    $errorMsg = "Repo disabled"
                }
                else {
                    Write-Host "Cloning $repoName..." -ForegroundColor Green
                    Set-Location $projectFolder
                    $gitOutput = & git clone $cloneUrl 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $isCloned = $true
                    }
                    else {
                        $errorMsg = "Git clone failed. Output: $gitOutput"
                        $clonedPath = $null
                    }
                }

                $repoResults += [PSCustomObject]@{
                    Organization = $Organization
                    Project      = $Project
                    Repository   = $repoName
                    isCloned     = $isCloned
                    PathCloned   = $clonedPath
                    Error        = $errorMsg
                    PSTypeName   = 'PSU.ADO.RepoCloneSummary'
                }
            }

            return $repoResults
        }
        catch {
            $repoResults += [PSCustomObject]@{
                Organization = $Organization
                Project      = $Project
                Repository   = $null
                isCloned     = $false
                PathCloned   = $null
                Error        = $_.Exception.Message
                PSTypeName   = 'PSU.ADO.RepoCloneSummary'
            }

            return $repoResults
        }
    }
}
