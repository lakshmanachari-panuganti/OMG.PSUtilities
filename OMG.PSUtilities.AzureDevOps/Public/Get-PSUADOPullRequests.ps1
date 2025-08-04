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
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PAT = $env:PAT
    )

    process {
        try {
            # Resolve RepositoryId if RepositoryName is provided
            if ($PSCmdlet.ParameterSetName -eq 'ByName') {
                Write-Verbose "Resolving repository name '$RepositoryName' to ID..."
                $headers = Get-PSUADOAuthorizationHeader -PAT $PAT
                $repoUri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories?api-version=7.1-preview.1"
                $repoResponse = Invoke-RestMethod -Uri $repoUri -Headers $headers -Method Get

                $matchedRepo = $repoResponse.value | Where-Object { $_.name -eq $RepositoryName }
                if (-not $matchedRepo) {
                    throw "Repository '$RepositoryName' not found in project '$Project'."
                }

                $RepositoryId = $matchedRepo.id
                Write-Verbose "Resolved repository ID: $RepositoryId"
            }

            Write-Verbose "Fetching pull requests for repository ID '$RepositoryId' in project '$Project'..."
            $uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/pullrequests?searchCriteria.status=active&api-version=7.0"
            $headers = @{
                Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
            }

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            $response.value | ConvertTo-CapitalizedObject
        }
        catch {
            Write-Error "Failed to fetch pull requests: $_"
        }
    }
}