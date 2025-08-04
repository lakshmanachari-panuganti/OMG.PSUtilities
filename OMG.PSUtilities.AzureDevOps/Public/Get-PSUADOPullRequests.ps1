function Get-PSUADOPullRequests {
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryId,

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [ValidateSet('Active', 'Completed', 'Abandoned')]
        [string]$State = 'Active',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )
    begin {
        if ([string]::IsNullOrWhiteSpace($Organization)) {
            Write-Warning 'A valid Azure DevOps organization is not provided.'
            Write-Host "`nTo fix this, either:"
            Write-Host "  1. Pass the -Organization parameter explicitly, OR" -ForegroundColor Yellow
            Write-Host "  2. Create an environment variable using:" -ForegroundColor Yellow
            Write-Host "     Set-PSUUserEnvironmentVariable -Name 'ORGANIZATION' -Value '<YOUR ADO ORGANIZATION NAME>'`n" -ForegroundColor Cyan
            $script:ShouldExit = $true
        }

        $headers = Get-PSUADOAuthorizationHeader -PAT $PAT
    }
    process {
        try {
            if ($script:ShouldExit) {
                return
            }

            # Resolve RepositoryId if RepositoryName is provided
            if ($PSCmdlet.ParameterSetName -eq 'ByName') {
                Write-Verbose "Resolving repository name '$RepositoryName' to ID..."
                $repoUri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories?api-version=7.1-preview.1"
                $repoResponse = Invoke-RestMethod -Uri $repoUri -Headers $headers -Method Get

                $matchedRepo = $repoResponse.value | Where-Object { $_.name -eq $RepositoryName }
                if (-not $matchedRepo) {
                    throw "Repository '$RepositoryName' not found in project '$Project'."
                }

                $RepositoryId = $matchedRepo.id
                Write-Verbose "Resolved repository ID: $RepositoryId"
            }

            Write-Verbose "Fetching $State pull requests for repository ID '$RepositoryId' in project '$Project'..."
            $stateParam = $State.ToLower()
            $uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/pullrequests?searchCriteria.status=$stateParam&api-version=7.0"

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            $response.value | ConvertTo-CapitalizedObject
        }
        catch {
            Write-Error "Failed to fetch pull requests: $_"
        }
    }
}