#TODO: add comment based help
function Get-PSUADORepositories {
    [CmdletBinding()]
    param (
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
            Write-Host "Fetching the Repositories in Project [$Project]"
            $uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories?api-version=7.0"
            $headers = @{
                Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
            }

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            $formattedResults = @()
            if ($response.value) {
                foreach ($item in $response.value) {
                    $formattedObject = [PSCustomObject]@{}
    
                    foreach ($property in $item.PSObject.Properties) {
                        $originalName = $property.Name
                        $originalValue = $property.Value

                        # Capitalize the first letter of the property name
                        $capitalizedName = ($originalName[0].ToString().ToUpper()) + ($originalName.Substring(1).ToLower())
        
                        $formattedObject | Add-Member -MemberType NoteProperty -Name $capitalizedName -Value $originalValue
                    }

                    $formattedResults += $formattedObject
                }
            }

            return $formattedResults

        }
        catch {
            Write-Error "Failed to fetch repositories for project '$Project': $_"
        }
    }
}