<#
    For Azure DevOps
    $token = Get-AzToken -Resource "499b84ac-1321-427f-aa17-267ca6975798"

    For Microsoft Graph
    $token = Get-AzToken -Resource "https://graph.microsoft.com/"
#>
function Get-PSUAzToken {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Resource = "https://management.azure.com/"
    )

    try {
        # Ensure Az.Accounts is available
        if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
            throw "Az.Accounts module is not installed. Please run: Install-Module Az.Accounts"
        }

        # Ensure user is logged in
        if (-not (Get-AzContext)) {
            Write-Host "🔐 Logging in to Azure..." -ForegroundColor Yellow
            Connect-AzAccount -ErrorAction Stop
        }

        # Acquire token
        $token = (Get-AzAccessToken -ResourceUrl $Resource -ErrorAction Stop).Token
        Write-Host "✅ Access token acquired for $Resource"
        return $token
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
