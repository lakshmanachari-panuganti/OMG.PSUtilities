function Invoke-PSUADORepoClone {
    <#
    .SYNOPSIS
        Clones all repositories from an Azure DevOps project to a local directory.

    .DESCRIPTION
        Clones all repositories from a specified Azure DevOps project using the Git CLI. The function will attempt to auto-detect
        the Organization from the current repository's remote (origin) or environment variables. Authentication uses a Personal 
        Access Token (PAT) via the $env:PAT environment variable or the -PAT parameter.

        This helper is intended for automation scripts and CI tasks where bulk cloning of project repositories is required.

    .PARAMETER Organization
        (Optional) The Azure DevOps organization name. Auto-detected from git remote origin URL, or uses $env:ORGANIZATION when set.

    .PARAMETER Project
        (Mandatory) The Azure DevOps project name containing repositories to clone.

    .PARAMETER Repository
        (Optional) The repository name. Auto-detected from git remote origin URL.

    .PARAMETER TargetPath
        (Mandatory) Local folder to clone into. Will create a subdirectory named "{Project}-Repos" under this path.

    .PARAMETER PAT
        (Optional) Personal Access Token used for HTTPS authentication. Default is $env:PAT. Do NOT hardcode secrets.

    .PARAMETER Force
        (Optional) Switch to remove existing target folder before cloning.

    .EXAMPLE
        Invoke-PSUADORepoClone -Organization "myorg" -Project "MyProject" -TargetPath "C:\repos"

        Clones all repositories from MyProject into C:\repos\MyProject-Repos folder.

    .EXAMPLE
        Invoke-PSUADORepoClone -Project "MyProject" -TargetPath "D:\code"

        Auto-detects organization and clones all repositories from MyProject into D:\code\MyProject-Repos.

    .OUTPUTS
        [PSCustomObject]

    .NOTES
        Author: Lakshmanachari Panuganti
        Date: 26th August 2025

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
        [string]$Organization = $(if ($env:ORGANIZATION) { $env:ORGANIZATION } else {
            git remote get-url origin 2>$null | ForEach-Object {
                if ($_ -match 'dev\.azure\.com/([^/]+)/') { $matches[1] }
            }
        }),

        [Parameter(mandatory)]
        [String]$Project,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$Repository,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (Test-Path $_) {
            if (-not (Get-Item $_).PSIsContainer) {
                throw "TargetPath '$_' exists but is not a directory."
            }
        } else{
            throw "TargetPath '$_' does not exist. Please provide a valid path."
        }
        $true
    })]
    [string]$TargetPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PAT = $env:PAT,

    [Parameter()]
    [switch]$Force
    )

process {
    try {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw "Git CLI not found. Please install Git and ensure it's available in PATH."
        }

        if (-not $Organization) {
            throw "Organization not provided and could not be auto-detected. Set -Organization or set env var ORGANIZATION."
        }

        if (-not $PAT) {
            throw "PAT token required to list projects and repositories. Set -PAT or env var PAT."
        }

        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))

        # Get project info (to get project ID)
        $projUri = "https://dev.azure.com/$Organization/_apis/projects?api-version=7.1-preview.4"
        $projectsResponse = Invoke-RestMethod -Uri $projUri -Headers @{ Authorization = "Basic $base64AuthInfo" } -Method Get -ErrorAction Stop
        $projectObj = $projectsResponse.value | Where-Object { $_.name -eq $Project }

        if (-not $projectObj) {
            throw "Project '$Project' not found in organization '$Organization'."
        }

        $projectId = $projectObj.id

        # Now get repos (use project ID in the URL)
        $repoUri = "https://dev.azure.com/$Organization/$projectId/_apis/git/repositories?api-version=7.1-preview.1"
        Write-Host "Fetching repositories from project '$Project' (ID: $projectId) in organization '$Organization'..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri $repoUri -Headers @{ Authorization = "Basic $base64AuthInfo" } -Method Get -ErrorAction Stop

        if (-not $response.value -or $response.count -eq 0) {
            Write-Host "No repositories found." -ForegroundColor Yellow
            return
        }

        $projectFolder = Join-Path -Path $TargetPath -ChildPath "$Project-Repos"

        if (Test-Path $projectFolder) {
            if ($Force) {
                Write-Host "Removing existing folder: $projectFolder" -ForegroundColor Yellow
                Remove-Item -LiteralPath $projectFolder -Recurse -Force -ErrorAction Stop
            }
            else {
                throw "Target path '$projectFolder' already exists. Use -Force to remove it."
            }
        }

        New-Item -ItemType Directory -Path $projectFolder -Force | Out-Null

        Push-Location $projectFolder
        $cloned = @()

        foreach ($repo in $response.value) {
            $repoName = $repo.name

            # Construct HTTPS clone URL using project ID to avoid spaces
            # Format: https://{org}@dev.azure.com/{org}/{projectId}/_git/{repo}
            $baseCloneUrl = "https://$Organization@dev.azure.com/$Organization/$projectId/_git/$repoName"

            # Embed PAT token safely (escaped)
            $escapedPAT = [uri]::EscapeDataString($PAT)
            $authCloneUrl = $baseCloneUrl -replace '^https://', "https://:$escapedPAT@"

            Write-Host "`nCloning $repoName using HTTPS with PAT..." -ForegroundColor Green

            $gitArgs = @('clone', $authCloneUrl)

            & git @gitArgs
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "git clone failed for $repoName (exit code $LASTEXITCODE)"
                continue
            }

            $cloned += [PSCustomObject]@{
                Name = $repoName
                CloneUrl = $authCloneUrl
                Path = (Join-Path -Path $projectFolder -ChildPath $repoName)
                PSTypeName = 'PSU.ADO.ClonedRepo'
            }
        }

        Pop-Location

        [PSCustomObject]@{
            Organization = $Organization
            Project = $Project
            ClonedCount = $cloned.Count
            Cloned = $cloned
            Path = $projectFolder
            PSTypeName = 'PSU.ADO.RepoCloneSummary'
        }
    }
    catch {
        if ((Get-Location).Path -like "$projectFolder*") { Pop-Location }
        $PSCmdlet.ThrowTerminatingError($_)
    }
}


}
