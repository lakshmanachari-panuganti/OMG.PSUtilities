function Invoke-PSUPullRequestCreation {
    <#
    .SYNOPSIS
    Creates a pull request in Azure DevOps using REST API.

    .DESCRIPTION
    This function submits a pull request (PR) from a specified source branch to a target branch in a given Azure DevOps repository.
    It authenticates using a Personal Access Token (PAT) and allows you to provide custom title and description content.

    .PARAMETER Organization
    The Azure DevOps organization name.

    .PARAMETER Project
    The Azure DevOps project name.

    .PARAMETER RepoId
    The repository name or GUID in which to create the pull request.

    .PARAMETER SourceBranch
    The full name of the source branch (e.g., 'refs/heads/feature-branch').

    .PARAMETER TargetBranch
    The full name of the target branch (e.g., 'refs/heads/main').

    .PARAMETER Title
    The title of the pull request.

    .PARAMETER Description
    The detailed description of the pull request.

    .PARAMETER PersonalAccessToken
    The Azure DevOps Personal Access Token (PAT) used for authentication.

    .EXAMPLE
    Invoke-PSUPullRequestCreation -Organization "myOrganization" -Project "MyProject" -RepoId "myrepo" `
        -SourceBranch "refs/heads/feature-x" -TargetBranch "refs/heads/main" `
        -Title "Feature X Implementation" -Description "This PR adds feature X." `
        -PersonalAccessToken $env:AZDO_PAT

    .OUTPUTS
    Outputs the response from Azure DevOps (usually a PR object in JSON).

    .NOTES
    Author: Lakshmanachari Panuganti
    Date: 2025-07-30
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is intended for this function to display formatted output to the user on the console'
    )]
    param (
        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter()]
        [string]$SourceBranch = $(git branch --show-current),

        [Parameter()]
        [string]$TargetBranch = $(git symbolic-ref refs/remotes/origin/HEAD | Split-Path -Leaf),

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter()]
        [string]$PAT = $env:PAT
    )

    $encodedPat = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
    $headers = @{ Authorization = "Basic $encodedPat" }

    $body = @{
        sourceRefName = $SourceBranch
        targetRefName = $TargetBranch
        title         = $Title
        description   = $Description | Out-String
    } | ConvertTo-Json -Depth 10

    $url = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepoId/pullrequests?api-version=7.0"

    try {
        $response = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $body -ContentType "application/json"
        Write-Host "Pull Request created successfully. PR ID: $($response.pullRequestId)" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Error "Failed to create pull request: $_"
    }
}
