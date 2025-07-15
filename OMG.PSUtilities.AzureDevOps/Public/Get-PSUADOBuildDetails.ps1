function Get-PSUADOBuildDetails {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Project
    )

    try {
        Write-Verbose "Escaping project name..."
        $escapedProject = [uri]::EscapeDataString($Project)

        Write-Verbose "Preparing authentication header..."
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
        $headers = @{ Authorization = "Basic $base64AuthInfo" }

        $buildUrl = "https://dev.azure.com/$Organization/$escapedProject/_apis/build/builds/$($BuildId)?api-version=7.1-preview.7"
        Write-Verbose "Calling Azure DevOps API at: $buildUrl"

        $buildDetails = Invoke-RestMethod -Uri $buildUrl -Headers $headers -Method Get -ErrorAction Stop

        return [PSCustomObject]@{
            BuildId      = $buildDetails.id
            PipelineName = $buildDetails.definition.name
            PipelineID = $buildDetails.definition.id
            QueuedTime   = $buildDetails.queueTime
            Status       = $buildDetails.status
            Result       = $buildDetails.result
            WebLink      = $buildDetails._links.web.href
        }
    }
    catch {
        Write-Error "Failed to retrieve build details for Build ID $BuildId. $_"
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
